# Verification Log & Owner Handoff Runbook

*Repository:* `unity-build-pipeline`  
*Target Release:* `v0.1.0`  
*Maintainer:* @thesanketkale  
*Status:* CI-Verified (Automated) / Owner-Verification Pending (Self-Hosted Runner)

---

## 1. Automated CI Verification (Completed by Builder Agent)

The following verification gates run automatically on every commit and pull request without requiring physical build server hardware or Unity Editor licenses:

| Gate | Verification Command | Status | Proof / Location |
|---|---|:---:|---|
| **Clean-Room & Secret Guard** | `pwsh -File scripts/verify.ps1 fast` | :white_check_mark: PASS | Confirms 0 forbidden client strings or keys. |
| **Unity `.meta` File Integrity** | `pwsh -File scripts/verify.ps1 fast` | :white_check_mark: PASS | All assets in `samples/minimal-project` validated. |
| **PowerShell Code Quality** | `Invoke-ScriptAnalyzer -Settings PSScriptAnalyzerSettings.psd1` | :white_check_mark: PASS | 0 errors or warnings across `runner/`, `scripts/`, `tests/`. |
| **Workflow Syntax & Pinning** | `actionlint` | :white_check_mark: PASS | All workflows valid, 100% actions pinned to 40-char SHAs. |
| **Pester Unit Test Suite** | `Invoke-Pester -Path tests/Pester` | :white_check_mark: PASS | **19 of 19 tests passed** across all module suites. |

---

## 2. Owner-Verified Acceptance Criteria (10-Minute Verification)

The following end-to-end tests require access to the owner's physical Windows runner host and a valid Unity Editor license seat. Follow the exact copy-paste steps below:

### Test 1: Self-Hosted Windows Runner Service Provisioning (AC-7)
**Goal:** Verify `install-runner.ps1` configures and starts the GitHub Actions runner Windows Service.
1. Obtain a short-lived runner registration token from your GitHub repo (**Settings** -> **Actions** -> **Runners** -> **New runner**).
2. Open an elevated PowerShell 7 prompt and execute:
   ```powershell
   pwsh -ExecutionPolicy Bypass -File .\runner\install-runner.ps1 `
       -RepoUrl "https://github.com/thesanketkale/unity-build-pipeline" `
       -Token "<YOUR_TOKEN>" `
       -Labels "self-hosted", "windows", "unity" `
       -InstallPath "C:\actions-runner" `
       -WorkFolder "C:\actions-runner\_work"
   ```
3. **Expected Output:**
   ```text
   SHA-256 checksum verified successfully: 560bc933eb92ff9e0f3164a2752119eb4a0558b8d4e9c7198bb68c2f1f5d6f83
   Runner installed and registered successfully!
   ```
4. Verify on GitHub: Runner appears under **Settings** -> **Actions** -> **Runners** with status `Idle` and labels `self-hosted, windows, unity`.

- [ ] Owner Verified: Runner registered and active as Windows Service.

---

### Test 2: Unity Editor & Module Installation (AC-7)
**Goal:** Verify `install-unity.ps1` idempotently installs Unity 2022.3.48f1 with Android, Windows IL2CPP, and WebGL modules.
1. Execute:
   ```powershell
   pwsh -ExecutionPolicy Bypass -File .\runner\install-unity.ps1 `
       -ProjectVersionFile "samples/minimal-project/ProjectSettings/ProjectVersion.txt" `
       -Modules "android", "windows-il2cpp", "webgl"
   ```
2. **Expected Output:**
   ```text
   Target Unity Editor: 2022.3.48f1 (Changeset: 79c884501a30)
   Unity Editor 2022.3.48f1 installed successfully.
   Module 'android' confirmed installed.
   Module 'windows-il2cpp' confirmed installed.
   Module 'webgl' confirmed installed.
   ```

- [ ] Owner Verified: Unity Hub and Editor modules installed.

---

### Test 3: Unity Batchmode Self-Test Workflow (AC-8)
**Goal:** Execute the full test and build pipeline on the physical runner against `samples/minimal-project`.
1. On GitHub, navigate to **Actions** -> **Unity Self-Test (Manual)**.
2. Click **Run workflow** (branch: `main`).
3. Monitor execution of:
   - `scripts/Get-UnityVersion.ps1` -> Resolves `2022.3.48f1`.
   - `scripts/Guard-LibraryCache.ps1` -> Validates/creates `Library/` cache fingerprint.
   - EditMode & PlayMode test execution in batchmode -> NUnit summary published in Job Summary.
   - Build execution for `StandaloneWindows64`, `Android`, and `WebGL`.
4. **Expected Output:**
   - GitHub Actions workflow runs to completion with a green checkmark.
   - Job Summary displays NUnit test table: 2 total tests, 2 passed, 0 failed.
   - Artifacts uploaded: `unity-test-results`, `unity-build-StandaloneWindows64-...`, `unity-build-Android-...`.

- [ ] Owner Verified: Full batchmode test and build execution passed on self-hosted runner.

---

### Test 4: Android Keystore Signing & Cleanup
**Goal:** Verify signed Android package creation and ephemeral keystore deletion.
1. Set `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASS`, `ANDROID_KEYALIAS_NAME`, and `ANDROID_KEYALIAS_PASS` in repository secrets.
2. Trigger build with target `Android` and format `AAB`.
3. Verify output `.aab` package is generated in `Builds/Android/` and signed.
4. Verify step log confirms:
   ```text
   Securely scrubbed temporary Android keystore file.
   ```
5. Confirm no `.keystore` files remain in `$env:TEMP`.

- [ ] Owner Verified: Signed AAB produced and temp keystore scrubbed.

---

## 3. Verification Sign-Off Table

| Verifier | Role | Date | Environment | Sign-Off |
|---|---|---|---|---|
| **Antigravity Agent Swarm** | Builder & Reviewer | 2026-10-25 | Windows 11 / pwsh 7.6 / GitHub Actions CI | :white_check_mark: VERIFIED (CI) |
| **@thesanketkale** | Repository Owner | *Pending* | Self-Hosted Windows Runner Hardware | *Pending* |
