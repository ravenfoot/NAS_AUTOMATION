#!/usr/bin/env bash
# ==============================================================================
# 🖖 GEMINI-NAS: CLAMAV SECURITY SWEEP (v1.3 — Annotated)
# ==============================================================================
# Purpose:  "Raven Scouting Party"
#           Performs a lightweight malware scan of all core data filesystems.
#
#           Behaviour:
#             • Automatically discovers mounted filesystems derived from SATA drives
#             • Excludes the Borg backup repo (deduplicated blob; scanning pointless)
#             • Filters scan output to show ONLY suspicious files + final summary
#
# Philosophy:
#   Keep scans *fast and meaningful*: review logs, not raw firehose output.
#
# Path:     /usr/local/sbin/nas_stage_clamav_scan.sh
# Logs:     /mnt/nas_sys_core/logs_files/clamav.log
# Mirror:   /mnt/backup/@logs/clamav.log
# ==============================================================================

# Safety notes:
# -u → undefined variables cause immediate errors
# pipefail is **disabled** because ClamAV + grep pipelines have non-fatal exit codes

set -u
set +o pipefail


# ------------------------------------------------------------------------------
# ⚙️ Configuration
# ------------------------------------------------------------------------------

LOG_DIR="/mnt/nas_sys_core/logs_files"
BACKUP_LOG_DIR="/mnt/backup/@logs"
LOG_FILE="${LOG_DIR}/clamav.log"
CORE_LOG="${LOG_DIR}/full_core.log"

# Drives to consider when auto-discovering scan targets

DRIVES=("sda" "sdb" "sdc" "sdd" "sde")

# Exclusion paths (we skip Borg repo; scanning it is meaningless + expensive)

EXCLUDED_PATHS=(
    "/mnt/backup/@tower/borg_repo"
    "/mnt/backup/@tower"
)

mkdir -p "$LOG_DIR"


# ------------------------------------------------------------------------------
# 📝 Logging Utility (Unified NAS Style)
# ------------------------------------------------------------------------------

log() {
    local level="$1"
    local msg="$2"

    local timestamp
    timestamp=$(date +'%d/%m/%y %H:%M:%S')

    local entry="[${timestamp}] [${level}] ${msg}"

    # Print if interactive

    if [ -t 1 ]; then
        echo "$entry"
    fi

    # Write logs

    echo "$entry" >> "$LOG_FILE"
    echo "$entry" >> "$CORE_LOG"

    # Mirror to backup logs when available

    if [ -d "$BACKUP_LOG_DIR" ] && [ -w "$BACKUP_LOG_DIR" ]; then
        echo "$entry" >> "${BACKUP_LOG_DIR}/clamav.log"
    fi
}


# ------------------------------------------------------------------------------
# 🔍 Auto-Discover Scan Targets
# ------------------------------------------------------------------------------
# Purpose:
#   Build a list of mountpoints associated with the physical drives.
#   This future-proofs your NAS if additional drives or mountpoints appear.
# ------------------------------------------------------------------------------

discover_targets() {
    local targets=()

    for drv in "${DRIVES[@]}"; do
        # Gather all mountpoints associated with the drive
        while read -r path; do
            # Skip empty lines
            [ -z "$path" ] && continue

            # Skip excluded paths
            for excl in "${EXCLUDED_PATHS[@]}"; do
                if [[ "$path" == "$excl"* ]]; then
                    continue 2
                fi
            done

            targets+=("$path")
        done < <(lsblk -no MOUNTPOINT "/dev/$drv" | grep -v '^$' || true)
    done

    # Fallback

    if [ "${#targets[@]}" -eq 0 ]; then
        targets+=("/mnt/nas_sys_core" "/mnt/storage")
    fi

    echo "${targets[@]}"
}


# ------------------------------------------------------------------------------
# 🦅 Malware Sweep (OG Logic Preserved)
# ------------------------------------------------------------------------------

run_scan() {
    log "INFO" "🕵️ Raven scouting party launched – initiating malware sweep…"

    # Ensure daemon is alive

    if ! systemctl is-active --quiet clamav-daemon; then
        log "WARNING" "⚠️ ClamAV daemon offline. Attempting restart…"
        systemctl start clamav-daemon
        sleep 30
    fi

    if ! systemctl is-active --quiet clamav-daemon; then
        log "CRITICAL" "🛑 ClamAV daemon failed to start. Aborting scan."
        exit 1
    fi

    # Determine targets dynamically

    TARGETS=($(discover_targets))
    log "INFO" "📂 Scanning filesystems: ${TARGETS[*]}"

    TEMP_LOG=$(mktemp)

    # - clamdscan runs the actual scan via daemon
    # - grep -v ': OK$' removes all clean entries (crucial)

    CMD=(clamdscan --fdpass --multiscan "${TARGETS[@]}")

    if [ -t 1 ]; then
        "${CMD[@]}" | grep -v ": OK$" | tee "$TEMP_LOG"
        SCAN_EXIT_CODE=${PIPESTATUS[0]}
    else
        "${CMD[@]}" | grep -v ": OK$" > "$TEMP_LOG"
        SCAN_EXIT_CODE=${PIPESTATUS[0]}
    fi

    # Append filtered results to the main log

    cat "$TEMP_LOG" >> "$LOG_FILE"

    # Extract infection count directly from ClamAV summary

    INFECTED_COUNT=$(grep "Infected files:" "$TEMP_LOG" | awk '{print $3}')

    # Interpret results

    if [ "$SCAN_EXIT_CODE" -eq 0 ]; then
        log "SUCCESS" "🕵️ Sector clear – zero threats detected."
    elif [ "$SCAN_EXIT_CODE" -eq 1 ]; then
        if [ "$INFECTED_COUNT" = "0" ]; then
            log "WARNING" "⚠️ Scan returned warnings, but no infections detected."
        else
            log "CRITICAL" "🛑 INTRUDER ALERT: $INFECTED_COUNT threat(s) found!"
        fi
    else
        log "ERROR" "🛑 Scanner malfunction (Exit Code $SCAN_EXIT_CODE). Check system logs."
    fi

    rm -f "$TEMP_LOG"
}



# ==============================================================================
# 🚀 MAIN EXECUTION
# ==============================================================================

main() {
    log "INFO" "🛡️ Starting ClamAV Security Sweep…"
    run_scan
}

main

# ==============================================================================
# 🛑 END
# ==============================================================================
