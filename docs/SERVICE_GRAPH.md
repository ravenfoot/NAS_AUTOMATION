#!/usr/bin/env bash
# ==============================================================================
# 🖖 NAS PROJECT — SERVICE GRAPH
# ==============================================================================
# Purpose: Map *when* each automation stage runs and *how* the chain is ordered.
#          This is the temporal blueprint of the NAS control-plane:
#          Boot → Nightly → Weekly → Shutdown.
#
# Audience: SRE / DevOps / backend engineers reviewing deterministic automation,
#           plus hiring managers who want a fast mental model.
#
# Scope: High-level orchestration (systemd) + stage intent + failure posture.
# ==============================================================================

**Core Idea:** This NAS behaves like a small control-plane.  
Each stage is **modular**, **auditable**, and **time-bound** via systemd.

**What this doc answers:**
- What runs **at boot** vs **nightly** vs **weekly** vs **shutdown**.
- Which checks are **sanity-only** vs **maintenance-heavy**.
- Why the order is designed to **minimise blast radius**.

---

## 🔗 Related Docs

├── START_HERE.md  
├── NAS_ARCHITECTURE_OVERVIEW.md  
├── SERVICE_GRAPH.md ← You are here  
├── SYSTEM_STATE_BEFORE.md  
├── SYSTEM_STATE_AFTER.md  
└── PROJECT_JOURNEY.md  

---

## 🧭 Temporal Spine (1-Week Model)

**Boot**  
→ Establish trust in the hardware + mounts + baseline security posture.

**Nightly**  
→ Low-risk media hygiene.

**Weekly**  
→ Security patching, malware scanning, backup integrity, drift auditing.

**Shutdown**  
→ Flush + unmount in correct order with log preservation.

---

# 1. ⚡ Boot Sequence

**Design intent:** *Sanity-first, minimal mutation.*  
Boot stages verify that the ship is real before it goes cruising.

**Key assumptions verified:**
- Drives present + healthy enough for service.
- Critical mounts are active.
- UFW is enforcing policy.
- Mullvad interface exists (leak prevention).

**Systemd overview (conceptual):**

local-fs.target
└─ nas-boot-verify.service
├─ SMART sweep
├─ mount verification
├─ BTRFS baseline checks
└─ fstab drift sanity

network.target
├─ nas-ufw-check.service
└─ nas-mullvad-check.service


**Stage scripts:**
- `scripts/boot/nas_stage_boot_verify.sh`
- `scripts/ufw/nas_stage_ufw_check.sh`
- `scripts/mullvad/nas_stage_mullvad_check.sh`

---

# 2. 🌙 Nightly Cycle

**Design intent:** *Low-risk maintenance.*  
Nightly jobs should be safe to rerun and cheap to fail.

**MiniDLNA “Surgical Refresh”:**
- Stop service  
- Purge `files.db`  
- Preserve `art_cache`  
- Restart  
- Confirm beacons (DLNA + SMB/NFS/Plex)

**Systemd overview:**

nas-dlna-nightly.timer
└─ nas-dlna-nightly.service
└─ nas_stage_dlna_maint.sh


---

# 3. 🔁 Weekly Maintenance

**Design intent:** *Deep integrity + security posture.*  
This is where you validate the *long-term health narrative* of the NAS.

**Weekly stages:**
- **Security updates** (patch discipline)
- **ClamAV sweep** (threat posture)
- **Borg integrity** (backup trust)
- **Audit** (configuration drift)

**Systemd overview (conceptual):**

nas-update-weekly.timer
└─ nas-update-weekly.service
└─ nas_stage_update.sh

nas-clamav-weekly.timer
└─ nas-clamav-weekly.service
└─ nas_stage_clamav_scan.sh

nas-borg-integrity.timer
└─ nas-borg-integrity.service
└─ nas_stage_borg_integrity.sh

nas-audit-weekly.timer
└─ nas-audit-weekly.service
└─ nas_stage_audit.sh


**Stage scripts:**
- `scripts/update/nas_stage_update.sh`
- `scripts/clamav/nas_stage_clamav_scan.sh`
- `scripts/borg/nas_stage_borg_integrity.sh`
- `scripts/audit/nas_stage_audit.sh`

---

# 4. 📴 Shutdown Sequence

**Design intent:** *Data-first landing.*  
This stage is about clean dismount of the storage stack.

**Unmount order is intentional:**
1. `/mnt/storage` (overlay)
2. `/mnt/media*` (payload)
3. `/mnt/backup` (last man standing)

**Systemd overview:**

nas-shutdown-stage.service
└─ nas_stage_shutdown.sh
├─ sync
├─ ordered unmount
└─ final sync


---

# 5. 📊 Execution Matrix (Fast Scan)

| Stage Script | Boot | Nightly | Weekly | Shutdown |
|-------------|------|---------|--------|----------|
| boot_verify | ✅ |  |  |  |
| ufw_check | ✅ |  |  |  |
| mullvad_check | ✅ |  |  |  |
| dlna_maint |  | ✅ |  |  |
| update |  |  | ✅ |  |
| clamav_scan |  |  | ✅ |  |
| borg_integrity |  |  | ✅ |  |
| audit |  |  | ✅ |  |
| shutdown |  |  |  | ✅ |

---

# 6. 🧯 Failure Philosophy

**Boot**  
- Logs hard signals.  
- The system may still reach multi-user state, but **trust is downgraded**.

**Nightly**  
- Expected to be safe + repeatable.  
- Failure impact is mostly *client-side convenience*.

**Weekly**  
- Failure indicates *policy drift* or *security/backup risk*.  
- System remains usable, but **admin action is recommended**.

**Shutdown**  
- Prioritises data safety and clean filesystems over speed.

---

# ✨ TL;DR

This service graph encodes one idea:

**A home NAS can behave like a tiny SRE-grade control-plane**  
when time, responsibilities, and trust boundaries are explicit.

Boot verifies reality.  
Nightly maintains convenience.  
Weekly defends integrity.  
Shutdown preserves the story.

---

# ==============================================================================
# 🛑 END
# ==============================================================================
