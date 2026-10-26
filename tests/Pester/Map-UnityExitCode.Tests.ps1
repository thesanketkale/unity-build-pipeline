BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../scripts/Map-UnityExitCode.ps1"
    $script:OriginalPesterTesting = $env:PESTER_TESTING
    $env:PESTER_TESTING = "true"
}

AfterAll {
    if ($null -ne $script:OriginalPesterTesting) {
        $env:PESTER_TESTING = $script:OriginalPesterTesting
    } else {
        Remove-Item env:PESTER_TESTING -ErrorAction SilentlyContinue
    }
}

Describe "Map-UnityExitCode" {
    Context "Exit Code Mapping Table" {
        It "Maps exit code 0 to Success" {
            $result = & $script:ScriptPath -ExitCode 0
            $result.ExitCode | Should -Be 0
            $result.Category | Should -Be "Success"
        }

        It "Maps exit code 1 to GeneralFailure" {
            $result = & $script:ScriptPath -ExitCode 1
            $result.ExitCode | Should -Be 1
            $result.Category | Should -Be "GeneralFailure"
        }

        It "Maps exit code 2 to CompilationError" {
            $result = & $script:ScriptPath -ExitCode 2
            $result.ExitCode | Should -Be 2
            $result.Category | Should -Be "CompilationError"
        }

        It "Maps exit code 3 to TestFailure" {
            $result = & $script:ScriptPath -ExitCode 3
            $result.ExitCode | Should -Be 3
            $result.Category | Should -Be "TestFailure"
        }

        It "Maps exit code 137 to OutOfMemory" {
            $result = & $script:ScriptPath -ExitCode 137
            $result.ExitCode | Should -Be 137
            $result.Category | Should -Be "OutOfMemory"
        }

        It "Maps undocumented exit code 99 to Unknown" {
            $result = & $script:ScriptPath -ExitCode 99
            $result.ExitCode | Should -Be 99
            $result.Category | Should -Be "Unknown"
        }
    }

    Context "Log File Error Extraction" {
        It "Extracts compiler errors from unity log file" {
            $tempLog = [System.IO.Path]::GetTempFileName()
            try {
                $logLines = @(
                    "Initialize engine version: 2022.3.48f1",
                    "Assets/Scripts/RotateObject.cs(12,25): error CS0103: The name 'foo' does not exist in the current context",
                    "Compilation failed: 1 error(s), 0 warnings"
                )
                Set-Content -Path $tempLog -Value $logLines

                $result = & $script:ScriptPath -ExitCode 2 -LogFile $tempLog
                $result.ExtractedErrors.Count | Should -BeGreaterThan 0
                $result.ExtractedErrors[0] | Should -Match "error CS0103"
            }
            finally {
                Remove-Item -Path $tempLog -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "AC-0 [BUG-REPRO]: False Annotation Emission Reproduction" {
        It "AC-0 reproduces false ::error:: annotation emission when suppression is absent" {
            $prev = $env:PESTER_TESTING
            try {
                Remove-Item env:PESTER_TESTING -ErrorAction SilentlyContinue
                $output = & $script:ScriptPath -ExitCode 1 6>&1
                $errorLines = @($output | Where-Object { "$_" -match '^::error::' })
                $errorLines.Count | Should -BeGreaterThan 0
                "$($errorLines[0])" | Should -Match "Unity failed with exit code 1 \(GeneralFailure\)"
            }
            finally {
                if ($null -ne $prev) {
                    $env:PESTER_TESTING = $prev
                }
            }
        }
    }

    Context "AC-1 [MAP-NO-ANNOTATION]: Annotation Suppression" {
        It "AC-1 suppresses ::error:: annotation and sets AnnotationMessage when -NoAnnotation is specified" {
            $prev = $env:PESTER_TESTING
            try {
                Remove-Item env:PESTER_TESTING -ErrorAction SilentlyContinue
                $output = & $script:ScriptPath -ExitCode 2 -NoAnnotation 6>&1
                $errorLines = @($output | Where-Object { "$_" -match '^::error::' })
                $errorLines.Count | Should -Be 0

                $result = $output | Where-Object { $_ -is [PSCustomObject] -and $_ -isnot [System.Management.Automation.InformationRecord] }
                $result.ExitCode | Should -Be 2
                $result.AnnotationMessage | Should -Not -BeNullOrEmpty
                $result.AnnotationMessage | Should -Match "Unity failed with exit code 2 \(CompilationError\)"
            }
            finally {
                if ($null -ne $prev) {
                    $env:PESTER_TESTING = $prev
                }
            }
        }

        It "AC-1 suppresses ::error:: annotation when PESTER_TESTING env var is set" {
            $prev = $env:PESTER_TESTING
            try {
                $env:PESTER_TESTING = "true"
                $output = & $script:ScriptPath -ExitCode 3 6>&1
                $errorLines = @($output | Where-Object { "$_" -match '^::error::' })
                $errorLines.Count | Should -Be 0

                $result = $output | Where-Object { $_ -is [PSCustomObject] -and $_ -isnot [System.Management.Automation.InformationRecord] }
                $result.ExitCode | Should -Be 3
                $result.AnnotationMessage | Should -Not -BeNullOrEmpty
                $result.AnnotationMessage | Should -Match "Unity failed with exit code 3 \(TestFailure\)"
            }
            finally {
                if ($null -ne $prev) {
                    $env:PESTER_TESTING = $prev
                }
            }
        }

        It "AC-1 populates AnnotationMessage for non-zero exit codes" {
            $prev = $env:PESTER_TESTING
            try {
                $env:PESTER_TESTING = "true"
                $codes = @(
                    @{ ExitCode = 1; Category = "GeneralFailure" }
                    @{ ExitCode = 2; Category = "CompilationError" }
                    @{ ExitCode = 3; Category = "TestFailure" }
                    @{ ExitCode = 137; Category = "OutOfMemory" }
                    @{ ExitCode = 99; Category = "Unknown" }
                )
                foreach ($case in $codes) {
                    $output = & $script:ScriptPath -ExitCode $case.ExitCode -NoAnnotation 6>&1
                    $result = $output | Where-Object { $_ -is [PSCustomObject] -and $_ -isnot [System.Management.Automation.InformationRecord] }
                    $result.AnnotationMessage | Should -Not -BeNullOrEmpty
                    $result.AnnotationMessage | Should -Match "Unity failed with exit code $($case.ExitCode) \($($case.Category)\)"
                }
            }
            finally {
                if ($null -ne $prev) {
                    $env:PESTER_TESTING = $prev
                }
            }
        }
    }

    Context "AC-2 [MAP-RUNTIME-ANNOTATION]: Runtime Annotation Emission" {
        It "AC-2 does not emit ::error:: and sets AnnotationMessage to null for exit code 0" {
            $prev = $env:PESTER_TESTING
            try {
                Remove-Item env:PESTER_TESTING -ErrorAction SilentlyContinue
                $output = & $script:ScriptPath -ExitCode 0 6>&1
                $errorLines = @($output | Where-Object { "$_" -match '^::error::' })
                $errorLines.Count | Should -Be 0

                $result = $output | Where-Object { $_ -is [PSCustomObject] -and $_ -isnot [System.Management.Automation.InformationRecord] }
                $result.ExitCode | Should -Be 0
                $result.PSObject.Properties.Match("AnnotationMessage").Count | Should -Be 1
                $result.AnnotationMessage | Should -BeNullOrEmpty
            }
            finally {
                if ($null -ne $prev) {
                    $env:PESTER_TESTING = $prev
                }
            }
        }

        It "AC-2 emits ::error:: annotation and returns AnnotationMessage in runtime mode for non-zero exit code" {
            $prev = $env:PESTER_TESTING
            try {
                Remove-Item env:PESTER_TESTING -ErrorAction SilentlyContinue
                $output = & $script:ScriptPath -ExitCode 1 6>&1
                $errorLines = @($output | Where-Object { "$_" -match '^::error::' })
                $errorLines.Count | Should -Be 1
                "$($errorLines[0])" | Should -Be "::error::Unity failed with exit code 1 (GeneralFailure): General build failure, uncaught exception, or user script error."

                $result = $output | Where-Object { $_ -is [PSCustomObject] -and $_ -isnot [System.Management.Automation.InformationRecord] }
                $result.ExitCode | Should -Be 1
                $result.AnnotationMessage | Should -Be "Unity failed with exit code 1 (GeneralFailure): General build failure, uncaught exception, or user script error."
            }
            finally {
                if ($null -ne $prev) {
                    $env:PESTER_TESTING = $prev
                }
            }
        }

        It "AC-2 includes extracted log errors in runtime ::error:: annotation and AnnotationMessage" {
            $tempLog = [System.IO.Path]::GetTempFileName()
            $prev = $env:PESTER_TESTING
            try {
                Remove-Item env:PESTER_TESTING -ErrorAction SilentlyContinue
                $logLines = @(
                    "Assets/Scripts/RotateObject.cs(12,25): error CS0103: The name 'foo' does not exist in the current context",
                    "Compilation failed: 1 error(s), 0 warnings"
                )
                Set-Content -Path $tempLog -Value $logLines

                $output = & $script:ScriptPath -ExitCode 2 -LogFile $tempLog 6>&1
                $errorLines = @($output | Where-Object { "$_" -match '^::error::' })
                $errorLines.Count | Should -Be 1
                "$($errorLines[0])" | Should -Match "Details: Assets/Scripts/RotateObject\.cs"

                $result = $output | Where-Object { $_ -is [PSCustomObject] -and $_ -isnot [System.Management.Automation.InformationRecord] }
                $result.AnnotationMessage | Should -Match "Details: Assets/Scripts/RotateObject\.cs"
            }
            finally {
                Remove-Item -Path $tempLog -Force -ErrorAction SilentlyContinue
                if ($null -ne $prev) {
                    $env:PESTER_TESTING = $prev
                }
            }
        }
    }
}
