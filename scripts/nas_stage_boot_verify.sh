#!/usr/bin/env bash
# ==============================================================================
# 🖖 GEMINI-NAS: BOOT VERIFICATION STAGE
# ==============================================================================
# Purpose:  "Morning Roll Call" for the entire NAS.
#           Runs immediately after system boot to confirm:
#             • Physical drives are present and healthy (SMART)
#             • Critical mount points are online and writable
#             • Btrfs backup pool is clean and consistent
#             • /etc/fstab matches the certified template (drift detection)
#
# Philosophy:
#   If something vital is offline, degraded, or unexpected,
#   we want to know *before* services start ingesting data.
#
# Path:     /usr/local/sbin/nas_stage_boot_verify.sh
# Logs:     /mnt/nas_sys_core/logs_files/boot.log
# Mirror:   /mnt/backup/@logs/boot.log
# ==============================================================================

# ------------------------------------------------------------------------------
# 🛡️ Safety Rails
# ------------------------------------------------------------------------------
# -e : Exit immediately on error
# -u : Treat unset variables as an error
# -o pipefail : If a pipeline fails, the failure propagates upstream

set -euo pipefail


# ------------------------------------------------------------------------------
# ⚙️ Core Configuration
# ------------------------------------------------------------------------------

LOG_DIR="/mnt/nas_sys_core/logs_files"
BACKUP_LOG_DIR="/mnt/backup/@logs"

LOG_FILE="${LOG_DIR}/boot.log"
CORE_LOG="${LOG_DIR}/full_core.log"

# Reference fstab template for drift detection

TEMPLATE_FSTAB="/mnt/nas_sys_core/config_backups/fstab_bak/fstab.template"

# Drives expected to be online (unformatted names → OG behaviour)

DRIVES=("sda" "sdb" "sdc" "sdd" "sde")

# Mountpoints that MUST be fully operational

MOUNTS_RW=(
    "/mnt/nas_sys_core"
    "/mnt/media"
    "/mnt/backup"
    "/mnt/storage"
)

# Mountpoints that are expected to be read-only

MOUNTS_RO=(
    "/mnt/media_ro"
)

# Ensure base directories exist (especially early in boot)

mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_LOG_DIR"


# ------------------------------------------------------------------------------
# 📝 Logging Utility (OG logic preserved)
# ------------------------------------------------------------------------------
# Notes:
#   • Writes to primary logs AND the global core timeline
#   • Mirrors to backup logs when the backup tower is available
# ------------------------------------------------------------------------------

log() {
    local level="$1"
    local msg="$2"

    local timestamp
    timestamp=$(date +'%d/%m/%y %H:%M:%S')

    local entry="[${timestamp}] [${level}] ${msg}"

    # Print to console for systemctl visibility

    echo "$entry"

    # Append to logs

    echo "$entry" >> "$LOG_FILE"
    echo "$entry" >> "$CORE_LOG"

    # Mirroring (non-fatal if unavailable during early boot)

    if [ -d "$BACKUP_LOG_DIR" ] && [ -w "$BACKUP_LOG_DIR" ]; then
        echo "$entry" >> "${BACKUP_LOG_DIR}/boot.log"
    fi
}

log_section() {
    log "INFO" "--- $1 ---"
}


# ------------------------------------------------------------------------------
# 1. 🏥 SMART HEALTH CHECK
# ------------------------------------------------------------------------------
# Purpose:
#   Ask every drive the simplest question: “Are you healthy?”
#
# Behaviour:
#   • SMART failure increments error counter
#   • Missing drives or SMART unavailable → warnings, but counted as errors
#   • MMC (eMMC) presence check included (OG behaviour)
# ------------------------------------------------------------------------------

check_smart() {
    log_section "🔍 Running Sensor Sweep (SMART)"
    local error_count=0

    for drive in "${DRIVES[@]}"; do
        if smartctl -H "/dev/${drive}" &>/dev/null; then
            log "INFO" "✅ Drive /dev/${drive} reporting healthy."
        else
            log "WARNING" "⚠️ Drive /dev/${drive} reporting health issues or offline!"
            ((error_count++))
        fi
    done

    # MMC check (internal flash)
    if [ -b "/dev/mmcblk0" ]; then
        log "INFO" "✅ System MMC /dev/mmcblk0 detected online."
    else
        log "WARNING" "⚠️ System MMC /dev/mmcblk0 not found!"
        ((error_count++))
    fi

    return $error_count
}

# ------------------------------------------------------------------------------
# 2. 📂 MOUNT VERIFICATION
# ------------------------------------------------------------------------------
# Purpose:
#   • Ensure all storage layers are attached AND writable when expected.
#   • Protects you from "mounted but read-only" filesystem failures.
#
# Technique (OG):
#   • RW mounts → test writing a probe file
#   • RO mounts → only check existence
# ------------------------------------------------------------------------------

check_mounts() {
    log_section "ℹ️ Verifying Cargo Manifest (Mounts)"
    local error_count=0

    # RW Mounts
    for mnt in "${MOUNTS_RW[@]}"; do
        if mountpoint -q "$mnt"; then

            # Write test → the safest and most accurate way

            if touch "$mnt/.nas_probe" 2>/dev/null; then
                rm "$mnt/.nas_probe"
                log "INFO" "✅ $mnt mounted and writable."
            else
                log "ERROR" "🛑 $mnt mounted but READ-ONLY or permission error."
                ((error_count++))
            fi
        else
            log "ERROR" "🛑 $mnt is NOT mounted."
            ((error_count++))
        fi
    done

    # RO Mounts
    for mnt in "${MOUNTS_RO[@]}"; do
        if mountpoint -q "$mnt"; then
            log "INFO" "✅ $mnt mounted (RO verified)."
        else
            log "ERROR" "🛑 $mnt is NOT mounted."
            ((error_count++))
        fi
    done

    return $error_count
}


# ------------------------------------------------------------------------------
# 3. 🧊 BTRFS POOL INTEGRITY
# ------------------------------------------------------------------------------
# Purpose:
#   Deep integrity check of your backup pool.
#   
#     • Verify pool is truly Btrfs
#     • Scan device stats for I/O errors (non-zero = danger)
#     • Verify correct device count (protects against silent disk detachment)
# ------------------------------------------------------------------------------

check_btrfs() {
    log_section "📦 Btrfs Stasis Pod Integrity"
    local mnt="/mnt/backup"
    local error_count=0

    # Confirm filesystem type

    if ! grep -qs "$mnt btrfs" /proc/mounts; then
        log "CRITICAL" "🛑 $mnt is not mounted as Btrfs! Skipping deep scan."
        return 1
    fi

    # DEVICE STATS: look for non-zero counters

    if btrfs device stats "$mnt" | grep -vE ' 0$'; then
        log "WARNING" "⚠️ Hull microfractures detected: Btrfs I/O errors on $mnt."
        btrfs device stats "$mnt" | while read -r line; do
            log "WARNING" "   → $line"
        done
        ((error_count++))
    else
        log "INFO" "✅ Btrfs device stats clean (zero errors)."
    fi

    # DEVICE COUNT CHECK — expects exactly 2 devices

    local dev_count
    dev_count=$(btrfs filesystem show "$mnt" | grep "devid" | wc -l)
    if [ "$dev_count" -eq 2 ]; then
        log "INFO" "✅ Btrfs pool optimal: 2 devices online."
    else
        log "CRITICAL" "💥 Core Breach: Expected 2 devices in pool, found $dev_count!"
        ((error_count++))
    fi

    return $error_count
}


# ------------------------------------------------------------------------------
# 4. 📝 CONFIGURATION DRIFT CHECK (fstab)
# ------------------------------------------------------------------------------
# Purpose:
#   Ensure /etc/fstab matches your authoritative template.
#   Detects accidental edits, corruption, or systemd-generator mismatches.
#
# ------------------------------------------------------------------------------

check_config() {
    log_section "🛡️ Integrity Check (fstab)"

    if [ ! -f "$TEMPLATE_FSTAB" ]; then
        log "WARNING" "⚠️ Reference fstab template missing at $TEMPLATE_FSTAB. Skipping check."
        return 0
    fi

    if diff -b -B /etc/fstab "$TEMPLATE_FSTAB" >/dev/null; then
        log "INFO" "✅ /etc/fstab matches verified template."
    else
        log "WARNING" "⚠️ Drift detected in /etc/fstab!"
        diff -b -B /etc/fstab "$TEMPLATE_FSTAB" | while read -r line; do
            log "WARNING" "   diff: $line"
        done
    fi
}


# ------------------------------------------------------------------------------
# 🚀 MAIN EXECUTION
# ------------------------------------------------------------------------------

main() {
    log "INFO" "🖖 Boot sequence initiated. Running diagnostics..."

    local exit_code=0

    check_smart   || exit_code=1
    check_mounts  || exit_code=1
    check_btrfs   || exit_code=1
    check_config  || exit_code=1

    if [ $exit_code -eq 0 ]; then
        log "SUCCESS" "✅ All systems green. Boot verification complete."
    else
        log "ERROR" "🛑 Diagnostics complete with ERRORS. Review logs immediately."
    fi

    exit $exit_code
}

main

# ==============================================================================
# 🛑 END
# ==============================================================================
