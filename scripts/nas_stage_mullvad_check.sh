#!/usr/bin/env bash
# ==============================================================================
# 🖖 GEMINI-NAS: MULLVAD CLOAK CHECK
# ==============================================================================
# Purpose:  The “Cloaking Device” Monitor.
#           Ensures that the Mullvad VPN daemon is alive and that the expected
#           WireGuard interface is active. If the cloak flickers, the script
#           attempts an automatic re-engagement.
#
# Philosophy:
#   • Fail-closed – if VPN is down, automation should not silently continue.
#   • Gentle recovery – allow grace periods during sluggish boots.
#   • Minimal touching – do only what is necessary to verify the cloak.
#
# Path:     /usr/local/sbin/nas_stage_mullvad_check.sh
# Logs:     /mnt/nas_sys_core/logs_files/mullvad.log
# Mirror:   /mnt/backup/@logs/mullvad.log
# ==============================================================================

set -uo pipefail

# ------------------------------------------------------------------------------
# ⚙️ Configuration & Interfaces
# ------------------------------------------------------------------------------

LOG_DIR="/mnt/nas_sys_core/logs_files"
BACKUP_LOG_DIR="/mnt/backup/@logs"

LOG_FILE="${LOG_DIR}/mullvad.log"
CORE_LOG="${LOG_DIR}/full_core.log"

# The actual interface Mullvad creates on your Xubuntu system

VPN_IFACE="wg0-mullvad"

# Extra delay to avoid false negatives on slow boots

GRACE_SECONDS=15

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
        echo "$entry" >> "${BACKUP_LOG_DIR}/mullvad.log"
    fi
}


# ------------------------------------------------------------------------------
# 🚀 Cloak Diagnostics & Restoration
# ------------------------------------------------------------------------------
# Checks:
#   1. Is the Mullvad daemon alive?
#   2. Is the WireGuard interface up?
#   3. If not, attempt soft reconnection via `mullvad connect`.


main() {
    : > "$LOG_FILE"   # Reset log for this run

    log "INFO" "🛰️ Initiating Mullvad Cloak Diagnostic…"

    # --------------------------------------------------------------------------
    # 1. Daemon Status
    # --------------------------------------------------------------------------

    if systemctl is-active --quiet mullvad-daemon; then
        log "INFO" "✅ Mullvad daemon active."
    else
        log "WARNING" "⚠️ Mullvad daemon stopped. Attempting restart…"

        if systemctl restart mullvad-daemon; then
            log "INFO" "⏳ Mullvad daemon restarted. Allowing ${GRACE_SECONDS}s to settle…"
            sleep "$GRACE_SECONDS"
        else
            log "CRITICAL" "🛑 Failed to start Mullvad daemon. Cloak offline."
            exit 1
        fi
    fi

    # --------------------------------------------------------------------------
    # 2. WireGuard Tunnel Interface
    # --------------------------------------------------------------------------

    if ip link show "$VPN_IFACE" >/dev/null 2>&1; then
        log "SUCCESS" "✅ Cloak engaged. Interface $VPN_IFACE present."
        return 0
    fi

    # If interface missing → attempt reconnection

    log "WARNING" "⚠️ Interface $VPN_IFACE missing. Attempting reconnection…"

    # Mullvad CLI availability check

    if ! command -v mullvad >/dev/null 2>&1; then
        log "CRITICAL" "🛑 'mullvad' command not found. Cannot re-engage cloak."
        exit 1
    fi

    mullvad connect
    log "INFO" "⏳ Reconnection issued. Allowing ${GRACE_SECONDS}s for tunnel negotiation…"
    sleep "$GRACE_SECONDS"

    # Recheck interface
    
    if ip link show "$VPN_IFACE" >/dev/null 2>&1; then
        log "SUCCESS" "✅ Cloak re-established successfully."
    else
        log "CRITICAL" "🛑 Cloak failure. VPN interface could not be raised."
        exit 1
    fi
}

main

# ==============================================================================
# 🛑 END
# ==============================================================================
