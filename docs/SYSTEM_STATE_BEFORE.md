#!/usr/bin/env bash
# ==============================================================================
# 🖖 NAS PROJECT — SYSTEM STATE (BEFORE)
# ==============================================================================
# Purpose:
#   Sanitised snapshot of the NAS *before* the automation + audit layers
#   were fully implemented.
#
#   This is the "configured but human-dependent" era:
#   - Disks and mounts are in place.
#   - Core services exist (Plex / MiniDLNA / NFS / Samba).
#   - Security tools are present (UFW / Mullvad / ClamAV),
#     but observability + drift-resistance are not yet unified.
#
# Audience:
#   Engineers or hiring managers who want evidence of real-world change.
#
# Scope:
#   Storage layout, mounts, network posture, open services,
#   and the early shape of the control-plane.
#
# Path:
#   docs/SYSTEM_STATE_BEFORE.md
# ==============================================================================


## 🔗 Related Docs

├── START_HERE.md  
├── ARCHITECTURE_OVERVIEW.md
├── SERVICE_GRAPH.md  
├── SYSTEM_STATE_BEFORE.md ← You are here 
├── SYSTEM_STATE_AFTER.md  
└── PROJECT_JOURNEY.md  

# 🎛️ System Identity (Sanitised)

Host: `<NAS_HOSTNAME>` (Dell Wyse 5070 Thin Client)  
OS: `<Ubuntu/Xubuntu 24.04.x LTS>`  
User: `<NAS_USER>`  

> All UUIDs, IPs, MACs, hostnames, usernames, and friendly names are sanitised. :contentReference[oaicite:3]{index=3}


# 1. 📦 Mounts Under `/mnt`

$ sudo mount | grep /mnt
/dev/<SYS_DEVICE>     on /mnt/nas_sys_core type ext4 (...)
/dev/<BACKUP_DEVICE>  on /mnt/backup       type btrfs (...)
/dev/<MEDIA_DEVICE>   on /mnt/media        type ext4 (...)
/dev/<MEDIA2_DEVICE>  on /mnt/media_ro     type ext4 (...)
storage               on /mnt/storage      type fuse.mergerfs (...)

**Interpretation:**

/mnt/nas_sys_core → early control-plane root (logs, configs, scripts).

/mnt/backup → btrfs pool holding subvolumes like @nas, @tower, @logs.

/mnt/media + /mnt/media_ro → physical media disks.

/mnt/storage → MergerFS overlay consumed by media services. 

---

# 2. 💽 Disk Layout (lsblk)

$ sudo lsblk -f
<OS_DISK>    vfat  <EFI_UUID>     /boot/efi
<OS_DISK>    ext4  <ROOT_UUID>    /
<MEDIA_DISK> ext4  MEDIA          <MEDIA_UUID>   /mnt/media
<MEDIA2_DISK>ext4  MEDIA2         <MEDIA2_UUID>  /mnt/media_ro
<BACKUP_DISK>btrfs BACKUP_POOL    <BACKUP_UUID>  /mnt/backup
<BACKUP_DISK>btrfs BACKUP_POOL    <BACKUP_UUID>
<SYSLOG_DISK>ext4  SYSLOGS        <SYS_UUID>     /mnt/nas_sys_core


Physical topology is already sensible here.
The “before” story is not about new disks — it’s about new governance over them. 

---

# 3. 📊 Filesystem Usage (df -hT)

$ sudo df -hT
/dev/<ROOT_PART>         ext4   <SIZE>  <USED>  <AVAIL>  <PCT> /
/dev/<SYS_PART>          ext4   <SIZE>  <USED>  <AVAIL>  <PCT> /mnt/nas_sys_core
/dev/<BACKUP_PART>       btrfs  <SIZE>  <USED>  <AVAIL>  <PCT> /mnt/backup
/dev/<MEDIA_PART>        ext4   <SIZE>  <USED>  <AVAIL>  <PCT> /mnt/media
/dev/<MEDIA2_PART>       ext4   <SIZE>  <USED>  <AVAIL>  <PCT> /mnt/media_ro
storage                  fuse   <SIZE>  <USED>  <AVAIL>  <PCT> /mnt/storage

In “before”, logs and snapshots aren’t yet a strong, centralised narrative. 

# 4. 🧬 Btrfs Layout (Backup Pool)

$ sudo btrfs filesystem df /mnt/backup
Data, ...      total=<X>, used=<Y>
Metadata, ...  total=<X>, used=<Y>

$ sudo btrfs subvolume list /mnt/backup
@nas     → config + control-plane backups
@tower   → Borg repo + related bundles
@logs    → mirrored logs target
@scratch → temporary staging

This structure exists, but the automation ecosystem that feeds it is still embryonic. 

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

VPN is present, but the automated cloak verification isn’t yet part of a formal boot contract. 

---

# 6. 🧾 Host Identity

$ sudo hostnamectl
Hostname: <NAS_HOSTNAME>
Chassis: desktop
Model: Dell Wyse 5070 Thin Client
Firmware: <FW_VERSION>

---

# 7. 🔐 UFW Firewall State

$ sudo ufw status verbose
Status: active
Default: deny (incoming), allow (outgoing)

LAN services allowlist (example):
- 2049/tcp+udp (NFS)
- 445/tcp (Samba)
- 8200/tcp (MiniDLNA)
- 32400/tcp (Plex)

The rules may be correct — but without stage enforcement and drift checks,
correctness is state, not policy. 

---

# 8. 🧵 Open Ports Snapshot (Trimmed)
$ sudo ss -tulpen
tcp  8200   → MiniDLNA
tcp  2049   → NFS
tcp  32400  → Plex
tcp  445    → Samba
udp  1900   → DLNA SSDP

---

# 9. 📤 NFS Exports (Sanitised)

$ sudo exportfs -v
/mnt/backup/@tower  <LAN_SUBNET>(rw,root_squash,...)
/mnt/storage        <LAN_SUBNET>(rw,root_squash,...)

---

# 10. 📡 MiniDLNA Settings (Key Lines)

$ sudo grep -E '^(media_dir|friendly_name|port)' /etc/minidlna.conf
media_dir=/mnt/storage
friendly_name=<DLNA_FRIENDLY_NAME>
port=8200

---

# 11. 🛡️ ClamAV Baseline Presence

$ sudo ls -lh /var/log/clamav/
clamav.log
clamd.log
freshclam.log

AV exists, but routine scanning + consistent “hits-only” logging
is not yet guaranteed by the system’s weekly cadence. 

---

# 12. 🧠 Early Control-Plane Shape

/mnt/nas_sys_core/
├── config_backups/
│   └── <stage>_bak/  (partial / early)
└── logs_files/
    └── (not yet a complete per-stage constellation)


The “before” control-plane is a promising staging zone.
The “after” control-plane becomes a self-checking brainstem. 

**✨ TL;DR**

Before automation, this NAS already had the right organs.

What it lacked was a nervous system:
scheduled checks, consistent logs, and drift-aware discipline.

# ==============================================================================
# 🛑 END
# ==============================================================================