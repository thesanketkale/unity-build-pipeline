<#
.SYNOPSIS
    Installs, configures, and registers a self-hosted GitHub Actions Windows runner service.
.DESCRIPTION
    Downloads the official GitHub Actions runner package, validates its SHA-256 hash,
    configures runner labels, and registers it as an automatic Windows Service under a
    dedicated local service account.
.PARAMETER RepoUrl
    The full URL of the GitHub repository (e.g. https://github.com/thesanketkale/unity-build-pipeline).
.PARAMETER OrgUrl
    The full URL of the GitHub organization if registering at the organization level.
.PARAMETER Token
    The short-lived GitHub runner registration token. NEVER stored or logged to disk.
.PARAMETER Labels
    Comma-separated or array of runner labels. Defaults to "unity,windows,x64".
.PARAMETER WorkFolder
    The root path for runner job workspaces. Defaults to "C:\actions-runner\_work".
.PARAMETER InstallPath
    The directory where runner binaries will be installed. Defaults to "C:\actions-runner".
.PARAMETER RunnerVersion
    The GitHub Actions runner version to install. Defaults to "2.321.0".
.PARAMETER ServiceAccount
    The local Windows user account to run the service under. Defaults to "NT AUTHORITY\NetworkService".
.PARAMETER Ephemeral
    Switch to configure the runner as ephemeral (single-job execution then deregistration).
.EXAMPLE
    .\install-runner.ps1 -RepoUrl "https://github.com/myorg/myrepo" -Token "AAABBBCCCDDD" -Labels "unity,windows,x64"
#>
[CmdletBinding(DefaultParameterSetName = "Repo")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Repo")]
    [ValidateNotNullOrEmpty()]
    [string]$RepoUrl,

    [Parameter(Mandatory = $true, ParameterSetName = "Org")]
    [ValidateNotNullOrEmpty()]
    [string]$OrgUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Token,

    [Parameter(Mandatory = $false)]
    [string[]]$Labels = @("unity", "windows", "x64"),

    [Parameter(Mandatory = $false)]
    [string]$WorkFolder = "C:\actions-runner\_work",

    [Parameter(Mandatory = $false)]
    [string]$InstallPath = "C:\actions-runner",

    [Parameter(Mandatory = $false)]
    [string]$RunnerVersion = "2.321.0",

    [Parameter(Mandatory = $false)]
    [string]$ServiceAccount = "NT AUTHORITY\NetworkService",

    [Parameter(Mandatory = $false)]
    [switch]$Ephemeral
)

$ErrorActionPreference = "Stop"

# Pinned SHA-256 hashes for official GitHub Actions Runner releases
$KnownHashes = @{
    "2.321.0" = "560bc933eb92ff9e0f3164a2752119eb4a0558b8d4e9c7198bb68c2f1f5d6f83"
    "2.320.0" = "0359b3cb55ad6fb4be232930ea28876e5c9b68ad93b4845b4c5fb3ea7e20b571"
}

$TargetUrl = if ($PSCmdlet.ParameterSetName -eq "Repo") { $RepoUrl } else { $OrgUrl }
$LabelString = ($Labels -join ",")

Write-Host "=== GitHub Actions Runner Provisioning ===" -ForegroundColor Cyan
Write-Host "Target URL:      $TargetUrl"
Write-Host "Install Path:    $InstallPath"
Write-Host "Work Folder:     $WorkFolder"
Write-Host "Runner Labels:   $LabelString"
Write-Host "Runner Version:  $RunnerVersion"
Write-Host "Service Account: $ServiceAccount"

# Ensure directories exist
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}
if (-not (Test-Path $WorkFolder)) {
    New-Item -ItemType Directory -Path $WorkFolder -Force | Out-Null
}

$ArchiveName = "actions-runner-win-x64-$RunnerVersion.zip"
$DownloadUrl = "https://github.com/actions/runner/releases/download/v$RunnerVersion/$ArchiveName"
$ZipPath = Join-Path $InstallPath $ArchiveName

# Download runner package if not already cached
if (-not (Test-Path $ZipPath)) {
    Write-Host "Downloading runner package from $DownloadUrl..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing
}

# Checksum verification
if ($KnownHashes.ContainsKey($RunnerVersion)) {
    $ExpectedHash = $KnownHashes[$RunnerVersion]
    $ActualHash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($ActualHash -ne $ExpectedHash) {
        Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
        throw "SHA-256 verification failed for $ArchiveName! Expected: $ExpectedHash, Got: $ActualHash"
    }
    Write-Host "SHA-256 checksum verified successfully: $ActualHash" -ForegroundColor Green
} else {
    Write-Warning "No pre-computed SHA-256 hash found for version $RunnerVersion. Verification skipped."
}

# Unpack runner package
$ConfigScript = Join-Path $InstallPath "config.cmd"
if (-not (Test-Path $ConfigScript)) {
    Write-Host "Extracting runner files to $InstallPath..." -ForegroundColor Cyan
    Expand-Archive -Path $ZipPath -DestinationPath $InstallPath -Force
}

# Prepare configuration arguments
$ConfigArgs = @(
    "--url", $TargetUrl,
    "--token", $Token,
    "--name", "$($env:COMPUTERNAME)-unity",
    "--work", $WorkFolder,
    "--labels", $LabelString,
    "--unattended",
    "--replace"
)

if ($Ephemeral) {
    $ConfigArgs += "--ephemeral"
}

Write-Host "Configuring GitHub Actions Runner..." -ForegroundColor Cyan
Push-Location $InstallPath
try {
    # Execute configuration
    & ".\config.cmd" @ConfigArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Runner configuration failed with exit code $LASTEXITCODE"
    }

    # Install as Windows Service if not ephemeral
    if (-not $Ephemeral) {
        Write-Host "Installing runner as Windows Service under $ServiceAccount..." -ForegroundColor Cyan
        & ".\config.cmd" "install" "--windows-service" "--windows-logon-account" $ServiceAccount
        Write-Host "Starting runner service..." -ForegroundColor Cyan
        & ".\config.cmd" "start"
    }

    Write-Host "Runner installed and registered successfully!" -ForegroundColor Green
}
finally {
    Pop-Location
}
