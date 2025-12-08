#!/usr/bin/env bash
# ==============================================================================
# 🖖 NAS PROJECT — ARCHITECTURE OVERVIEW
# ==============================================================================
# Purpose: High-level map of the system architecture and where each component lives.
# Audience: SRE / DevOps / backend engineers evaluating deterministic NAS automation.
# ==============================================================================

**Tech Stack:** Xubuntu • systemd • Bash • btrfs • MergerFS • Borg • Mullvad • UFW • MiniDLNA • Plex  
**Core Idea:** Converting an ad-hoc home NAS into a **modular, self-verifying control-plane**.

---

## 🔗 Related Docs

├── START_HERE.md  
├── ARCHITECTURE_OVERVIEW.md ← You are here  
├── SERVICE_GRAPH.md  
├── SYSTEM_STATE_BEFORE.md  
├── SYSTEM_STATE_AFTER.md  
└── PROJECT_JOURNEY.md  

---

# 1. 🗂 Repository Layout

**GitHub Tree (sanitised):**

nas-automation/
├── README.md
├── docs/
│   ├── ARCHITECTURE_OVERVIEW.md
│   ├── SERVICE_GRAPH.md
│   ├── SYSTEM_STATE_BEFORE.md
│   └── SYSTEM_STATE_AFTER.md
├── scripts/
│   ├── boot/        # System checks at startup
│   ├── ufw/         # Firewall rules baseline
│   ├── mullvad/     # VPN tunnel & route checks
│   ├── dlna/        # Media hygiene tasks
│   ├── borg/        # Backup verification
│   ├── clamav/      # Malware scans
│   ├── update/      # OS maintenance
│   └── shutdown/    # Controlled shutdown
├── systemd/
│   └── *.service / *.timer
└── configs_sanitised/
    └── subsystem_name_bak/
        ├── *_script/
        └── *_settings/


**Notes**

- `scripts/` → Modular stage logic; one job per script  
- `systemd/` → Timers + services binding logic to schedule  
- `configs_sanitised/` → Drift-audit baseline  
- `docs/` → Human-readable: diagrams, state snapshots, architecture

---

# 2. 🧠 Core Design Concepts

### System Purpose

The NAS automates:

- 🔐 Security: UFW baseline, Mullvad tunnel checks, ClamAV scans  
- 📡 Media hygiene: MiniDLNA resets, Plex/Samba/NFS beacon checks  
- 💾 Backup integrity: Borg repo validation  
- 🧪 Drift-resistance: Weekly config comparison against sanitised baseline  

### Principles

- **Modular** — One script per stage  
- **Fail-soft** — Logs issues without trying to "guess-fix"  
- **Deterministic** — systemd orchestration + temporal graph  
- **Auditable** — Everything logs to `logs_files/` + `full_core.log`  
- **Partitioned** — `/mnt/nas_sys_core/` as the control-plane root  

### Trust Boundaries

Only approved scripts may modify:

- 🔐 UFW rules  
- 🔐 Mullvad VPN state  
- 🔐 Core config files (`fstab`, MiniDLNA, ClamAV, Borg profile)

---

# 3. 🔁 Stage Scripts (What Runs When)

Each stage has:

- A script  
- A sanitised config snapshot  
- A systemd service/timer  

### Examples

#### 🧹 Boot Stage  
Verifies mounts, SMART health, fstab integrity.

#### 🔥 Firewall Stage (UFW)  
Checks baseline LAN rules + drift from snapshot.

#### 🧅 Mullvad Stage  
Confirms tunnel, routing table, policy bypass.

#### 📡 DLNA Stage  
Nightly index rebuild (surgical mode).

#### 🛡️ Borg Stage  
Ensures remote backup repo is present + recent.

#### 🧬 ClamAV Stage  
Weekly malware scan.

#### 🧰 Update Stage  
Weekly security updates + autoremove + reboot-flag check.

#### 📴 Shutdown Stage  
Sync → unmount → final sync → log.

#### 🕵️ Audit Stage  
Compares live system configs to sanitised snapshots.

---

# 4. 🧩 Systemd Wiring

| Unit | Purpose |
|------|---------|
| nas-boot-verify.service | Startup system checks |
| nas-ufw-check.service | Firewall baseline |
| nas-mullvad-check.service | VPN cloak verification |
| nas-dlna-nightly.service/timer | Media index maintenance |
| nas-borg-integrity.service | Backup check |
| nas-clamav-weekly.service | Malware scan |
| nas-update-weekly.service | Weekly updates |
| nas-integrity-weekly.service | Drift audit |
| nas-shutdown-stage.service | Controlled shutdown |

See: `docs/SERVICE_GRAPH.md`

---

# 5. 🧾 Sanitised Config Snapshots

Used for **drift detection**:

- UFW  
- Mullvad  
- MiniDLNA  
- ClamAV  
- Borg  
- fstab  

No secrets.  
Each snapshot = real configs used historically in the live system.

---

# 6. 📜 Logging & Observability

`/mnt/nas_sys_core/logs_files/` stores:

- Individual stage logs  
- `full_core.log` — merged telemetry  

All logs are also mirrored into the backup array while mounted.

---

# ✨ TL;DR

This repo is a **scripted, deterministic, self-auditing NAS brainstem**.

Clear boundaries, clear flow, clear observability.

# ==============================================================================
# 🛑 END
# ==============================================================================
