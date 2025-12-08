#!/usr/bin/env bash
# ==============================================================================
# 🖖 GEMINI-NAS: SYSTEM INTEGRITY AUDIT (Stage 8)
# ==============================================================================
# Purpose:  The "Forensic Accountant."
#           Detects configuration drift by comparing the LIVE system state against
#           the WORKING reference and the immutable GOLDEN MASTER.
#
#           Layer 1: LIVE (Running) vs WORKING (Staging)
#           Layer 2: WORKING (Staging) vs GOLDEN (Backup)
#
# Path:     /usr/local/sbin/nas_stage_audit.sh
# Logs:     /mnt/nas_sys_core/logs_files/audit.log
# Mirror:   /mnt/backup/@logs/audit.log
# ==============================================================================

# ------------------------------------------------------------------------------
# 🛡️ Safety Rails
# ------------------------------------------------------------------------------
set -u  # Treat unset variables as an error.


# ------------------------------------------------------------------------------
# ⚙️ Configuration & Architecture Map
# ------------------------------------------------------------------------------

LOG_DIR="/mnt/nas_sys_core/logs_files"
BACKUP_LOG_DIR="/mnt/backup/@logs"
LOG_FILE="${LOG_DIR}/audit.log"
CORE_LOG="${LOG_DIR}/full_core.log"

# -- The Three Layers of Truth --

# 1. LIVE LAYER: What is actually executing on the OS right now.
LIVE_BIN="/usr/local/sbin"
LIVE_SYS="/etc/systemd/system"
LIVE_CFG_UFW="/etc/ufw"
LIVE_CFG_DLNA="/etc"
LIVE_CFG_CLAM="/etc/clamav"
LIVE_CFG_MULL="/etc/mullvad-vpn"

# 2. WORKING LAYER: The 'Staging' area. Read-only day-to-day, but updateable.
WORKING_ROOT="/mnt/nas_sys_core/config_backups"

# 3. GOLDEN LAYER: The immutable, offline-capable backup on the BTRFS array.
GOLDEN_ROOT="/mnt/backup/@nas/config_backups"

# Ensure log directories exist
mkdir -p "$LOG_DIR" "$BACKUP_LOG_DIR"


# ------------------------------------------------------------------------------
# 📝 Logging Utility
# ------------------------------------------------------------------------------

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    local log_entry="[$timestamp] [$level] $message"
    
    # 1. Print to console (if running interactively)
    if [ -t 1 ]; then echo "$log_entry"; fi
    
    # 2. Write to primary logs
    echo "$log_entry" >> "$LOG_FILE"
    echo "$log_entry" >> "$CORE_LOG"

    # 3. Mirror to backup drive (Redundancy)
    if [ -d "$BACKUP_LOG_DIR" ] && [ -w "$BACKUP_LOG_DIR" ]; then
        echo "$log_entry" >> "${BACKUP_LOG_DIR}/audit.log"
    fi
}


# ------------------------------------------------------------------------------
# 🔍 Comparison Engine
# ------------------------------------------------------------------------------
# Compares two files using 'diff'.
# Returns 0 if identical, 1 if drift detected.
#
# Arguments:
#   $1: Name (e.g. "Boot Script")
#   $2: Source Path (Live)
#   $3: Reference Path (Working/Golden)
#   $4: Label (e.g. "Live->Work")

check_drift() {
    local name="$1"
    local file_a="$2"
    local file_b="$3"
    local label="$4"

    # 1. Existence Check
    if [ ! -f "$file_a" ]; then
        log "ERROR" "🛑 $label: Missing Source - $file_a"
        return 1
    fi
    if [ ! -f "$file_b" ]; then
        log "WARNING" "⚠️ $label: Missing Reference - $file_b"
        return 1
    fi

    # 2. Content Check
    # -q: Brief mode (report only if different)
    # -b: Ignore changes in amount of whitespace
    # -B: Ignore blank lines

    if diff -q -b -B "$file_a" "$file_b" >/dev/null; then
        log "INFO" "✅ $label Match: $name"
        return 0
    else
        log "WARNING" "⚠️ $label DRIFT DETECTED: $name"
        
        # Optional: Log the specific diff for debugging
        # echo "      --- DIFF START ($name) ---" >> "$LOG_FILE"
        # diff -b -B "$file_a" "$file_b" >> "$LOG_FILE"
        # echo "      --- DIFF END ---" >> "$LOG_FILE"
        
        return 1
    fi
}


# ==============================================================================
# 🚀 MAIN AUDIT LOGIC
# ==============================================================================

main() {
    log "INFO" "🛰️ Initiating Hull Integrity Scan (Level 1 Diagnostic)..."

    local DRIFT_COUNT=0

    # --------------------------------------------------------------------------
    # LAYER 1: LIVE SYSTEM vs STAGING (Working Copy)
    # --------------------------------------------------------------------------
    # Purpose: Did someone edit a script on the server without updating the repo?
    # --------------------------------------------------------------------------

    log "INFO" "--- Comparing LIVE System to STAGING Configs ---"

    # --- A. SHELL SCRIPTS (.sh) ---
    check_drift "Boot Script" \
        "$LIVE_BIN/nas_stage_boot_verify.sh" \
        "$WORKING_ROOT/boot_bak/boot_script/nas_stage_boot_verify.sh" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Shutdown Script" \
        "$LIVE_BIN/nas_stage_shutdown.sh" \
        "$WORKING_ROOT/shutdown_bak/shutdown_script/nas_stage_shutdown.sh" \
        "Live->Work" || ((DRIFT_COUNT++))
        
    check_drift "UFW Script" \
        "$LIVE_BIN/nas_stage_ufw_check.sh" \
        "$WORKING_ROOT/ufw_bak/ufw_script/nas_stage_ufw_check.sh" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Mullvad Script" \
        "$LIVE_BIN/nas_stage_mullvad_check.sh" \
        "$WORKING_ROOT/mullvad_bak/mullvad_script/nas_stage_mullvad_check.sh" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "DLNA Script" \
        "$LIVE_BIN/nas_stage_dlna_maint.sh" \
        "$WORKING_ROOT/dlna_bak/dlna_script/nas_stage_dlna_maint.sh" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Borg Script" \
        "$LIVE_BIN/nas_stage_borg_integrity.sh" \
        "$WORKING_ROOT/borg_bak/borg_script/nas_stage_borg_integrity.sh" \
        "Live->Work" || ((DRIFT_COUNT++))
        
    check_drift "ClamAV Script" \
        "$LIVE_BIN/nas_stage_clamav_scan.sh" \
        "$WORKING_ROOT/clamav_bak/clamav_script/nas_stage_clamav_scan.sh" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Update Script" \
        "$LIVE_BIN/nas_stage_update.sh" \
        "$WORKING_ROOT/update_bak/update_script/nas_stage_update.sh" \
        "Live->Work" || ((DRIFT_COUNT++))
        
    check_drift "Audit Script (Self)" \
        "$LIVE_BIN/nas_stage_audit.sh" \
        "$WORKING_ROOT/audit_bak/audit_script/nas_stage_audit.sh" \
        "Live->Work" || ((DRIFT_COUNT++))

    # --- B. SYSTEMD SERVICES (.service) ---
    check_drift "Boot Service" \
        "$LIVE_SYS/nas-boot-verify.service" \
        "$WORKING_ROOT/boot_bak/boot_service/nas-boot-verify.service" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Shutdown Service" \
        "$LIVE_SYS/nas-stage-shutdown.service" \
        "$WORKING_ROOT/shutdown_bak/shutdown_service/nas-stage-shutdown.service" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "UFW Service" \
        "$LIVE_SYS/nas-ufw-check.service" \
        "$WORKING_ROOT/ufw_bak/ufw_service/nas-ufw-check.service" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Mullvad Service" \
        "$LIVE_SYS/nas-mullvad-check.service" \
        "$WORKING_ROOT/mullvad_bak/mullvad_service/nas-mullvad-check.service" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "DLNA Service" \
        "$LIVE_SYS/nas-dlna-maint.service" \
        "$WORKING_ROOT/dlna_bak/dlna_service/nas-dlna-maint.service" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Borg Service" \
        "$LIVE_SYS/nas-borg-integrity.service" \
        "$WORKING_ROOT/borg_bak/borg_service/nas-borg-integrity.service" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "ClamAV Service" \
        "$LIVE_SYS/nas-clamav-weekly.service" \
        "$WORKING_ROOT/clamav_bak/clamav_service/nas-clamav-weekly.service" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Update Service" \
        "$LIVE_SYS/nas-update-weekly.service" \
        "$WORKING_ROOT/update_bak/update_service/nas-update-weekly.service" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Audit Service" \
        "$LIVE_SYS/nas-audit-weekly.service" \
        "$WORKING_ROOT/audit_bak/audit_service/nas-audit-weekly.service" \
        "Live->Work" || ((DRIFT_COUNT++))
        
    # --- C. SYSTEMD TIMERS (.timer) ---
    check_drift "DLNA Timer" \
        "$LIVE_SYS/nas-dlna-maint.timer" \
        "$WORKING_ROOT/dlna_bak/dlna_service/nas-dlna-maint.timer" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Borg Timer" \
        "$LIVE_SYS/nas-borg-integrity.timer" \
        "$WORKING_ROOT/borg_bak/borg_service/nas-borg-integrity.timer" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "ClamAV Timer" \
        "$LIVE_SYS/nas-clamav-weekly.timer" \
        "$WORKING_ROOT/clamav_bak/clamav_service/nas-clamav-weekly.timer" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Update Timer" \
        "$LIVE_SYS/nas-update-weekly.timer" \
        "$WORKING_ROOT/update_bak/update_service/nas-update-weekly.timer" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Audit Timer" \
        "$LIVE_SYS/nas-audit-weekly.timer" \
        "$WORKING_ROOT/audit_bak/audit_service/nas-audit-weekly.timer" \
        "Live->Work" || ((DRIFT_COUNT++))

    # --- D. CRITICAL CONFIGURATIONS (Settings) ---
    check_drift "System Fstab" \
        "/etc/fstab" \
        "$WORKING_ROOT/fstab_bak/fstab.template" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "ClamAV Config" \
        "$LIVE_CFG_CLAM/clamd.conf" \
        "$WORKING_ROOT/clamav_bak/clamav_settings/clamd.conf" \
        "Live->Work" || ((DRIFT_COUNT++))
    
    check_drift "MiniDLNA Config" \
        "$LIVE_CFG_DLNA/minidlna.conf" \
        "$WORKING_ROOT/dlna_bak/dlna_settings/minidlna.conf" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "Mullvad Settings" \
        "$LIVE_CFG_MULL/settings.json" \
        "$WORKING_ROOT/mullvad_bak/mullvad_settings/etc_mullvad-vpn/settings.json" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "UFW User Rules (IPv4)" \
        "$LIVE_CFG_UFW/user.rules" \
        "$WORKING_ROOT/ufw_bak/ufw_settings/user.rules" \
        "Live->Work" || ((DRIFT_COUNT++))

    check_drift "UFW User Rules (IPv6)" \
        "$LIVE_CFG_UFW/user6.rules" \
        "$WORKING_ROOT/ufw_bak/ufw_settings/user6.rules" \
        "Live->Work" || ((DRIFT_COUNT++))


    # --------------------------------------------------------------------------
    # LAYER 2: STAGING (Working Copy) vs GOLDEN MASTER
    # --------------------------------------------------------------------------
    # Purpose: Is the local repo backed up to the immutable storage?
    # --------------------------------------------------------------------------

    if [ -d "$GOLDEN_ROOT" ] && mountpoint -q /mnt/backup; then
        log "INFO" "--- Comparing STAGING Configs to GOLDEN MASTER ---"
        
        # Recursive diff, excluding the secret passphrase file
        if diff -r -q -x "passphrase" "$WORKING_ROOT" "$GOLDEN_ROOT" >/dev/null; then
             log "SUCCESS" "✅ Golden Master is synchronized."
        else
             log "WARNING" "⚠️ Staging area differs from Golden Master backup."
             # To list drifted files in log:
             # diff -r -q "$WORKING_ROOT" "$GOLDEN_ROOT" | grep "differ" >> "$LOG_FILE"
             ((DRIFT_COUNT++))
        fi
    else
        log "WARNING" "⚠️ Golden Master not accessible at $GOLDEN_ROOT. Skipping Level 2 checks."
    fi


    # --------------------------------------------------------------------------
    # 3. FINAL REPORTING
    # --------------------------------------------------------------------------
    
    if [ "$DRIFT_COUNT" -eq 0 ]; then
        log "SUCCESS" "🔍 Hull integrity 100%. No configuration drift detected."
    else
        log "ERROR" "🛑 Hull microfractures detected: $DRIFT_COUNT files have drifted."
        log "INFO" "ℹ️ Please review $LOG_FILE and sync files manually."
        # We exit 0 so systemd doesn't think the *audit script* crashed, 
        # but the log clearly indicates failure.
    fi
}

main

# ==============================================================================
# 🛑 END
# ==============================================================================