#!/usr/bin/env bash
# ==============================================================================
# 🖖 GEMINI-NAS: SECURITY UPDATE & MAINTENANCE CYCLE
# ==============================================================================
# Purpose:  The "Maintenance Deck."
#           Performs **security-focused** updates, preserves an auditable record
#           of every package-level change, and manages log retention so the
#           NAS remains lean and predictable.
#
#           Strategy:
#           - Refresh repository indexes
#           - Apply *security upgrades only* via unattended-upgrades
#           - Keep verbose output in a dedicated details log
#           - Maintain log hygiene (compress → archive → prune)
#
# Path:     /usr/local/sbin/nas_stage_update.sh
# Logs:     /mnt/nas_sys_core/logs_files/update.log
# Details:  /mnt/nas_sys_core/logs_files/update.details.log
# Mirror:   /mnt/backup/@logs/update.log
# ==============================================================================
set -uo pipefail

# ------------------------------------------------------------------------------
# ⚙️ Configuration
# ------------------------------------------------------------------------------

LOG_DIR="/mnt/nas_sys_core/logs_files"
BACKUP_LOG_DIR="/mnt/backup/@logs"

LOG_FILE="${LOG_DIR}/update.log"
DETAIL_LOG="${LOG_DIR}/update.details.log"
CORE_LOG="${LOG_DIR}/full_core.log"

# Retention Policy
RETENTION_DAYS_RAW=10    # Compress raw logs after X days
RETENTION_DAYS_ARC=30    # Delete compressed logs after X days

mkdir -p "$LOG_DIR" "$BACKUP_LOG_DIR"

# ------------------------------------------------------------------------------
# 📝 Logging Utility
# ------------------------------------------------------------------------------
log() {
    local level="$1"
    local msg="$2"
    local ts
    ts="$(date '+%d/%m/%y %H:%M:%S')"

    local entry="[$ts] [$level] $msg"

    # Print & write to core log files
    echo "$entry" | tee -a "$LOG_FILE" "$CORE_LOG" >/dev/null

    # Mirror to backup array ONLY if it's still mounted & writable
    if [ -d "$BACKUP_LOG_DIR" ] && [ -w "$BACKUP_LOG_DIR" ] && mountpoint -q "/mnt/backup"; then
        echo "$entry" >> "${BACKUP_LOG_DIR}/update.log"
    fi
}

# ------------------------------------------------------------------------------
# 🔄 1. Security Update Logic
# ------------------------------------------------------------------------------
run_security_updates() {
    log "INFO" "🔭 Refreshing repository index (apt update)..."

    if ! apt-get update -q >> "$DETAIL_LOG" 2>&1; then
        log "ERROR" "🛑 Failed to refresh repositories."
        return 1
    fi

    log "INFO" "🛡️ Applying security patches (unattended-upgrades)..."
    echo "--- RUN START: $(date '+%d/%m/%y %H:%M:%S') ---" >> "$DETAIL_LOG"

    # unattended-upgrades (security-only)
    if unattended-upgrade -v >> "$DETAIL_LOG" 2>&1; then
        log "SUCCESS" "✅ Security patches applied (see details log)."
    else
        log "ERROR" "🛑 Security patch application encountered errors. Review details log."
        return 1
    fi

    log "INFO" "🧹 Sweeping decks (autoremove)..."
    apt-get autoremove -yq >> "$DETAIL_LOG" 2>&1
    apt-get autoclean -yq >> "$DETAIL_LOG" 2>&1

    return 0
}

# ------------------------------------------------------------------------------
# 🌀 2. Reboot Requirement Check
# ------------------------------------------------------------------------------
check_reboot_flag() {
    if [ -f /var/run/reboot-required ]; then
        log "WARNING" "⚠️ Reboot required to activate kernel/security patches."
    else
        log "INFO" "✅ No reboot required."
    fi
}

# ------------------------------------------------------------------------------
# 🗄️ 3. Log Pruning & Retention
# ------------------------------------------------------------------------------
cleanup_logs() {
    log "INFO" "🧹 Archiving maintenance logs..."

    # Compress raw logs older than retention window
    find "$LOG_DIR" -name "*.log" -type f -mtime +$RETENTION_DAYS_RAW -exec gzip {} \;
    log "INFO" "📦 Old logs compressed."

    # Purge gzipped archives past long-term retention
    find "$LOG_DIR" -name "*.gz" -type f -mtime +$RETENTION_DAYS_ARC -exec rm {} \;
    log "INFO" "🗑️ Archived logs older than $RETENTION_DAYS_ARC days purged."

    # Truncate details log to last 2000 lines
    tail -n 2000 "$DETAIL_LOG" > "${DETAIL_LOG}.tmp" && mv "${DETAIL_LOG}.tmp" "$DETAIL_LOG"
}

# ==============================================================================
# 🚀 MAIN EXECUTION FLOW
# ==============================================================================
main() {
    : > "$LOG_FILE"     # Reset main log (details log retains rolling history)

    log "INFO" "🚀 Initiating Security Update & Maintenance Cycle..."

    run_security_updates
    check_reboot_flag
    cleanup_logs

    log "SUCCESS" "🛠️ Maintenance cycle complete."
}

main

# ==============================================================================
# 🛑 END
# ==============================================================================
