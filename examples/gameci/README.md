# Alternative Architecture: GameCI on Hosted Linux Runners

While `unity-build-pipeline` specializes in self-hosted Windows build servers for maximum build speed and native Windows IL2CPP support, many teams prefer or require purely cloud-hosted pipelines without physical hardware to maintain.

This directory illustrates the alternative containerized approach using [GameCI](https://game.ci/) on GitHub-hosted Linux runners.

---

## Architectural & Tradeoff Comparison

| Dimension | Self-Hosted Windows (`unity-build-pipeline`) | GameCI on Hosted Linux Runners |
|---|---|---|
| **Build Host** | Dedicated Windows 10/11 or Server | GitHub-hosted `ubuntu-latest` / Larger Runners |
| **Incremental Build Time** | **2–4 minutes** (persistent local `Library/`) | **15–30 minutes** (cache download & extraction) |
| **Clean Build Time** | 30–45 minutes | 45–60 minutes |
| **Cost** | Fixed: Hardware + Power + Internet (Zero GitHub runner minutes) | Variable: Cloud runner minutes (~$0.008–$0.064/min) |
| **Windows Standalone IL2CPP** | **Full Native Support** | **Not Supported** (Linux containers cannot build Windows IL2CPP) |
| **Android (APK / AAB)** | Supported (requires Android build support module) | Supported out of the box via Docker image |
| **WebGL** | Supported | Supported |
| **Hardware Maintenance** | Required (Windows Updates, disk pruning, service monitoring) | **Zero** (GitHub manages virtual machines) |
| **Security Surface** | High if exposed to fork PRs; requires dedicated service account | Low (ephemeral sandboxed Linux container per run) |
| **Licensing Activation** | Activated once on machine via Hub CLI or Editor CLI | Per-job activation & return via GitHub Secrets |

---

## GameCI License Activation Notes

When using GameCI on ephemeral Linux runners, each runner job must activate a Unity license at the start of the job and return it at the end to avoid exhausting license seat activations:

1. **Personal License:**
   - Requires generating a `.alf` license activation file manually, uploading it to `license.unity.com`, and storing the returned `.ulf` file as a secret (`UNITY_LICENSE`).
2. **Professional / Enterprise License:**
   - Requires setting `UNITY_EMAIL`, `UNITY_PASSWORD`, and `UNITY_SERIAL` as GitHub repository secrets.
   - The job acquires a seat, performs tests/builds, and releases the license in an `if: always()` step using GameCI's license return action.

---

## Example GameCI Workflow

See [`gameci-workflow.yml`](file:///d:/Repositories/git/thesanketkale/unity-build-pipeline/examples/gameci/gameci-workflow.yml) for a reference implementation testing and building an Android APK on GitHub-hosted Ubuntu runners.
