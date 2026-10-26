<#
.SYNOPSIS
    Repository verification script for unity-build-pipeline.
.DESCRIPTION
    Runs static analysis, clean-room secret guards, .meta integrity checks,
    and automated Pester test suites.
    Usage:
        pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1 fast
        pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1 full
#>
param(
    [ValidateSet("fast", "full")]
    [string]$Mode = "full"
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptRoot
Set-Location -Path $RepoRoot

$Failed = [System.Collections.Generic.List[string]]::new()
$Skipped = [System.Collections.Generic.List[string]]::new()
$RanCount = 0

function Invoke-Step {
    param(
        [string]$Label,
        [scriptblock]$Action
    )
    $script:RanCount++
    Write-Host "`n> $Label" -ForegroundColor Cyan
    try {
        & $Action
        Write-Host "ok  $Label" -ForegroundColor Green
    }
    catch {
        Write-Host "FAIL $Label" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        $script:Failed.Add($Label)
    }
}

function Add-Skip {
    param([string]$Label)
    Write-Host "SKIPPED $Label" -ForegroundColor Yellow
    $script:Skipped.Add($Label)
}

function fast_checks {
    # --- STEP: Clean-Room Guard ---
    Invoke-Step "clean-room keyword & secret guard" {
        $forbidden = @("Vue" + "XR", "Trium" + " Designs", "Fudge" + "3d")
        $trackedFiles = git ls-files
        foreach ($file in $trackedFiles) {
            if ($file -match "scripts/verify\.") { continue }
            if (-not (Test-Path $file)) { continue }
            $content = Get-Content -Path $file -Raw -ErrorAction SilentlyContinue
            if ($null -eq $content) { continue }
            foreach ($pattern in $forbidden) {
                if ($content -match $pattern) {
                    throw "Forbidden pattern '$pattern' found in file: $file"
                }
            }
        }
    }

    # --- STEP: Unity .meta File Integrity ---
    Invoke-Step "unity .meta file integrity" {
        if (Test-Path "samples/minimal-project/Assets") {
            $assets = Get-ChildItem -Path "samples/minimal-project/Assets" -Recurse
            foreach ($item in $assets) {
                if ($item.Extension -eq ".meta") { continue }
                $expectedMeta = "$($item.FullName).meta"
                if (-not (Test-Path $expectedMeta)) {
                    throw "Missing .meta file for asset: $($item.FullName)"
                }
            }
        }
    }

    # --- STEP: PSScriptAnalyzer ---
    Invoke-Step "powershell static analysis (PSScriptAnalyzer)" {
        if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
            Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue
            $targets = @("runner", "scripts", "tests") | Where-Object { Test-Path $_ }
            $settingsPath = Join-Path $RepoRoot "PSScriptAnalyzerSettings.psd1"
            $results = [System.Collections.Generic.List[object]]::new()
            foreach ($target in $targets) {
                $params = @{ Path = $target; Recurse = $true }
                if (Test-Path $settingsPath) { $params['Settings'] = $settingsPath }
                $analysis = Invoke-ScriptAnalyzer @params
                if ($null -ne $analysis) {
                    foreach ($item in $analysis) {
                        $results.Add($item)
                    }
                }
            }
            $errorsOrWarnings = $results | Where-Object { $_.Severity -in @("Error", "Warning") }
            if ($errorsOrWarnings.Count -gt 0) {
                $msg = ($errorsOrWarnings | ForEach-Object { "$($_.ScriptName):$($_.Line) [$($_.Severity)] $($_.Message)" }) -join "`n"
                throw "PSScriptAnalyzer issues detected:`n$msg"
            }
        } else {
            Add-Skip "PSScriptAnalyzer (module not installed)"
        }
    }

    # --- STEP: GitHub Actions Workflow Linting (actionlint) ---
    Invoke-Step "actionlint & workflow validation" {
        $actionlint = Get-Command actionlint -ErrorAction SilentlyContinue
        if ($null -ne $actionlint) {
            $wfFiles = Get-ChildItem -Path ".github/workflows" -Filter "*.yml" -Recurse -ErrorAction SilentlyContinue
            if ($wfFiles.Count -gt 0) {
                $output = & $actionlint.Source 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "actionlint failed:`n$output"
                }
            }
        } else {
            Add-Skip "actionlint (binary not on PATH)"
        }
    }

    # --- STEP: yamllint ---
    Invoke-Step "yamllint workflow validation" {
        $yamllint = Get-Command yamllint -ErrorAction SilentlyContinue
        if ($null -ne $yamllint) {
            $output = & $yamllint.Source -c .yamllint.yml .github/ 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "yamllint failed:`n$output"
            }
        } else {
            Add-Skip "yamllint (binary not on PATH)"
        }
    }
}

function full_checks {
    fast_checks

    # --- STEP: Pester Unit Tests ---
    Invoke-Step "pester unit test suite" {
        if (Test-Path "tests/Pester") {
            if (Get-Module -ListAvailable -Name Pester) {
                Import-Module Pester -ErrorAction SilentlyContinue
                $pesterConfig = [PesterConfiguration]::Default
                $pesterConfig.Run.Path = "tests/Pester"
                $pesterConfig.Output.Verbosity = "Detailed"
                $pesterConfig.Run.Exit = $false
                $testResult = Invoke-Pester -Configuration $pesterConfig
                if ($testResult.FailedCount -gt 0) {
                    throw "$($testResult.FailedCount) Pester test(s) failed."
                }
            } else {
                Add-Skip "Pester (module not installed)"
            }
        }
    }

    # --- STEP: Check Self-Hosted Triggers (if present) ---
    if (Test-Path "scripts/check-self-hosted-triggers.ps1") {
        Invoke-Step "self-hosted trigger check" {
            & (Join-Path $ScriptRoot "check-self-hosted-triggers.ps1")
        }
    }
}

if ($Mode -eq "fast") {
    fast_checks
} elseif ($Mode -eq "full") {
    full_checks
}

Write-Host ""
if ($Failed.Count -gt 0) {
    Write-Host "verify ${Mode}: FAILED ($($Failed -join ', '))" -ForegroundColor Red
    exit 1
}

if ($Skipped.Count -gt 0) {
    Write-Host "verify ${Mode}: INCOMPLETE. $RanCount checks passed, NOT VERIFIED (skipped): $($Skipped -join ', ')" -ForegroundColor Yellow
    exit 0
}

if ($RanCount -eq 0) {
    Write-Host "verify ${Mode}: NO CHECKS RAN. Nothing is configured yet; fill fast_checks/full_checks." -ForegroundColor Yellow
    if ($Mode -eq "full") { exit 3 }
    exit 0
}

Write-Host "verify ${Mode}: OK ($RanCount checks passed)" -ForegroundColor Green
exit 0
