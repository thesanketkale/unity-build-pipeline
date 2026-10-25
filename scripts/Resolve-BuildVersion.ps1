<#
.SYNOPSIS
    Calculates semantic build versions and Android bundleVersionCode from Git history.
.DESCRIPTION
    Extracts the latest semantic tag and commit count to generate standard SemVer strings
    and monotonically increasing integer bundleVersionCode values for mobile deployments.
.PARAMETER BaseVersion
    Fallback version when no git tags exist. Defaults to "0.1.0".
.PARAMETER RepoRoot
    Path to the repository root. Defaults to current directory.
.PARAMETER TagPrefix
    Prefix used for release tags. Defaults to "v".
.EXAMPLE
    .\Resolve-BuildVersion.ps1 -BaseVersion "0.1.0"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BaseVersion = "0.1.0",

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = ".",

    [Parameter(Mandatory = $false)]
    [string]$TagPrefix = "v"
)

$ErrorActionPreference = "Stop"

Push-Location $RepoRoot
try {
    $ShortSha = "0000000"
    $CommitCount = 0
    $LatestTag = ""

    # Attempt to query git if repository is valid
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($null -ne $gitCmd) {
        $shaOutput = git rev-parse --short HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($shaOutput)) {
            $ShortSha = $shaOutput.Trim()
        }

        $tagOutput = git describe --tags --abbrev=0 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($tagOutput)) {
            $LatestTag = $tagOutput.Trim()
        }

        $countOutput = git rev-list --count HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($countOutput)) {
            $CommitCount = [int]$countOutput.Trim()
        }
    }

    # Resolve SemVer base
    $VersionString = if (-not [string]::IsNullOrWhiteSpace($LatestTag)) {
        $LatestTag.TrimStart($TagPrefix)
    } else {
        $BaseVersion
    }

    # Parse Major, Minor, Patch
    $Major = 0; $Minor = 1; $Patch = 0
    if ($VersionString -match "^(\d+)\.(\d+)\.(\d+)") {
        $Major = [int]$Matches[1]
        $Minor = [int]$Matches[2]
        $Patch = [int]$Matches[3]
    }

    # Formulate Semantic Version
    $SemVer = "$Major.$Minor.$Patch"
    if ($CommitCount -gt 0 -and [string]::IsNullOrWhiteSpace($LatestTag)) {
        $SemVer = "$Major.$Minor.$Patch-preview.$CommitCount+$ShortSha"
    } elseif ($CommitCount -gt 0) {
        $commitsSinceTag = 0
        $commitsSinceOutput = git rev-list "$LatestTag..HEAD" --count 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commitsSinceOutput)) {
            $commitsSinceTag = [int]$commitsSinceOutput.Trim()
        }
        if ($commitsSinceTag -gt 0) {
            $SemVer = "$Major.$Minor.$Patch-preview.$commitsSinceTag+$ShortSha"
        }
    }

    # Monotonically increasing Android bundleVersionCode: Major(2) + Minor(2) + Patch(2) + CommitCount(3)
    # e.g., 1.2.3 with 14 commits -> 1020314
    $BundleVersionCode = ($Major * 1000000) + ($Minor * 10000) + ($Patch * 100) + ($CommitCount % 100)

    Write-Host "=== Version Resolution ===" -ForegroundColor Cyan
    Write-Host "Semantic Version:          $SemVer"
    Write-Host "Android bundleVersionCode: $BundleVersionCode"
    Write-Host "Commit Short SHA:          $ShortSha"
    Write-Host "Total Commits:             $CommitCount"

    # Export to GitHub Actions step outputs if running in CI
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT) -and (Test-Path $env:GITHUB_OUTPUT)) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "semver=$SemVer"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "bundle_version_code=$BundleVersionCode"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "short_sha=$ShortSha"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "commit_count=$CommitCount"
    }

    return [PSCustomObject]@{
        SemanticVersion        = $SemVer
        AndroidBundleVersionCode = $BundleVersionCode
        ShortSha               = $ShortSha
        CommitCount            = $CommitCount
        Major                  = $Major
        Minor                  = $Minor
        Patch                  = $Patch
    }
}
finally {
    Pop-Location
}
