#!/usr/bin/env bash
# ==============================================================================
# 🖖 GEMINI-NAS: MEDIA SERVICES MAINTENANCE (SURGICAL)
# ==============================================================================
# Purpose:  The “Librarian's Tune-Up.”
#           MiniDLNA is a simple beast: when metadata drifts or clients start
#           showing the wrong episodes, the most reliable fix is a surgical
#           refresh — stop, purge DB, restart, rebuild.
#
#           Behaviour Philosophy:
#             • Keep the operation predictable.
#             • Touch only what is necessary.
#             • Confirm each media-service beacon is alive post-operation.
#
# Path:     /usr/local/sbin/nas_stage_dlna_maint.sh
# Logs:     /mnt/nas_sys_core/logs_files/dlna.log
# Mirror:   /mnt/backup/@logs/dlna.log
# ==============================================================================

set -uo pipefail

# ------------------------------------------------------------------------------
# ⚙️ Configuration & Paths
# ------------------------------------------------------------------------------

LOG_DIR="/mnt/nas_sys_core/logs_files"
BACKUP_LOG_DIR="/mnt/backup/@logs"

LOG_FILE="${LOG_DIR}/dlna.log"
CORE_LOG="${LOG_DIR}/full_core.log"

# MiniDLNA identifiers (Adjusted for Xubuntu environment)

MINIDLNA_SERVICE="minidlna"
MINIDLNA_DB="/var/cache/minidlna/files.db"

# NOTE: art_cache intentionally preserved for faster rebuilds.


# Storage location that must exist before anything proceeds

STORAGE_MOUNT="/mnt/storage"

# Create log dirs early

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

    echo "$entry" | tee -a "$LOG_FILE" "$CORE_LOG" >/dev/null

    if [ -d "$BACKUP_LOG_DIR" ] && [ -w "$BACKUP_LOG_DIR" ]; then
        echo "$entry" >> "${BACKUP_LOG_DIR}/dlna.log"
    fi
}


# ------------------------------------------------------------------------------
# 📺 1. MiniDLNA Surgical Refresh
# ------------------------------------------------------------------------------
# This is the precision operation:
#   1) Ensure storage is online.
#   2) Stop MiniDLNA (release locks, reset watcher states).
#   3) Delete only the core database (files.db).
#   4) Restart and allow indexing to begin.
#   5) Confirm service heartbeat.

refresh_minidlna() {
    log "INFO" "📡 Initiating MiniDLNA Surgical Refresh…"

    # --- Verify storage availability ---

    if ! mountpoint -q "$STORAGE_MOUNT"; then
        log "CRITICAL" "🛑 Cargo bay ($STORAGE_MOUNT) not mounted. Aborting."
        return 1
    fi

    # --- Stop MiniDLNA safely ---

    if systemctl is-active --quiet "$MINIDLNA_SERVICE"; then
        log "INFO" "🧨 Standing down MiniDLNA service..."
        systemctl stop "$MINIDLNA_SERVICE"
        sleep 5
    else
        log "INFO" "ℹ️ MiniDLNA already offline. Proceeding to DB refresh."
    fi

    # --- Purge database (surgical reset, preserve art_cache) ---

    if [ -f "$MINIDLNA_DB" ]; then
        rm -f "$MINIDLNA_DB"
        log "INFO" "🧠 MiniDLNA database purged (files.db)."
    else
        log "WARNING" "⚠️ No files.db found — nothing to purge."
    fi

    # --- Restart and settle ---

    log "INFO" "🚀 Restarting MiniDLNA…"
    systemctl start "$MINIDLNA_SERVICE"

    log "INFO" "⏳ Allowing 10 seconds for MiniDLNA to settle and begin indexing…"
    sleep 10

    if systemctl is-active --quiet "$MINIDLNA_SERVICE"; then
        log "SUCCESS" "✅ MiniDLNA online and rebuilding index."
    else
        log "ERROR" "🛑 MiniDLNA failed to restart."
    fi
}


# ------------------------------------------------------------------------------
# 📡 2. Cargo Bay Beacons (DLNA / Plex / SMB / NFS)
# ------------------------------------------------------------------------------
# Post-operation verification: ensure all media-service ports are alive.
# These act like heartbeat monitors for your media stack.


check_service_beacons() {
    log "INFO" "🛰️ Verifying service beacons (DLNA / Plex / SMB / NFS)…"

    # DLNA (MiniDLNA) – Port 8200

    if ss -tuln | grep -q ":8200"; then
        log "INFO" "✅ MiniDLNA Beacon active (Port 8200)."
    else
        log "ERROR" "🛑 MiniDLNA Beacon silent."
    fi

    # Plex – Port 32400

    if ss -tuln | grep -q ":32400"; then
        log "INFO" "✅ Plex Server active (Port 32400)."
    else
        log "WARNING" "⚠️ Plex Beacon silent."
    fi

    # Samba (SMB) – Port 445

    if ss -tuln | grep -q ":445"; then
        log "INFO" "✅ Samba Export active (Port 445)."
    else
        log "WARNING" "⚠️ Samba Export silent."
    fi

    # NFS – Port 2049

    if ss -tuln | grep -q ":2049"; then
        log "INFO" "✅ NFS Export active (Port 2049)."
    else
        log "WARNING" "⚠️ NFS Export silent."
    fi
}


# ==============================================================================
# 🚀 MAIN EXECUTION FLOW
# ==============================================================================

main() {
    : > "$LOG_FILE"   # Reset log for this run

    log "INFO" "🔧 Media Services Maintenance Cycle initiated."

    refresh_minidlna
    check_service_beacons
}

main

# ==============================================================================
# 🛑 END
# ==============================================================================
