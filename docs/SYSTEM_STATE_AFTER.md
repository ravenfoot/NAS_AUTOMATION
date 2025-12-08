#!/usr/bin/env bash
# ==============================================================================
# 🖖 NAS PROJECT — SYSTEM STATE (AFTER)
# ==============================================================================
# Purpose:
#   Sanitised snapshot of the NAS *after* the automation project is active.
#
#   This is the "governed and observable" era:
#   - Same physical layout.
#   - A real control-plane.
#   - Stage scripts + systemd wiring.
#   - Centralised logging.
#   - Weekly drift detection against sanitised baselines.
#
# Audience:
#   Engineers or hiring managers who want proof of operational maturity,
#   not just "it works on my NAS."
#
# Path:
#   docs/SYSTEM_STATE_AFTER.md
# ==============================================================================



## 🔗 Related Docs

├── START_HERE.md  
├── ARCHITECTURE_OVERVIEW.md  
├── SERVICE_GRAPH.md  
├── SYSTEM_STATE_BEFORE.md  
├── SYSTEM_STATE_AFTER.md ← You are here 
└── PROJECT_JOURNEY.md  


# 🎛️ System Identity (Sanitised)

Host: `<NAS_HOSTNAME>` (Dell Wyse 5070 Thin Client)  
OS: `<Ubuntu/Xubuntu 24.04.x LTS>`  
User: `<NAS_USER>`  

> All UUIDs, IPs, MACs, hostnames, usernames, and friendly names are sanitised. :contentReference[oaicite:16]{index=16}


# 1. 📦 Mounts Under `/mnt`

$ sudo mount | grep /mnt
/dev/<SYS_DEVICE>     on /mnt/nas_sys_core type ext4 (...)
/dev/<BACKUP_DEVICE>  on /mnt/backup       type btrfs (...)
/dev/<MEDIA_DEVICE>   on /mnt/media        type ext4 (...)
/dev/<MEDIA2_DEVICE>  on /mnt/media_ro     type ext4 (...)
storage               on /mnt/storage      type fuse.mergerfs (...)

**Interpretation:**

Physical mounts remain consistent.

The difference is who is in charge now:
systemd + stage scripts + audit policy. 

---

# 2. 💽 Disk Layout (lsblk)

$ sudo lsblk -f
<OS_DISK>     vfat   <EFI_UUID>      /boot/efi
<OS_DISK>     ext4   <ROOT_UUID>     /
<MEDIA_DISK>  ext4   MEDIA           <MEDIA_UUID>   /mnt/media
<MEDIA2_DISK> ext4   MEDIA2          <MEDIA2_UUID>  /mnt/media_ro
<BACKUP_DISK> btrfs  BACKUP_POOL     <BACKUP_UUID>  /mnt/backup
<SYSLOG_DISK> ext4   SYSLOGS         <SYS_UUID>     /mnt/nas_sys_core


Same ship. New autopilot.

---

# 3. 📊 Filesystem Usage (df -hT)

$ sudo df -hT
/dev/<ROOT_PART>    ext4   <SIZE>  <USED>  <AVAIL>  <PCT> /
/dev/<SYS_PART>     ext4   <SIZE>  <USED>  <AVAIL>  <PCT> /mnt/nas_sys_core
/dev/<BACKUP_PART>  btrfs  <SIZE>  <USED>  <AVAIL>  <PCT> /mnt/backup
storage             fuse   <SIZE>  <USED>  <AVAIL>  <PCT> /mnt/storage


Expect slightly higher /mnt/nas_sys_core usage post-automation
due to logs + snapshots + staged backups.

---

# 4. 🧬 Btrfs Layout (Backup Pool)

$ sudo btrfs subvolume list /mnt/backup
@nas     → Golden/Master config + script backups
@tower   → Borg repo + health context
@logs    → mirrored stage logs
@scratch → safe staging zone

“After” makes these subvols earn their keep on schedule.

---

# 5. 🌐 Network Configuration

IPs
$ sudo ip addr show
<LAN_IFACE>: <LAN_IP>/24
<wg_iface>:  <MULLVAD_IPV4>/32, <MULLVAD_IPV6>/128

Routes
$ sudo ip route
default via <LAN_GATEWAY> dev <LAN_IFACE>
<LAN_SUBNET> dev <LAN_IFACE>
<VPN_ROUTE> dev <wg_iface>

Key difference: boot-time Mullvad cloak checks
become a formal part of the boot contract.

---

# 6. 🔐 UFW Firewall Policy (Governed State)

$ sudo ufw status verbose
Status: active
Default: deny (incoming), allow (outgoing)

LAN services allowlist (example):
- 2049/tcp+udp (NFS)
- 445/tcp (Samba)
- 8200/tcp (MiniDLNA)
- 32400/tcp (Plex)


The rules are now backed by:
stage checks + config snapshots + drift detection.

---

# 7. 🧵 Open Ports Snapshot (Trimmed)

$ sudo ss -tulpen
tcp  8200   → MiniDLNA
tcp  2049   → NFS
tcp  32400  → Plex
tcp  445    → Samba
udp  1900   → DLNA SSDP

Same exposure pattern, now routinely verified.

---

# 8. 🧩 Systemd Stage Wiring (Sanitised)

$ systemctl list-timers --all | grep nas-
nas-dlna-nightly.timer
nas-update-weekly.timer
nas-clamav-weekly.timer
nas-borg-integrity.timer
nas-audit-weekly.timer

$ systemctl status nas-boot-verify.service
$ systemctl status nas-ufw-check.service
$ systemctl status nas-mullvad-check.service


The “service graph” is no longer conceptual.
It is enforced by timers + dependencies.

---

# 9. 🛡️ ClamAV Scan Behaviour

/mnt/nas_sys_core/logs_files/clamav.log

AV becomes a predictable weekly sweep with summarised logging.
The goal here is observability, not bloated remediation logic.

---

# 10. 🧠 Control-Plane (Mature Form)

/mnt/nas_sys_core/
├── config_backups/
│   ├── boot_bak/
│   ├── ufw_bak/
│   ├── mullvad_bak/
│   ├── dlna_bak/
│   ├── borg_bak/
│   ├── clamav_bak/
│   ├── update_bak/
│   ├── shutdown_bak/
│   └── audit_bak/
└── logs_files/
    ├── boot.log
    ├── ufw.log
    ├── mullvad.log
    ├── dlna.log
    ├── borg.log
    ├── clamav.log
    ├── update.log
    ├── audit.log
    ├── shutdown.log
    └── full_core.log


This is the heart of the project:
staged reality → live reality → golden master.

---

**✨ TL;DR**

After automation, the NAS becomes:

Modular (one script per stage)

Deterministic (systemd wiring matches declared intent)

Auditable (snapshots + weekly drift checks)

Observable (per-stage logs + full_core aggregation)

Same hardware.
A dramatically smarter nervous system.

# ==============================================================================
# 🛑 END
# ==============================================================================