#!/usr/bin/env bash
# ==============================================================================
# 🖖 NAS PROJECT — START HERE
# ==============================================================================
# Purpose: A reviewer-friendly guide to navigating this repository.
# Audience: Engineers, SREs, DevOps reviewers, hiring managers.
# ==============================================================================

If you're skimming this repository and want the **fast lane**, here’s the route:

---

## 🚀 Quick Navigation Order

1. **Architecture Overview**  
   `docs/ARCHITECTURE_OVERVIEW.md`  
   → What this system *is*, why it exists, and how components fit together.

2. **Service Graph**  
   `docs/SERVICE_GRAPH.md`  
   → The temporal layout: what runs at boot, nightly, weekly, shutdown.

3. **Before / After System State**  
   `docs/SYSTEM_STATE_BEFORE.md`  
   `docs/SYSTEM_STATE_AFTER.md`  
   → A clear view of how the NAS evolved from manual → automated control-plane.

4. **Scripts + systemd Units**  
   `scripts/`  
   `systemd/`  
   → The living logic of the system.

5. **Sanitised Config Snapshots**  
   `configs_sanitised/`  
   → Ground-truth references used for weekly drift-detection.

---

## 🔗 Related Documents

├── START_HERE.md  
├── ARCHITECTURE_OVERVIEW.md  
├── SERVICE_GRAPH.md  
├── SYSTEM_STATE_BEFORE.md  
├── SYSTEM_STATE_AFTER.md  
└── PROJECT_JOURNEY.md  

---

## 🧩 Understanding the Repo

### **1. Architecture**  
`docs/ARCHITECTURE_OVERVIEW.md`  
A high-level map of the purpose, boundaries, and structure.

### **2. Stage Order & Temporal Model**  
`docs/SERVICE_GRAPH.md`  
Shows which scripts run *when* and *why*.

### **3. State Change**  
`docs/SYSTEM_STATE_BEFORE.md`  
`docs/SYSTEM_STATE_AFTER.md`  
These demonstrate the real-world change in system behaviour.

### **4. Scripts**  
`scripts/`  
One folder per stage.  
Each script = one responsibility.

### **5. Systemd Units**  
`systemd/`  
Defines *when* each stage is activated.

### **6. Sanitised Configs**  
`configs_sanitised/`  
Baseline configuration snapshots for drift-audit.

---

## ✅ TL;DR

- **Architecture →** `docs/ARCHITECTURE_OVERVIEW.md`  
- **When things run →** `docs/SERVICE_GRAPH.md`  
- **Actual logic →** `scripts/` + `systemd/`  
- **Ground truth →** `configs_sanitised/`  
- **Before/After snapshots →** `docs/SYSTEM_STATE_*.md`

This repository = a **fully automated, deterministic, auditable NAS control-plane**.

All behaviour is explicit, traceable, and observable.

---

# ==============================================================================
# 🔒 Licensing & Attribution
# ==============================================================================

This project is released under the **Apache License 2.0**.

What that means in practice:

- The code is **free to use**, adapt, remix, or integrate  
- Commercial use is explicitly permitted  
- Please **retain attribution** to the original author in redistributed versions  
- A copy of the license must accompany any forks or derivatives  
- Code is provided **as-is**, without warranty or guarantees

If this project helps you, teaches you, or inspires you, leaving a ⭐ on GitHub or referencing the repo is always appreciated.


# ==============================================================================
# 🛑 END
# ==============================================================================
