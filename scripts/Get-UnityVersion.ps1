<#
.SYNOPSIS
    Parses Unity ProjectSettings/ProjectVersion.txt and resolves the local Unity Editor executable.
.DESCRIPTION
    Extracts the exact Unity version and changeset revision, then locates the corresponding
    Unity.exe installation on the host filesystem. Sets GitHub Actions step outputs if running in CI.
.PARAMETER ProjectPath
    Path to the Unity project root. Defaults to current directory.
.PARAMETER ProjectVersionFile
    Optional explicit path to ProjectVersion.txt.
.PARAMETER HubInstallPath
    Optional path to Unity Hub installation.
.EXAMPLE
    .\Get-UnityVersion.ps1 -ProjectPath "samples/minimal-project"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath = ".",

    [Parameter(Mandatory = $false)]
    [string]$ProjectVersionFile,

    [Parameter(Mandatory = $false)]
    [string]$HubInstallPath = "C:\Program Files\Unity Hub\Unity Hub.exe"
)

$ErrorActionPreference = "Stop"

$VersionFile = if (-not [string]::IsNullOrWhiteSpace($ProjectVersionFile)) {
    $ProjectVersionFile
} else {
    Join-Path $ProjectPath "ProjectSettings/ProjectVersion.txt"
}

if (-not (Test-Path $VersionFile)) {
    throw "ProjectVersion.txt not found at '$VersionFile'."
}

$content = Get-Content -Path $VersionFile -Raw
$Version = ""
$Changeset = ""

if ($content -match "m_EditorVersionWithRevision:\s*([^\s]+)\s*\(([a-f0-9]+)\)") {
    $Version = $Matches[1]
    $Changeset = $Matches[2]
} elseif ($content -match "m_EditorVersion:\s*([^\s]+)") {
    $Version = $Matches[1]
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    throw "Failed to extract Unity editor version from '$VersionFile'."
}

Write-Host "=== Unity Version Resolution ===" -ForegroundColor Cyan
Write-Host "Resolved Version:   $Version"
Write-Host "Resolved Changeset: $(if ($Changeset) { $Changeset } else { 'none' })"

# Locate Unity.exe on the Windows filesystem
$CandidatePaths = @(
    "C:\Program Files\Unity\Hub\Editor\$Version\Editor\Unity.exe",
    "C:\Program Files\Unity\$Version\Editor\Unity.exe",
    "C:\Program Files\Unity\Editor\Unity.exe"
)

$ResolvedEditorPath = ""
foreach ($path in $CandidatePaths) {
    if (Test-Path $path) {
        $ResolvedEditorPath = $path
        break
    }
}

if ([string]::IsNullOrWhiteSpace($ResolvedEditorPath)) {
    Write-Warning "Unity.exe for version '$Version' was not found in standard Hub installation folders."
} else {
    Write-Host "Found Unity Editor: $ResolvedEditorPath" -ForegroundColor Green
}

# Export to GitHub Actions step outputs if running in CI
if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT) -and (Test-Path $env:GITHUB_OUTPUT)) {
    Add-Content -Path $env:GITHUB_OUTPUT -Value "unity_version=$Version"
    Add-Content -Path $env:GITHUB_OUTPUT -Value "unity_changeset=$Changeset"
    Add-Content -Path $env:GITHUB_OUTPUT -Value "unity_path=$ResolvedEditorPath"
}

return [PSCustomObject]@{
    Version    = $Version
    Changeset  = $Changeset
    EditorPath = $ResolvedEditorPath
    Found      = (-not [string]::IsNullOrWhiteSpace($ResolvedEditorPath))
}
