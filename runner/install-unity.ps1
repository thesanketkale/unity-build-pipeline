<#
.SYNOPSIS
    Installs Unity Hub and specific Unity Editor versions with required build modules.
.DESCRIPTION
    Idempotently verifies and installs Unity Hub and parses ProjectSettings/ProjectVersion.txt
    to install the exact Editor changeset and build modules (Android, Windows IL2CPP, WebGL).
.PARAMETER ProjectVersionFile
    Path to ProjectSettings/ProjectVersion.txt. Defaults to "./ProjectSettings/ProjectVersion.txt".
.PARAMETER UnityVersion
    Explicit Unity Editor version override (e.g. 2022.3.48f1).
.PARAMETER Changeset
    Explicit Unity Editor changeset override (e.g. 79c884501a30).
.PARAMETER HubInstallPath
    Path to the Unity Hub executable. Defaults to standard 64-bit Program Files.
.PARAMETER Modules
    List of build target modules to install. Defaults to Android, Windows IL2CPP, and WebGL.
.EXAMPLE
    .\install-unity.ps1 -ProjectVersionFile "samples/minimal-project/ProjectSettings/ProjectVersion.txt"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectVersionFile = "./ProjectSettings/ProjectVersion.txt",

    [Parameter(Mandatory = $false)]
    [string]$UnityVersion,

    [Parameter(Mandatory = $false)]
    [string]$Changeset,

    [Parameter(Mandatory = $false)]
    [string]$HubInstallPath = "C:\Program Files\Unity Hub\Unity Hub.exe",

    [Parameter(Mandatory = $false)]
    [string[]]$Modules = @("android", "windows-il2cpp", "webgl")
)

$ErrorActionPreference = "Stop"

Write-Host "=== Unity Hub & Editor Provisioning ===" -ForegroundColor Cyan

# 1. Verify or Install Unity Hub
if (-not (Test-Path $HubInstallPath)) {
    Write-Host "Unity Hub not found at '$HubInstallPath'. Installing Unity Hub..." -ForegroundColor Yellow
    $HubInstallerUrl = "https://public-cdn.cloud.unity3d.com/hub/prod/UnityHubSetup.exe"
    $TempInstaller = Join-Path $env:TEMP "UnityHubSetup.exe"

    Invoke-WebRequest -Uri $HubInstallerUrl -OutFile $TempInstaller -UseBasicParsing
    Write-Host "Executing silent Unity Hub installation..." -ForegroundColor Cyan
    Start-Process -FilePath $TempInstaller -ArgumentList "/S" -Wait
    Remove-Item -Path $TempInstaller -Force -ErrorAction SilentlyContinue

    if (-not (Test-Path $HubInstallPath)) {
        throw "Unity Hub installation completed, but executable was not found at '$HubInstallPath'."
    }
    Write-Host "Unity Hub installed successfully." -ForegroundColor Green
} else {
    Write-Host "Found Unity Hub at '$HubInstallPath'." -ForegroundColor Green
}

# 2. Resolve Target Unity Version and Changeset
$TargetVersion = $UnityVersion
$TargetChangeset = $Changeset

if ([string]::IsNullOrWhiteSpace($TargetVersion) -and (Test-Path $ProjectVersionFile)) {
    Write-Host "Reading target editor version from '$ProjectVersionFile'..." -ForegroundColor Cyan
    $versionContent = Get-Content -Path $ProjectVersionFile -Raw

    if ($versionContent -match "m_EditorVersionWithRevision:\s*([^\s]+)\s*\(([a-f0-9]+)\)") {
        $TargetVersion = $Matches[1]
        $TargetChangeset = $Matches[2]
    }
    elseif ($versionContent -match "m_EditorVersion:\s*([^\s]+)") {
        $TargetVersion = $Matches[1]
    }
}

if ([string]::IsNullOrWhiteSpace($TargetVersion)) {
    throw "Target Unity version could not be resolved from parameters or ProjectVersionFile ('$ProjectVersionFile')."
}

Write-Host "Target Unity Editor: $TargetVersion (Changeset: $(if ($TargetChangeset) { $TargetChangeset } else { 'auto' }))" -ForegroundColor Cyan

# 3. Check Installed Editors via Hub CLI
$installedEditorsOutput = & "$HubInstallPath" -- --headless editors --installed 2>&1
$isAlreadyInstalled = $false
foreach ($line in $installedEditorsOutput) {
    if ($line -match [regex]::Escape($TargetVersion)) {
        $isAlreadyInstalled = $true
        break
    }
}

# 4. Install Editor if missing
if (-not $isAlreadyInstalled) {
    Write-Host "Editor $TargetVersion is not installed. Installing via Unity Hub..." -ForegroundColor Yellow
    $installArgs = @("--", "--headless", "install", "--version", $TargetVersion)
    if (-not [string]::IsNullOrWhiteSpace($TargetChangeset)) {
        $installArgs += @("--changeset", $TargetChangeset)
    }

    Write-Host "Running: Unity Hub $($installArgs -join ' ')" -ForegroundColor Cyan
    $installProcess = Start-Process -FilePath $HubInstallPath -ArgumentList $installArgs -NoNewWindow -Wait -PassThru
    if ($installProcess.ExitCode -ne 0) {
        throw "Unity Editor installation failed with exit code $($installProcess.ExitCode)."
    }
    Write-Host "Unity Editor $TargetVersion installed successfully." -ForegroundColor Green
} else {
    Write-Host "Unity Editor $TargetVersion is already installed." -ForegroundColor Green
}

# 5. Install Required Target Modules
foreach ($module in $Modules) {
    Write-Host "Ensuring module '$module' is installed for editor $TargetVersion..." -ForegroundColor Cyan
    $moduleArgs = @("--", "--headless", "install-modules", "--version", $TargetVersion, "-m", $module)
    $moduleProcess = Start-Process -FilePath $HubInstallPath -ArgumentList $moduleArgs -NoNewWindow -Wait -PassThru
    if ($moduleProcess.ExitCode -ne 0) {
        Write-Warning "Module '$module' installation returned exit code $($moduleProcess.ExitCode) (may already be present or skipped)."
    } else {
        Write-Host "Module '$module' confirmed installed." -ForegroundColor Green
    }
}

Write-Host "Unity provisioning completed successfully for $TargetVersion." -ForegroundColor Green
