# Security Policy: unity-build-pipeline

We take the security of `unity-build-pipeline` and the build environments it automates seriously.

---

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1.0 | :x:                |

---

## Reporting a Vulnerability

If you discover a security vulnerability or security misconfiguration in this repository, please **DO NOT** open a public GitHub issue.

Instead, please report security vulnerabilities using **GitHub Private Vulnerability Reporting**:
1. Navigate to the [Security](https://github.com/thesanketkale/unity-build-pipeline/security) tab of this repository.
2. Click **Report a vulnerability** to open a private advisory draft.
3. Include detailed steps to reproduce, impact assessment, and any proposed remediations.

You will receive an initial response within 48 hours acknowledging receipt of your report.

---

## Self-Hosted Runner Security Guidelines

Running self-hosted GitHub Actions runners introduces unique security considerations compared to cloud-hosted ephemeral virtual machines:

1. **Untrusted Pull Requests:**
   - **NEVER** expose self-hosted runners to untrusted fork pull requests in public repositories. Workflows in this repository trigger only on `push` to protected branches, version tags, and manual `workflow_dispatch`.
   - Ensure repository settings require approval for outside collaborators before workflows run.
2. **Dedicated Least-Privilege User Account:**
   - Always run the GitHub Actions runner service under a dedicated local service account (`.\UnityRunner`), not `LocalSystem` or Administrator.
3. **Android Keystore Security:**
   - Ingest signing keys as base64 secrets in protected GitHub Environments.
   - The pipeline decodes keystores into temporary ephemeral files and securely purges them in `if: always()` post-steps.
4. **Action Pinning:**
   - All third-party actions are pinned to immutable 40-character commit SHAs to prevent supply chain tampering.
