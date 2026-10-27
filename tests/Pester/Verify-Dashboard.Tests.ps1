BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
    $script:VerifyScript = Join-Path $script:RepoRoot "scripts/verify.ps1"
}

Describe "Verify Script Step Summary Dashboard (AC-5)" {
    Context "When GITHUB_STEP_SUMMARY is unset" {
        It "Executes fast verification cleanly without error" {
            $prevSummary = $env:GITHUB_STEP_SUMMARY
            try {
                Remove-Item Env:\GITHUB_STEP_SUMMARY -ErrorAction SilentlyContinue
                $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:VerifyScript fast 2>&1
                $LASTEXITCODE | Should -Be 0
                ($output -join "`n") | Should -Match "verify fast: OK"
            }
            finally {
                if ($null -ne $prevSummary) {
                    $env:GITHUB_STEP_SUMMARY = $prevSummary
                }
            }
        }
    }

    Context "When GITHUB_STEP_SUMMARY is configured" {
        BeforeEach {
            $script:TempSummaryFile = [System.IO.Path]::GetTempFileName()
            $env:GITHUB_STEP_SUMMARY = $script:TempSummaryFile
        }

        AfterEach {
            Remove-Item Env:\GITHUB_STEP_SUMMARY -ErrorAction SilentlyContinue
            if (Test-Path -Path $script:TempSummaryFile) {
                Remove-Item -Path $script:TempSummaryFile -Force -ErrorAction SilentlyContinue
            }
        }

        It "AC-5 writes GitHub Flavored Markdown dashboard to GITHUB_STEP_SUMMARY" {
            $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:VerifyScript fast 2>&1
            $LASTEXITCODE | Should -Be 0
            ($output -join "`n") | Should -Match "verify fast: OK"

            Test-Path -Path $script:TempSummaryFile | Should -Be $true
            $content = Get-Content -Path $script:TempSummaryFile -Raw

            # Assert Title
            $content | Should -Match "## 🛡️ Repository Verification Dashboard \(fast\)"

            # Assert Summary Table & Status Badge
            $content | Should -Match "\| Status \| Total Checks \| Passed \| Skipped \| Failed \|"
            $content | Should -Match "Verification-PASSED"
            $content | Should -Match "✅ Passed"

            # Assert Verification Breakdown Table
            $content | Should -Match "### Verification Breakdown"
            $content | Should -Match "\| Step \| Status \| Duration \|"
            $content | Should -Match "clean-room keyword & secret guard"
            $content | Should -Match "unity \.meta file integrity"
        }

        It "AC-5 appends Pester test suite summary when PesterMetrics are recorded" {
            $tempSummary = [System.IO.Path]::GetTempFileName()
            try {
                $escapedSummary = $tempSummary -replace '\\', '\\'
                $escapedVerifyScript = $script:VerifyScript -replace '\\', '\\'
                $escapedRepoRoot = $script:RepoRoot -replace '\\', '\\'

                $testCode = @"
`$env:GITHUB_STEP_SUMMARY = '$escapedSummary'
`$RepoRoot = '$escapedRepoRoot'
Set-Location `$RepoRoot
`$script:StepRecords = [System.Collections.Generic.List[PSCustomObject]]::new()
`$script:StepRecords.Add([PSCustomObject]@{ Label = 'pester unit test suite'; Status = 'Passed'; Duration = [TimeSpan]::FromSeconds(4.2) })
`$script:PesterMetrics = [PSCustomObject]@{
    Total    = 26
    Passed   = 26
    Failed   = 0
    Skipped  = 0
    Duration = [TimeSpan]::FromSeconds(4.2)
}
`$lines = Get-Content -Path '$escapedVerifyScript'
`$fnDef = (`$lines[27..159] -join [System.Environment]::NewLine)
. ([scriptblock]::Create(`$fnDef))
Write-StepSummary -VerificationMode 'full'
"@
                & pwsh -NoProfile -ExecutionPolicy Bypass -Command $testCode
                Test-Path -Path $tempSummary | Should -Be $true
                $content = Get-Content -Path $tempSummary -Raw

                $content | Should -Match "## 🛡️ Repository Verification Dashboard \(full\)"
                $content | Should -Match "### 🧪 Pester Test Suite Summary"
                $content | Should -Match "\| Total Tests \| Passed \| Failed \| Skipped \| Duration \|"
                $content | Should -Match "\| 26 \| 26 \| 0 \| 0 \|"
            }
            finally {
                Remove-Item -Path $tempSummary -Force -ErrorAction SilentlyContinue
            }
        }

        It "Creates parent directory if GITHUB_STEP_SUMMARY path is in a non-existent folder" {
            $nestedFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
            $nestedSummary = Join-Path $nestedFolder "summary.md"
            $env:GITHUB_STEP_SUMMARY = $nestedSummary

            try {
                $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:VerifyScript fast 2>&1
                $LASTEXITCODE | Should -Be 0
                ($output -join "`n") | Should -Match "verify fast: OK"
                Test-Path -Path $nestedSummary | Should -Be $true
                $content = Get-Content -Path $nestedSummary -Raw
                $content | Should -Match "## 🛡️ Repository Verification Dashboard \(fast\)"
            }
            finally {
                if (Test-Path -Path $nestedFolder) {
                    Remove-Item -Path $nestedFolder -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}
