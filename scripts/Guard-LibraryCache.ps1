<#
.SYNOPSIS
    Guards and validates Unity Library/ folder cache integrity.
.DESCRIPTION
    Calculates a composite SHA-256 hash across ProjectVersion.txt, Packages/manifest.json,
    and Packages/packages-lock.json. If the fingerprint matches the cached signature,
    Library/ is preserved for sub-3-minute incremental builds. If a change or corruption is detected,
    Library/ is pruned safely.
.PARAMETER ProjectPath
    Root path to the Unity project. Defaults to current directory.
.PARAMETER CacheSignaturePath
    Path where the cache hash signature is stored relative to ProjectPath.
.PARAMETER ForceClean
    Forces pruning of the Library folder regardless of hash match.
.PARAMETER ManifestFiles
    List of files contributing to the project cache fingerprint.
.EXAMPLE
    .\Guard-LibraryCache.ps1 -ProjectPath "samples/minimal-project"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath = ".",

    [Parameter(Mandatory = $false)]
    [string]$CacheSignaturePath = ".library-cache-hash",

    [Parameter(Mandatory = $false)]
    [switch]$ForceClean,

    [Parameter(Mandatory = $false)]
    [string[]]$ManifestFiles = @(
        "ProjectSettings/ProjectVersion.txt",
        "Packages/manifest.json",
        "Packages/packages-lock.json"
    )
)

$ErrorActionPreference = "Stop"

$ResolvedProjectPath = Resolve-Path -Path $ProjectPath
$LibraryFolder = Join-Path $ResolvedProjectPath "Library"
$SignatureFile = Join-Path $ResolvedProjectPath $CacheSignaturePath

Write-Host "=== Unity Library Cache Guard ===" -ForegroundColor Cyan
Write-Host "Project Path: $ResolvedProjectPath"
Write-Host "Library Path: $LibraryFolder"

# Compute composite SHA-256 hash from existing manifest files
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$combinedBytes = [System.Collections.Generic.List[byte]]::new()

$foundFiles = 0
foreach ($relPath in $ManifestFiles) {
    $fullPath = Join-Path $ResolvedProjectPath $relPath
    if (Test-Path $fullPath) {
        $fileBytes = [System.IO.File]::ReadAllBytes($fullPath)
        $combinedBytes.AddRange($fileBytes)
        $foundFiles++
    }
}

if ($foundFiles -eq 0) {
    Write-Warning "None of the specified manifest files were found under '$ResolvedProjectPath'."
    $CurrentHash = "empty"
} else {
    $hashBytes = $sha256.ComputeHash($combinedBytes.ToArray())
    $CurrentHash = [BitConverter]::ToString($hashBytes).Replace("-", "").ToLowerInvariant()
}

Write-Host "Calculated Cache Fingerprint: $CurrentHash" -ForegroundColor Cyan

# Check existing signature
$PreviousHash = ""
if (Test-Path $SignatureFile) {
    $PreviousHash = (Get-Content -Path $SignatureFile -Raw).Trim()
    Write-Host "Existing Cache Signature:   $PreviousHash"
}

$LibraryExists = Test-Path $LibraryFolder
$MustClean = $ForceClean -or ($CurrentHash -ne $PreviousHash) -or (-not $LibraryExists)

if ($MustClean) {
    if ($ForceClean) {
        Write-Host "ForceClean flag specified: invalidating Library cache." -ForegroundColor Yellow
    } elseif ($CurrentHash -ne $PreviousHash) {
        Write-Host "Cache fingerprint changed ($PreviousHash -> $CurrentHash): invalidating Library cache." -ForegroundColor Yellow
    }

    if ($LibraryExists) {
        Write-Host "Pruning stale Library folder..." -ForegroundColor Yellow
        Remove-Item -Path $LibraryFolder -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Store updated signature
    Set-Content -Path $SignatureFile -Value $CurrentHash -Encoding utf8
    Write-Host "Cache signature updated: $CurrentHash" -ForegroundColor Green
    $ResultStatus = "Invalidated"
} else {
    Write-Host "Cache signature matched ($CurrentHash). Preserving Library folder for fast incremental build." -ForegroundColor Green
    $ResultStatus = "Preserved"
}

return [PSCustomObject]@{
    ProjectPath = $ResolvedProjectPath.Path
    Fingerprint = $CurrentHash
    Status      = $ResultStatus
    Cleaned     = $MustClean
}
