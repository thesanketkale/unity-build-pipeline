# ADR-0001: Self-Hosted Windows Runner Architecture and Pipeline Stack Choices

- **Status:** Accepted
- **Date:** 2026-10-24
- **Deciders:** Sanket Kale
- **Technical Context:** Unity CI/CD, GitHub Actions, Windows Self-Hosted Runners, IL2CPP Build Automation

---

## Context and Problem Statement

Automating Unity tests and multi-platform builds (Windows Standalone, Android IL2CPP, and WebGL) in continuous integration presents distinct challenges that standard software CI/CD tooling does not solve well:

1. **Massive Cache Re-import Overhead:** Unity's `Library/` directory caches processed assets, shader variants, and imported textures. When building from a clean state without `Library/`, importing an average-sized project takes 30 to 90 minutes. Downloading and unpacking multi-gigabyte tarballs via cloud cache actions (`actions/cache`) over network boundaries frequently negates any time savings.
2. **Platform & Toolchain Limitations on Hosted Linux:** Hosted Linux runners running containerized Unity environments (such as GameCI) are effective for Android APK/AAB and Linux targets, but cannot natively compile Windows Standalone IL2CPP binaries or run Windows-specific DirectX graphics tests.
3. **Hardware Utilization & Cost:** Cloud compute minutes for larger hosted runners with high CPU core counts and GPUs are expensive. Many studios and independent developers maintain spare or dedicated Windows workstations capable of delivering 4x to 8x faster build throughput if harnessed properly.
4. **Security Risks of Self-Hosted Runners:** Self-hosted runners executing workflows from public repositories or untrusted forks pose serious host compromise risks if not strictly configured with dedicated user accounts, isolated storage, and protected triggers.

---

## Decision Drivers

- **Build Speed:** Incremental test and build cycles must complete in under 5 minutes for typical commit workflows.
- **Cross-Platform Target Support:** Must build Windows Standalone (Mono/IL2CPP), Android (APK and AAB with keystore signing), and WebGL.
- **Operational Simplicity:** Setup on a clean Windows machine must take approximately 10 minutes with idempotent provisioning scripts.
- **Host Security:** Runner processes must run under least-privilege service accounts and never execute untrusted pull request code.
- **Reproducibility & Auditability:** All third-party GitHub Actions must be pinned to immutable commit SHAs with zero hallucinated SHAs.

---

## Considered Alternatives

1. **Cloud-Hosted Linux Runners with GameCI Docker Containers:**
   - *Pros:* Fully managed infrastructure, ephemeral clean environments, no hardware management.
   - *Cons:* Cannot build Windows Standalone IL2CPP; cache upload/download overhead is bottlenecked by network bandwidth; high recurring runner costs.
2. **Unity Cloud Build (UCB):**
   - *Pros:* Turnkey SaaS built into Unity dashboard.
   - *Cons:* Opaque queue times, limited customization for proprietary signing/release workflows, vendor lock-in, recurring subscription pricing.
3. **Interactive Local Runner on Developer Workstations:**
   - *Pros:* Zero setup cost.
   - *Cons:* Interrupted by developer logins/reboots; runs with user's full desktop permissions; locks projects open in the Unity Editor.
4. **Self-Hosted Windows Service Runner with Dedicated User and Persistent Library Cache (Chosen):**
   - *Pros:* Blazing fast local NVMe builds; native Windows and Android IL2CPP toolchains; automated maintenance and security boundaries.
   - *Cons:* Requires physical host hardware and licensing compliance management.

---

## Decision Outcome

We decided to implement a **self-hosted Windows service runner architecture** driven by **PowerShell 7 (`pwsh`)** and reusable GitHub Actions workflows:

### 1. Automation Scripting with PowerShell 7 (`pwsh`)
- All runner provisioning, maintenance, and build helper scripts are authored in PowerShell 7 (`pwsh`) with strict parameter typing, PSScriptAnalyzer compliance, and robust error handling.
- Avoids legacy `cmd.exe` limitations and Windows PowerShell 5.1 quirks.

### 2. Dedicated Least-Privilege Windows Service Account
- `runner/install-runner.ps1` configures the GitHub Actions runner as an automatic Windows Service running under a dedicated local user account (`.\UnityRunner` or user-defined `-ServiceAccount`).
- The service account is granted `Logon as a Service` rights and access only to the runner directory and work drive, mitigating lateral movement risks.

### 3. Persistent Workspace with Deterministic Hash Guard
- To eliminate 45+ minute asset re-imports, the pipeline runs with persistent workspaces (`clean: false`) keeping the `Library/` directory intact between runs.
- To prevent silent cache corruption across Unity version or package updates, `scripts/Guard-LibraryCache.ps1` calculates a composite SHA-256 fingerprint of `ProjectSettings/ProjectVersion.txt`, `Packages/manifest.json`, and `Packages/packages-lock.json`. When the fingerprint changes, `Library/` is pruned deterministically.

### 4. Single-Job Concurrency Locking
- Unity's Editor process acquires an exclusive file lock on the project directory. Attempting concurrent builds of the same project corrupts the database.
- Workflows enforce strict concurrency per project and runner:
  ```yaml
  concurrency:
    group: unity-${{ github.repository }}-${{ runner.name }}
    cancel-in-progress: false
  ```

### 5. Ephemeral Secret Lifecycle for Android Signing
- Android keystores are stored as base64 secrets (`ANDROID_KEYSTORE_BASE64`) in GitHub Environments.
- At build time, the workflow decodes the keystore to a secure temporary path, passes passwords strictly via environment variables, and removes the file in a guaranteed `if: always()` cleanup step.

---

## Consequences

### Positive
- Build and test iterations drop from ~45 minutes to 2–4 minutes.
- Full support for Windows IL2CPP, Android AAB with Play Store signing, and WebGL.
- Complete transparency: all build steps, exit codes, and NUnit test summaries are visible in GitHub Actions.

### Negative / Trade-offs
- The build host requires physical or VM Windows management (Windows Updates, disk space monitoring).
- Untrusted fork PRs cannot run on self-hosted runners; repository permissions must enforce mandatory review for external contributors.
- Editor licensing must be activated on the physical host using Unity's official command line licensing tools.
