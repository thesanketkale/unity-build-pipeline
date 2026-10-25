# Ten-Minute Windows Runner Provisioning Guide

This guide walks through setting up a clean Windows 10, Windows 11, or Windows Server host as a high-performance Unity build machine in approximately ten minutes.

---

## Prerequisites

1. **Operating System:** Windows 10/11 64-bit or Windows Server 2022.
2. **PowerShell 7 (`pwsh`):** Install via winget:
   ```powershell
   winget install --id Microsoft.PowerShell --source winget
   ```
3. **Git for Windows:**
   ```powershell
   winget install --id Git.Git --source winget
   ```
4. **Storage:** An SSD or NVMe drive with at least 100 GB of free space. We recommend setting the work directory to `C:\actions-runner\_work` or on a secondary high-speed drive (e.g. `D:\_work`).
5. **GitHub Runner Registration Token:**
   - In your repository or organization on GitHub: **Settings** -> **Actions** -> **Runners** -> **New runner**.
   - Copy the generated registration token (e.g. `A7B...`).

---

## Step 1: Provision the GitHub Actions Runner Service

Run `runner/install-runner.ps1` from an elevated PowerShell 7 prompt:

```powershell
pwsh -ExecutionPolicy Bypass -File .\runner\install-runner.ps1 `
    -RepoUrl "https://github.com/your-org/your-unity-project" `
    -Token "YOUR_GITHUB_RUNNER_TOKEN" `
    -Labels "self-hosted", "windows", "unity" `
    -InstallPath "C:\actions-runner" `
    -WorkFolder "C:\actions-runner\_work"
```

### What this script does:
- Downloads the official Actions Runner binary (`2.321.0`).
- Verifies its cryptographic SHA-256 checksum.
- Configures labels (`self-hosted,windows,unity`).
- Installs and starts the runner as an automatic Windows Service under `NT AUTHORITY\NetworkService` (or custom `-ServiceAccount`).

---

## Step 2: Install Unity Hub and Editor Modules

Run `runner/install-unity.ps1` pointing to your target project's `ProjectVersion.txt`:

```powershell
pwsh -ExecutionPolicy Bypass -File .\runner\install-unity.ps1 `
    -ProjectVersionFile "samples/minimal-project/ProjectSettings/ProjectVersion.txt" `
    -Modules "android", "windows-il2cpp", "webgl"
```

### What this script does:
- Installs Unity Hub silently if not present.
- Extracts the exact Editor version and changeset revision (e.g. `2022.3.48f1` / `79c884501a30`).
- Idempotently installs the Editor and the required Android (SDK/NDK/OpenJDK), Windows IL2CPP, and WebGL modules.

---

## Step 3: Activate Unity License

See [Licensing Guide](licensing.md) for details on license types. To activate a Professional/Enterprise license:

```powershell
pwsh -ExecutionPolicy Bypass -File .\runner\license.ps1 `
    -Action Activate `
    -Username "builder@example.com" `
    -Password "your-secure-password" `
    -Serial "SC-XXXX-XXXX-XXXX-XXXX-XXXX"
```

To verify active license status:
```powershell
pwsh -ExecutionPolicy Bypass -File .\runner\license.ps1 -Action Status
```

---

## Step 4: Configure Maintenance Task Scheduler

Set up `runner/maintenance.ps1` as a nightly Windows Scheduled Task to prune stale workspaces and log files:

```powershell
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-ExecutionPolicy Bypass -File C:\actions-runner\runner\maintenance.ps1 -FreeDiskThresholdGB 40"
$trigger = New-ScheduledTaskTrigger -Daily -At 3:00AM
Register-ScheduledTask -TaskName "UnityRunnerMaintenance" -Action $action -Trigger $trigger -Description "Nightly Unity CI cache pruning"
```

Your self-hosted Unity build server is now fully operational!
