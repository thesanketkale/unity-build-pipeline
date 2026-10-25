# Security Architecture & Threat Model: Self-Hosted Runners

Self-hosted GitHub Actions runners provide immense computational performance and zero-cost build minutes for Unity projects, but they introduce a significantly larger security attack surface than cloud-hosted ephemeral runners.

This document outlines the threat model, security boundaries, and mandatory repository configuration policies for `unity-build-pipeline`.

---

## 1. The Core Threat: Untrusted Pull Request Execution

### The Risk
In a public GitHub repository, anyone can submit a pull request containing modified workflow files, C# scripts, or malicious pre-build PowerShell hooks. If a self-hosted runner executes workflows automatically on fork pull requests, arbitrary code executes directly on the physical host operating system with access to the local network, runner credentials, and cached assets.

### The Mitigation: Strict Trigger Restrictions
Workflows in this repository are designed with strict trigger boundaries:
1. Reusable build and test workflows (`unity-test.yml`, `unity-build.yml`, `unity-release.yml`) are intended to trigger **only on `push` to protected branches (e.g. `main`), tags, or authorized `workflow_dispatch`**.
2. **NEVER** bind a self-hosted runner to `on: pull_request` without requiring maintainer approval.

### Mandatory GitHub Repository Settings
In your GitHub repository settings:
- Go to **Settings** -> **Actions** -> **General**.
- Under **Fork pull request workflows from outside collaborators**:
  - Select: **Require approval for all outside collaborators** or **Require approval for first-time contributors**.
- Under **Workflow permissions**:
  - Select: **Read repository contents and packages permissions** (least privilege).

---

## 2. Host Isolation & Least Privilege

1. **Dedicated Service Account:**
   - The runner service must run under a dedicated, unprivileged Windows account (`NT AUTHORITY\NetworkService` or a local user `.\UnityRunner`).
   - The service account must NOT be a member of the local `Administrators` group.
2. **Filesystem Boundaries:**
   - The runner work directory (`C:\actions-runner\_work`) should reside on a dedicated partition or volume with explicit ACLs granting write access only to the runner service account.
3. **Network Isolation:**
   - Isolate the build machine on a segmented VLAN with outbound internet access restricted to GitHub, Unity services, and authorized artifact endpoints.
   - Deny inbound connections to the build machine.

---

## 3. Cryptographic Action Pinning

All GitHub Actions invocations in this repository are strictly pinned to immutable 40-character commit SHAs with trailing version comments:

```yaml
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
uses: actions/upload-artifact@4cec3d8aa04e39d1a68397de0c4cd6fb9dce8ec1 # v4.6.1
```

This prevents upstream supply-chain tampering where a modified mutable tag (e.g. `@v4`) could execute malicious code on your build server.

---

## 4. Secret Masking & Ephemeral Keystores

- Sensitive values (Unity passwords, Android keystores) are passed strictly through GitHub Actions environment variables and mapped via `PlayerSettings`.
- Passwords are never passed as command-line arguments (which are logged in process tables).
- Decoded temporary Android keystores are stored in ephemeral temp paths and erased in `if: always()` post-steps.
