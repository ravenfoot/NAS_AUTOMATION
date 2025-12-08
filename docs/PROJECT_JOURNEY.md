#!/usr/bin/env bash
# ==============================================================================
# 🖖 NAS PROJECT — PROJECT JOURNEY
# ==============================================================================
# Purpose:  Narrative walkthrough of how this NAS evolved from
#           “just mount my drives” into a deterministic, self-auditing home lab.
#
# Audience: Engineers, recruiters, tinkerers. Anyone trying to understand
#           how a chaotic pile of services became a modular control-plane.
#
# Path:     docs/PROJECT_JOURNEY.md
# Related:  ARCHITECTURE_OVERVIEW.md • SERVICE_GRAPH.md
#           SYSTEM_STATE_BEFORE.md • SYSTEM_STATE_AFTER.md
# ==============================================================================


## 🔗 Related Docs

├── START_HERE.md  
├── ARCHITECTURE_OVERVIEW.md  
├── SERVICE_GRAPH.md  
├── SYSTEM_STATE_BEFORE.md  
├── SYSTEM_STATE_AFTER.md  
└── PROJECT_JOURNEY.md ← You are here


## 📖 How to Use This Document

If you're browsing the repo fresh:

- Start with `START_HERE.md` — for a quick guide on what is what.  
- Read `ARCHITECTURE_OVERVIEW.md` — for an overview of the structure of the project.  
- Glance at `SERVICE_GRAPH.md` — the “when & why” of the system.  
- Then return here — for the “how this system came into existence.”  

**Code Locations:**

→ `scripts/` — stage logic  
→ `systemd/` — services + timers  
→ `configs_sanitised/` — drift-audit baselines  

---

## 🗂 Contents

1. **Problem & Context**  
2. **Success Criteria**  
3. **Initial Architecture (V1)**  
4. **Key Decisions & Trade-offs**  
5. **Breakpoints & Fixes**  
6. **AI as a Tool**  
7. **Testing & Evidence**  
8. **Security & Data Handling**  
9. **Operations**  
10. **Impact**  
11. **What I'd Do Next / Known Gaps**  
12. **Repo Tour**  

---


# 1. ❓ Problem & Context

## **1.1 What Was Broken / Inefficient?**

Starting hardware: a **Dell Wyse 5070 thin client**, Xubuntu, hand-me-down drives, and a simple goal:  
**turn it into a media centre** to pair with a projector.

**Except:**

- Mounts were manual and flaky (`/mnt/media`, `/mnt/media_ro`, `/mnt/storage`, `/mnt/backup`).  
- Backups relied on human memory (“oh yeah… run Borg”).  
- Service startup order was a dice roll.  
- No authoritative config source.  
- No mechanism to detect drift.  
- No proof of safety after boot.  
- No logs to reconstruct failures.  

The system *worked*, but the operator (me) was doing all the heavy lifting.

**My needs:**  
`<Automation>` `<Determinism>` `<Confidence>` `<Observability>`

---

## **1.2 Who Benefits?**

- **Me (operator/SRE):** Less hand-holding, more reliability.  
- **Reviewers & recruiters:** A real architecture case study.  
- **Future me:** Can understand system behaviour at a glance in two years.  

---

## **1.3 Hard Constraints**

- **Hardware:** Low-power Wyse 5070, mixed storage, limited RAM.  
- **Time & emotional bandwidth:** A demanding job + family life.  
- **Skill profile:** Linux/Python/Bash comfortable; wanted maintainable, human-legible automation.  
- **Legacy services:** MergerFS, Mullvad, Plex, Samba, NFS, MiniDLNA already in use.  

---


# 2. 🎯 Success Criteria

## **2.1 Technical Goals**

- All **mountpoints** correct after boot.  
- **SMART** drive checks.  
- **Borg backups** validated weekly.  
- **Btrfs:** two devices online, zero errors.  
- **UFW:** deny incoming; LAN rules preserved.  
- **Mullvad:** tunnel active with LAN access unbroken.  
- **Stage scripts** must be light, deterministic, and debuggable.  
- Scheduled maintenance must happen *overnight*, not during usage hours.  

---

## **2.2 Human-Focused Goals**

- One log per script under `/mnt/nas_sys_core/logs_files/`.  
- A unified `full_core.log`.  
- No secrets in the public repo.  
- Documentation that reads like a small internal platform, not a hobby dump.  

---


# 3. 🏗️ Initial Architecture (V1)

## **3.1 Shape of V1**

- **One giant script:** `/usr/local/bin/NAS_Lifecycle.sh`  
- Logic duplicated (e.g. in `/etc/fstab`)  
- No config snapshots  
- No systemd orchestration  
- btrfs mounted incorrectly (device names instead of UUIDs)  
- MergerFS double-mounted  

**Verdict:** V1 was a monolith — workable but fragile.

---

## **3.2 Why It Looked Like That**

- Bash is fast to iterate on.  
- systemd felt “heavy” at first.  
- The goal was “make it work,” not “build a control-plane.”  
- V1 exposed all the pain points V2 solved.  

---


# 4. 🔑 Key Decisions & Trade-offs

## **4.1 Creating a Control-Plane Partition**

**Chosen:** `/mnt/nas_sys_core/`  

- Holds `config_backups/`, logs, and stage scripts.  
- Independent of OS reinstall.  
- Clear boundary between **truth** and **live state**.  

---

## **4.2 systemd Over Cron**

**Chosen:** systemd  

- Explicit ordering (`After=`, `Requires=`).  
- Built-in logging and retry behaviour.  
- Clean temporal separation of stages.  
- Boot, shutdown, daily, weekly units.  

---

## **4.3 Btrfs Mounts by UUID**

**Chosen:** UUID-based mounts  

- Avoids “already mounted” conflicts.  
- Kernel assembles multi-device pools correctly.  

---

## **4.4 Drift Detection vs File Overwrites**

**Chosen:** Compare-and-warn (Audit Stage)  

- Never overwrite whole config files.  
- Only track meaningful blocks.  
- Protect against distro updates breaking things.  

---

## **4.5 VPN + UFW Boot Ordering**

**Chosen:** Explicit dependency graph  

- Tunnel + firewall rise cleanly.  
- Prevents “accidental naked boot.”  

---


# 5. 🩹 Breakpoints & Fixes

## **5.1 Duplicate MergerFS / Btrfs Issues**

- Both `fstab` and scripts were mounting devices.  
- Fixed via systemd mount units.  
- Scripts now *verify* instead of *mount*.  

**Principle:** init system owns mounts.

---

## **5.2 MiniDLNA Stale Cache**

- Clients saw outdated media.  
- Added nightly database rebuild (“Surgical Mode”).  
- Logged and visible in `full_core.log`.  

**Principle:** caches drift unless refreshed.

---

## **5.3 Mullvad Path Bug (AI Mismatch)**

AI suggested incorrect defaults.  
**Reality:** `/etc/mullvad-vpn/`  

Backups now only include stable, verifiable config paths.

**Principle:** AI provides typical patterns — *not guarantees*.

---

## **5.4 Boot Verification**

Previously no proof the system was healthy.

Now validated via:

- SMART checks  
- Mount verification  
- Btrfs device count  
- Health summary  

**Principle:** boot is a checkpoint.

---

## **5.5 Audit Stage**

Without drift detection, automation accelerates chaos.

Added weekly diffing of configs/scripts vs “golden baseline.”

**Principle:** trust, but verify.  

---


# 6. 🤖 AI as a Tool

## **6.1 What Worked**

- Architecture ideation  
- Drafting scripts  
- Systemd skeletons  
- Reasoning cross-checks  
- Inventory generation  

---

## **6.2 What Was Rejected**

- Wrong Mullvad paths  
- Over-clever Bash  
- Whole-file overwrites  
- Anything non-deterministic or hard to debug  

---

## **6.3 How Validation Happened**

- Manual diffing  
- Live system inspection  
- Dry-runs before enabling timers  
- One script → test → refine → next script  

AI accelerated development — I retained architectural ownership.

---


# 7. 🧪 Testing & Evidence

## **7.1 System State Snapshots**

- `SYSTEM_STATE_BEFORE.md`  
- `SYSTEM_STATE_AFTER.md`  

Derived from real command output and sanitised.

---

## **7.2 Functional Tests**

- Offline drive → btrfs degraded detection  
- DLNA rebuild validated on clients  
- VPN/UFW layered test  
- Local dry-runs  

---

## **7.3 Inventory Tools**

Python-based tree + config extractor ensures documentation fidelity.

---


# 8. 🔐 Security & Data Handling

- No secrets committed.  
- Mullvad keys/config constrained.  
- UFW default deny.  
- LAN-only rules preserved.  
- Partitioned control-plane reduces attack surface.  

---


# 9. 🛠️ Operations

### Weekly Lifecycle

- **Boot:** verify mounts + hardware  
- **Nightly:** DLNA maintenance  
- **Weekly:** updates, ClamAV scan, Borg integrity, drift audit  
- **Shutdown:** controlled unmount sequence  

### Monitoring

- Logs: per-stage + unified  
- `systemctl status nas-*`  
- `journalctl -u nas-*`  

---


# 10. 📈 Impact

## **10.1 Quantitative**

- Manual mount failures: near zero  
- Media index stability: consistent  
- Backups: regular + validated  
- Debugging: inspect logs, not guess  

---

## **10.2 Qualitative**

- The NAS feels like a **platform**, not a hobby script.  
- Repo is legible to engineers and hiring managers.  
- Demonstrates **systems thinking**, not just scripting.  

---


# 11. 🚧 What I'd Do Next

- Add metrics exporter (Prometheus/Grafana lite)  
- Increase managed config blocks  
- More synthetic failure testing  
- Bare-metal provisioning workflow  
- Off-site Borg  

---


# 12. 🗺️ Repo Tour
nas-automation/
├── README.md
├── docs/
│   ├── ARCHITECTURE_OVERVIEW.md
│   ├── SERVICE_GRAPH.md
│   ├── PROJECT_JOURNEY.md   # ← You are here
│   ├── SYSTEM_STATE_BEFORE.md
│   └── SYSTEM_STATE_AFTER.md
├── scripts/
│   ├── boot/
│   ├── shutdown/
│   ├── mullvad/
│   ├── ufw/
│   ├── dlna/
│   ├── borg/
│   ├── clamav/
│   ├── update/
│   └── audit/
├── systemd/
│   ├── services/
│   └── timers/
├── configs_sanitised/
└── tools/

# ==============================================================================
# 🛑 END
# ==============================================================================
