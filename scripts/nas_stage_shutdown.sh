#!/usr/bin/env bash
# ==============================================================================
# 🖖 GEMINI-NAS: SHUTDOWN STAGE (v1.2)
# ==============================================================================
# Purpose:  The “Landing Sequence.”
#
#           This script performs a controlled shutdown of all non-root
#           filesystems, ensuring:
#             1) Filesystem buffers are flushed.
#             2) Media & storage mounts are unmounted cleanly.
#             3) All logs are written to the backup array before it is detached.
#             4) The backup array is unmounted LAST — the “Last Man Standing.”
#
#           Behaviour Philosophy:
#             • Fail gracefully.
#             • Preserve logs until the final possible millisecond.
#             • Leave /mnt/nas_sys_core (root) to the OS.
#
# Path:     /usr/local/sbin/nas_stage_shutdown.sh
# Logs:     /mnt/nas_sys_core/logs_files/shutdown.log
# Mirror:   /mnt/backup/@logs/shutdown.log
# ==============================================================================

set -uo pipefail

# ------------------------------------------------------------------------------
# ⚙️ Configuration
# ------------------------------------------------------------------------------

LOG_DIR="/mnt/nas_sys_core/logs_files"
BACKUP_LOG_DIR="/mnt/backup/@logs"

LOG_FILE="${LOG_DIR}/shutdown.log"
CORE_LOG="${LOG_DIR}/full_core.log"

# Unmount order matters:
#   1. MergerFS overlay first (storage)
#   2. Underlying media disks second
#   3. Backup array last

TARGETS=(
    "/mnt/storage"
    "/mnt/media"
    "/mnt/media_ro"
)

BACKUP_TARGET="/mnt/backup"

# Ensure log directories exist early

mkdir -p "$LOG_DIR" "$BACKUP_LOG_DIR"


# ------------------------------------------------------------------------------
# 📝 Logging Utility
# ------------------------------------------------------------------------------

log() {
    local level="$1"
    local msg="$2"
    local ts
    ts=$(date +'%d/%m/%y %H:%M:%S')

    local entry="[$ts] [$level] $msg"

    # Write to stdout for systemctl visibility

    echo "$entry"

    # Local logs
    echo "$entry" >> "$LOG_FILE"
    echo "$entry" >> "$CORE_LOG"

    # Mirror to backup if still mounted (critical!)

    if [ -d "$BACKUP_LOG_DIR" ] \
       && [ -w "$BACKUP_LOG_DIR" ] \
       && mountpoint -q "$BACKUP_TARGET"; then
        echo "$entry" >> "${BACKUP_LOG_DIR}/shutdown.log"
    fi
}


# ==============================================================================
# 🚀 MAIN EXECUTION FLOW
# ==============================================================================

main() {

    # We append rather than clear: shutdown may be attempted multiple times.

    log "INFO" "🛌 Ship entering standby — initiating graceful shutdown sequence."

    # --------------------------------------------------------------------------
    # 1. FLUSH BUFFERS
    # --------------------------------------------------------------------------

    log "INFO" "💾 Syncing filesystem buffers (RAM → Disk)…"
    sync

    local error_count=0

    # --------------------------------------------------------------------------
    # 2. UNMOUNT STANDARD PAYLOAD
    # --------------------------------------------------------------------------
    # These mounts must go before the backup array is detached.

    for mnt in "${TARGETS[@]}"; do
        if mountpoint -q "$mnt"; then
            log "INFO" "🔻 Unmounting $mnt…"

            if umount "$mnt"; then
                log "SUCCESS" "✅ $mnt unmounted successfully."
            else
                log "ERROR" "🛑 Failed to unmount $mnt — device may be busy."
                log "WARNING" "⚠️ Attempting lazy unmount (umount -l)…"

                if ! umount -l "$mnt"; then
                    ((error_count++))
                    log "ERROR" "🛑 Lazy unmount failed for $mnt."
                else
                    log "SUCCESS" "⚠️ Lazy unmount succeeded for $mnt."
                fi
            fi
        else
            log "INFO" "ℹ️ $mnt already unmounted."
        fi
    done

    # --------------------------------------------------------------------------
    # 3. UNMOUNT BACKUP GRID (Last Man Standing)
    # --------------------------------------------------------------------------

    log "INFO" "🔻 Unmounting Backup Grid ($BACKUP_TARGET) — Final Log Transmission."

    if mountpoint -q "$BACKUP_TARGET"; then
        
        if umount "$BACKUP_TARGET"; then

            # This entry will appear only in local logs — backup is now offline.

            log "SUCCESS" "✅ Backup Grid unmounted. Communications severed."

        else
            log "ERROR" "🛑 Failed to unmount Backup Grid!"
            ((error_count++))
        fi

    else
        log "INFO" "ℹ️ Backup Grid was already offline."
    fi

    # --------------------------------------------------------------------------
    # 4. FINAL SYNC & STATUS REPORT
    # --------------------------------------------------------------------------
    
    sync

    if [ "$error_count" -eq 0 ]; then
        log "SUCCESS" "🛌 All decks report green. Safe to power down."
    else
        log "ERROR" "🛑 Shutdown sequence completed with $error_count ERRORS."
    fi
}

main

# ==============================================================================
# 🛑 END
# ==============================================================================
