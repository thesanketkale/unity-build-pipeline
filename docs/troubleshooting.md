# Troubleshooting & Diagnostic Runbook

This runbook provides diagnostic solutions for the most common issues encountered when running Unity builds on self-hosted Windows runners.

---

## 1. Unity License Failures

### Symptoms
- Build step fails with exit code `1` or `99`.
- Editor log shows:
  ```text
  [Licensing::Client] Handshake with client failed
  No valid Unity license found
  Failed to activate serial
  ```

### Solutions
1. **Verify Machine Activation:**
   Run `license.ps1` to check current status:
   ```powershell
   pwsh -File .\runner\license.ps1 -Action Status
   ```
2. **Re-activate License:**
   If the seat was deactivated or machine hardware changed:
   ```powershell
   pwsh -File .\runner\license.ps1 -Action Activate -Serial "SC-XXXX-..." -Username "ci@company.com" -Password "secret"
   ```
3. **Check Seat Limits:**
   Log into `id.unity.com` -> **My Account** -> **My Seats** to ensure your seat pool has not reached its activation limit.

---

## 2. `-nographics` and Shader Compilation Errors

### Symptoms
- Tests or builds fail with:
  ```text
  Display: No graphic device found
  Shader compiler failed to compile shader variant
  ```

### Solutions
- Unity Editor in batchmode with `-nographics` compiles shaders using a fallback CPU-based shader compiler.
- Ensure the runner machine has the required **DirectX End-User Runtimes** and updated GPU drivers installed, even if headless.
- If using dummy rendering in tests, ensure camera components use `CameraClearFlags.SolidColor` rather than `Skybox`.

---

## 3. Project Directory Locked / Library Lockfile

### Symptoms
- Unity fails immediately with exit code `1` or logs:
  ```text
  Another instance of Unity is running on this project
  Could not open project at path ... (Lockfile exists)
  ```

### Solutions
1. **Ensure Single-Job Concurrency:**
   Verify workflow concurrency settings are enabled (`cancel-in-progress: false`).
2. **Clear Stale Lockfile:**
   If a previous Unity process crashed abnormally or was killed by a runner timeout, the lockfile may remain on disk. Delete it:
   ```powershell
   Remove-Item -Path "Temp\UnityLockfile" -Force -ErrorAction SilentlyContinue
   ```
3. **Kill Orphaned Unity Processes:**
   ```powershell
   Get-Process -Name "Unity" -ErrorAction SilentlyContinue | Stop-Process -Force
   ```

---

## 4. IL2CPP Memory Exhaustion (Exit Code 137)

### Symptoms
- Android or Windows IL2CPP build fails during native C++ compilation.
- Runner log indicates `Exit code 137` or `il2cpp.exe exited with non-zero exit code`.

### Solutions
- IL2CPP compilation is multi-threaded and consumes massive RAM (often 2–4 GB per worker thread).
- On machines with 16 GB RAM or less, restrict IL2CPP parallel threads in `ProjectSettings`:
  Set `PlayerSettings.SetAdditionalIl2CppArgs("--threads=4")`.
- Increase system pagefile size to at least 32 GB on the build host SSD.

---

## 5. Decommissioning a Runner / Returning License

When retiring or rebuilding a physical build server, ALWAYS return the active license seat first:
```powershell
pwsh -File .\runner\license.ps1 -Action Return
```
This frees the seat in your Unity account so it can be re-assigned immediately to another machine.
