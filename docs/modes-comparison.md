# Architecture Comparison: Self-Hosted vs GameCI vs Unity Cloud Build

Choosing the right continuous integration strategy for a Unity game or XR project depends on team size, target platforms, budget, and operational capacity.

This document provides an objective, transparent comparison of the three primary approaches:

---

## High-Level Comparison Matrix

| Evaluation Criteria | Self-Hosted Windows (`unity-build-pipeline`) | GameCI (Hosted Linux Containers) | Unity Cloud Build (UCB) |
|---|---|---|---|
| **Typical Incremental Build** | **2–4 minutes** (persistent local NVMe cache) | **15–30 minutes** (cache download/unzip) | 15–30 minutes |
| **Typical Clean Build** | 35–45 minutes | 45–60 minutes | 40–60 minutes |
| **Infrastructure Cost** | **Zero per-minute CI cost**; fixed host hardware | Recurring per-minute GitHub Actions costs | Monthly Unity DevOps subscription tier |
| **Windows Standalone IL2CPP** | **Full Native Support** | **Not Supported** (Linux containers cannot build Windows IL2CPP) | Supported via Windows build farm |
| **Android (APK / AAB)** | Supported (with Android build support module) | Supported out-of-the-box via Docker image | Supported |
| **WebGL** | Supported | Supported | Supported |
| **Host Maintenance Required** | Yes (OS updates, disk pruning, service health) | **Zero** (GitHub manages runners) | **Zero** (Unity manages runners) |
| **Custom Signing & Packaging** | Full control over PowerShell & batch scripts | Controlled via YAML & Docker entrypoints | Limited to UCB web dashboard options |
| **Security Surface** | Higher (requires dedicated service account & PR gating) | Sandboxed ephemeral Linux container | Managed SaaS environment |

---

## 1. When to Choose Self-Hosted Windows (`unity-build-pipeline`)

Choose this architecture when:
- **Build speed is paramount:** Your team makes 20+ commits a day and cannot wait 30 minutes per commit.
- **You target Windows Standalone (IL2CPP) or PC VR (OpenXR):** Only a Windows machine can build native Windows IL2CPP binaries.
- **You have existing hardware:** A spare desktop with a modern multi-core CPU and fast NVMe can be repurposed in 10 minutes.
- **You want zero recurring cloud runner minute charges.**

---

## 2. When to Choose GameCI on Hosted Linux

Choose GameCI when:
- **Your team has zero physical hardware:** You want 100% cloud-hosted infrastructure without managing physical machines.
- **You target Android, WebGL, or Linux only:** Linux Docker containers excel at Android and WebGL compilation.
- **You build infrequently:** If builds run 1–2 times a day, paying a few dollars a month for hosted runner minutes is cheaper than maintaining hardware.

See [`examples/gameci/`](file:///d:/Repositories/git/thesanketkale/unity-build-pipeline/examples/gameci/) for reference GameCI workflow examples.

---

## 3. When to Choose Unity Cloud Build (UCB)

Choose Unity Cloud Build when:
- Your organization prefers turnkey SaaS integrated directly into the Unity Editor dashboard.
- You do not require custom pre-build infrastructure scripts, custom hardware peripherals, or multi-cloud deployment pipelines.
