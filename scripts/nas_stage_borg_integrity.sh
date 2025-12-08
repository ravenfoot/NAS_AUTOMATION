#!/usr/bin/env bash
# ==============================================================================
# 🖖 GEMINI-NAS: BORG INTEGRITY CHECK
# ==============================================================================
# Purpose:  "Stasis Pod Status Report"
#           Verifies that the Borg Backup repository:
#             • Is mounted correctly
#             • Exists at the expected path
#             • Can be opened using the stored BORG_PASSPHRASE
#             • Contains recent snapshots (Today or Yesterday)
#
# Philosophy:
#   This script intentionally performs *lightweight, daily-safe checks*.
#   Deep block-level validation (borg check --verify-data) is expensive and
#   belongs in a scheduled maintenance script, not a daily integrity heartbeat.
#
# Path:     /usr/local/sbin/nas_stage_borg_integrity.sh
# Logs:     /mnt/nas_sys_core/logs_files/borg.log
# Mirror:   /mnt/backup/@logs/borg.log
# ==============================================================================

set -uo pipefail  # Safety: undefined variables cause errors; pipelines propagate failures


# ------------------------------------------------------------------------------
# ⚙️ Configuration
# ------------------------------------------------------------------------------

LOG_DIR="/mnt/nas_sys_core/logs_files"
BACKUP_LOG_DIR="/mnt/backup/@logs"

LOG_FILE="${LOG_DIR}/borg.log"
CORE_LOG="${LOG_DIR}/full_core.log"

# Borg repository path on the backup Btrfs dataset

BORG_REPO="/mnt/backup/@tower/borg_repo"

# Passphrase location (must be chmod 600, root-owned)

PASSPHRASE_FILE="/mnt/nas_sys_core/config_backups/borg_bak/borg_settings/passphrase"


# ------------------------------------------------------------------------------
# 📝 Logging Utility (consistent with boot + audit scripts)
# ------------------------------------------------------------------------------

log() {
    local level="$1"
    local msg="$2"

    local timestamp
    timestamp=$(date +'%d/%m/%y %H:%M:%S')

    local entry="[${timestamp}] [${level}] ${msg}"

    mkdir -p "$LOG_DIR"
    echo "$entry"
    echo "$entry" >> "$LOG_FILE"
    echo "$entry" >> "$CORE_LOG"

    if [ -d "$BACKUP_LOG_DIR" ] && [ -w "$BACKUP_LOG_DIR" ]; then
        echo "$entry" >> "${BACKUP_LOG_DIR}/borg.log"
    fi
}


# ------------------------------------------------------------------------------
# 📦 MAIN INTEGRITY LOGIC
# ------------------------------------------------------------------------------

main() {
    log "INFO" "📦 Initiating Stasis Pod (Backup) diagnostics..."

    
    # 1. Backup mount check
    #    Ensures your entire backup dataset is actually online.
    
    if ! mountpoint -q /mnt/backup; then
        log "CRITICAL" "🛑 Backup Drive not mounted! Aborting."
        exit 1
    fi

    
    # 2. Borg repository existence
    
    if [ ! -d "$BORG_REPO" ]; then
        log "CRITICAL" "🛑 Borg Repo not found at $BORG_REPO!"
        exit 1
    fi

    
    # 3. Authenticate into Borg
    #    The passphrase is injected into the environment so no manual entry occurs.
    
    if [ -f "$PASSPHRASE_FILE" ]; then
        export BORG_PASSPHRASE=$(cat "$PASSPHRASE_FILE")
    else
        log "CRITICAL" "🛑 Passphrase file missing at $PASSPHRASE_FILE. Cannot authenticate."
        exit 1
    fi

    
    # 4. Query repository metadata
    #    borg info confirms the repo is readable, valid, and not corrupted.

    log "INFO" "📡 Querying repository metadata..."

    if borg_info=$(borg info "$BORG_REPO" 2>&1); then
        log "SUCCESS" "✅ Repository is accessible and structurally valid."
    else
        log "ERROR" "🛑 Borg returned an error!"
        echo "$borg_info" | while read -r line; do log "ERROR" "   → $line"; done
        exit 1
    fi

    # 5. Freshness Check
    #    Ensures that the most recent snapshot is from Today or Yesterday.
    #    This is a lightweight heuristic for daily backup health.
    
    last_archive=$(borg list --short "$BORG_REPO" | tail -n 1)

    if [ -n "$last_archive" ]; then

        archive_time=$(borg info "$BORG_REPO::$last_archive" \
                        | grep "Time (start)" \
                        | awk '{print $3, $4}')

        log "INFO" "ℹ️ Latest Snapshot: $last_archive ($archive_time)"

        current_date=$(date +%Y-%m-%d)
        yesterday=$(date -d "yesterday" +%Y-%m-%d)

        if [[ "$last_archive" == *"$current_date"* ]] || [[ "$last_archive" == *"$yesterday"* ]]; then
            log "SUCCESS" "✅ Backup is fresh (Today or Yesterday)."
        else
            log "WARNING" "⚠️ Backup may be stale! Last snapshot: $last_archive"
        fi

    else
        log "WARNING" "⚠️ No archives found in Borg repository!"
    fi

}

main
