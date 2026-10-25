BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../scripts/Map-UnityExitCode.ps1"
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
}
