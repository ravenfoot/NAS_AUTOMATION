#!/usr/bin/env bash
# ==============================================================================
# 🖖 GEMINI-NAS: UFW SHIELD CHECK
# ==============================================================================
# Purpose:  The "Shield Generator."
#
#           Ensures the Uncomplicated Firewall (UFW) is:
#             • Active
#             • Enforcing rules correctly
#             • Explicitly allowing the LAN subnet
#
#           Why this matters:
#             If the LAN subnet rule disappears and UFW defaults to DENY,
#             the NAS can vanish from the network — SSH, Samba, Plex… gone.
#             This script acts as a pre-flight verification to prevent
#             accidental "self-isolation."
#
# Path:     /usr/local/sbin/nas_stage_ufw_check.sh
# Logs:     /mnt/nas_sys_core/logs_files/ufw.log
# Mirror:   /mnt/backup/@logs/ufw.log
# ==============================================================================

set -uo pipefail

# ------------------------------------------------------------------------------
# ⚙️ Configuration
# ------------------------------------------------------------------------------

LOG_DIR="/mnt/nas_sys_core/logs_files"
BACKUP_LOG_DIR="/mnt/backup/@logs"

LOG_FILE="${LOG_DIR}/ufw.log"
CORE_LOG="${LOG_DIR}/full_core.log"

# -- Critical Subnet Placeholder --
# Replace <LAN_SUBNET> with your safe, non-identifying subnet (e.g. 192.168.0.0/24).
# Leaving it as a placeholder is ideal for GitHub sanitisation.
CRITICAL_SUBNET="<PLACE_HOLDER_IP>"

# Ensure log directories exist
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

    # Print for systemctl/journalctl visibility

    echo "$entry"

    # Write to local logs

    echo "$entry" >> "$LOG_FILE"
    echo "$entry" >> "$CORE_LOG"

    # Mirror to backup drive (only if still online!)

    if [ -d "$BACKUP_LOG_DIR" ] \
       && [ -w "$BACKUP_LOG_DIR" ] \
       && mountpoint -q "/mnt/backup"; then
        echo "$entry" >> "${BACKUP_LOG_DIR}/ufw.log"
    fi
}


# ------------------------------------------------------------------------------
# 1. Shield Status Verification
# ------------------------------------------------------------------------------

ensure_ufw_active() {
    log "INFO" "🛡️ Verifying shield generator status…"

    if ufw status | grep -q "Status: active"; then
        log "INFO" "✅ UFW shield is active."
    else
        log "WARNING" "⚠️ UFW shield DOWN. Attempting restart…"

        # `yes` auto-approves the SSH warning

        if yes | ufw enable 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "✅ UFW successfully re-enabled. Shields up."
        else
            log "CRITICAL" "🛑 Shield generator failure — UFW could not be enabled."
            exit 1
        fi
    fi
}


# ------------------------------------------------------------------------------
# 2. ACL Anti-Lockout Verification
# ------------------------------------------------------------------------------

check_rules() {
    log "INFO" "🔐 Auditing access control lists…"

    # We only check presence — not full rule correctness

    if ufw status | grep -q "$CRITICAL_SUBNET"; then
        log "INFO" "✅ LAN access rule present for $CRITICAL_SUBNET."
    else
        log "WARNING" "⚠️ Critical subnet ($CRITICAL_SUBNET) not found!"
        log "WARNING" "⚠️ If default policy is DENY, remote access may fail."
    fi
}


# ==============================================================================
# 🚀 MAIN EXECUTION FLOW
# ==============================================================================

main() {
    # Reset the log for this run
    : > "$LOG_FILE"

    log "INFO" "🛡️ Beginning UFW shield verification cycle…"

    ensure_ufw_active
    check_rules
}

main

# ==============================================================================
# 🛑 END
# ==============================================================================
