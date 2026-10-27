<#
.SYNOPSIS
    Repository verification script for unity-build-pipeline.
.DESCRIPTION
    Runs static analysis, clean-room secret guards, .meta integrity checks,
    and automated Pester test suites. Generates a Markdown Step Summary dashboard
    when GITHUB_STEP_SUMMARY environment variable is present.
    Usage:
        pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1 fast
        pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1 full
#>
param(
    [ValidateSet("fast", "full")]
    [string]$Mode = "full"
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = Split-Path -Path $ScriptRoot -Parent
Set-Location -Path $RepoRoot

$Failed = [System.Collections.Generic.List[string]]::new()
$Skipped = [System.Collections.Generic.List[string]]::new()
$StepRecords = [System.Collections.Generic.List[PSCustomObject]]::new()
$PesterMetrics = $null
$RanCount = 0

function Format-Duration {
    param([TimeSpan]$Duration)
    if ($Duration.TotalSeconds -lt 1) {
        return "$([int]$Duration.TotalMilliseconds)ms"
    }
    return "$([math]::Round($Duration.TotalSeconds, 2))s"
}

function Invoke-Step {
    param(
        [string]$Label,
        [scriptblock]$Action
    )
    $script:RanCount++
    Write-Host "`n> $Label" -ForegroundColor Cyan
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $skipCountBefore = $script:Skipped.Count
    try {
        & $Action
        $sw.Stop()
        if ($script:Skipped.Count -gt $skipCountBefore) {
            $script:StepRecords.Add([PSCustomObject]@{
                Label    = $Label
                Status   = "Skipped"
                Duration = $sw.Elapsed
            })
        }
        else {
            Write-Host "ok  $Label" -ForegroundColor Green
            $script:StepRecords.Add([PSCustomObject]@{
                Label    = $Label
                Status   = "Passed"
                Duration = $sw.Elapsed
            })
        }
    }
    catch {
        $sw.Stop()
        Write-Host "FAIL $Label" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        $script:Failed.Add($Label)
        $script:StepRecords.Add([PSCustomObject]@{
            Label    = $Label
            Status   = "Failed"
            Duration = $sw.Elapsed
        })
    }
}

function Add-Skip {
    param([string]$Label)
    Write-Host "SKIPPED $Label" -ForegroundColor Yellow
    $script:Skipped.Add($Label)
}

function Write-StepSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VerificationMode
    )

    $summaryPath = $env:GITHUB_STEP_SUMMARY
    if ([string]::IsNullOrWhiteSpace($summaryPath)) {
        return
    }

    try {
        $parentDir = Split-Path -Path $summaryPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        $totalCount = $script:StepRecords.Count
        $passedCount = ($script:StepRecords | Where-Object { $_.Status -eq "Passed" }).Count
        $skippedCount = ($script:StepRecords | Where-Object { $_.Status -eq "Skipped" }).Count
        $failedCount = ($script:StepRecords | Where-Object { $_.Status -eq "Failed" }).Count

        $badge = if ($failedCount -gt 0) {
            "![Status: FAILED](https://img.shields.io/badge/Verification-FAILED-d73a49?style=flat-square)"
        } elseif ($skippedCount -gt 0) {
            "![Status: INCOMPLETE](https://img.shields.io/badge/Verification-INCOMPLETE-yellow?style=flat-square)"
        } else {
            "![Status: PASSED](https://img.shields.io/badge/Verification-PASSED-2ea44f?style=flat-square)"
        }

        $statusText = if ($failedCount -gt 0) {
            "❌ Failed"
        } elseif ($skippedCount -gt 0) {
            "⚠️ Incomplete"
        } else {
            "✅ Passed"
        }

        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("## 🛡️ Repository Verification Dashboard ($VerificationMode)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| Status | Total Checks | Passed | Skipped | Failed |")
        [void]$sb.AppendLine("|:---:|:---:|:---:|:---:|:---:|")
        [void]$sb.AppendLine("| $badge<br>**$statusText** | $totalCount | $passedCount | $skippedCount | $failedCount |")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("### Verification Breakdown")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| Step | Status | Duration |")
        [void]$sb.AppendLine("|:---|:---:|:---|")

        foreach ($record in $script:StepRecords) {
            $statusEmoji = switch ($record.Status) {
                "Passed"  { "✅ Passed" }
                "Skipped" { "⚠️ Skipped" }
                "Failed"  { "❌ Failed" }
                default   { $record.Status }
            }
            $durStr = Format-Duration -Duration $record.Duration
            [void]$sb.AppendLine("| $($record.Label) | $statusEmoji | $durStr |")
        }

        if ($null -ne $script:PesterMetrics) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("### 🧪 Pester Test Suite Summary")
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("| Total Tests | Passed | Failed | Skipped | Duration |")
            [void]$sb.AppendLine("|:---:|:---:|:---:|:---:|:---:|")
            $pesterDur = Format-Duration -Duration $script:PesterMetrics.Duration
            [void]$sb.AppendLine("| $($script:PesterMetrics.Total) | $($script:PesterMetrics.Passed) | $($script:PesterMetrics.Failed) | $($script:PesterMetrics.Skipped) | $pesterDur |")
        }

        [void]$sb.AppendLine("")
        $sb.ToString() | Out-File -FilePath $summaryPath -Append -Encoding utf8
    }
    catch {
        Write-Warning -Message "Failed to write GITHUB_STEP_SUMMARY: $($_.Exception.Message)"
    }
}

function fast_checks {
    # --- STEP: Clean-Room Guard ---
    Invoke-Step "clean-room keyword & secret guard" {
        $forbidden = @("Vue" + "XR", "Trium" + " Designs", "Fudge" + "3d")
        $trackedFiles = git ls-files
        foreach ($file in $trackedFiles) {
            if ($file -match "scripts/verify\.") { continue }
            if (-not (Test-Path -Path $file)) { continue }
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
        if (Test-Path -Path "samples/minimal-project/Assets") {
            $assets = Get-ChildItem -Path "samples/minimal-project/Assets" -Recurse
            foreach ($item in $assets) {
                if ($item.Extension -eq ".meta") { continue }
                $expectedMeta = "$($item.FullName).meta"
                if (-not (Test-Path -Path $expectedMeta)) {
                    throw "Missing .meta file for asset: $($item.FullName)"
                }
            }
        }
    }

    # --- STEP: PSScriptAnalyzer ---
    Invoke-Step "powershell static analysis (PSScriptAnalyzer)" {
        if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
            Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue
            $targets = @("runner", "scripts", "tests") | Where-Object { Test-Path -Path $_ }
            $settingsPath = Join-Path -Path $RepoRoot -ChildPath "PSScriptAnalyzerSettings.psd1"
            $results = [System.Collections.Generic.List[object]]::new()
            foreach ($target in $targets) {
                $params = @{ Path = $target; Recurse = $true }
                if (Test-Path -Path $settingsPath) { $params['Settings'] = $settingsPath }
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
        if (Test-Path -Path "tests/Pester") {
            if (Get-Module -ListAvailable -Name Pester) {
                Import-Module Pester -ErrorAction SilentlyContinue
                $pesterConfig = [PesterConfiguration]::Default
                $pesterConfig.Run.Path = "tests/Pester"
                $pesterConfig.Output.Verbosity = "Detailed"
                $pesterConfig.Run.Exit = $false
                $pesterConfig.Run.PassThru = $true
                $testResult = Invoke-Pester -Configuration $pesterConfig
                if ($null -ne $testResult) {
                    $script:PesterMetrics = [PSCustomObject]@{
                        Total    = $testResult.TotalCount
                        Passed   = $testResult.PassedCount
                        Failed   = $testResult.FailedCount
                        Skipped  = $testResult.SkippedCount
                        Duration = $testResult.Duration
                    }
                }
                if ($testResult.FailedCount -gt 0) {
                    throw "$($testResult.FailedCount) Pester test(s) failed."
                }
            } else {
                Add-Skip "Pester (module not installed)"
            }
        }
    }

    # --- STEP: Check Self-Hosted Triggers (if present) ---
    if (Test-Path -Path "scripts/check-self-hosted-triggers.ps1") {
        Invoke-Step "self-hosted trigger check" {
            & (Join-Path -Path $ScriptRoot -ChildPath "check-self-hosted-triggers.ps1")
        }
    }
}

if ($Mode -eq "fast") {
    fast_checks
} elseif ($Mode -eq "full") {
    full_checks
}

Write-StepSummary -VerificationMode $Mode

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
