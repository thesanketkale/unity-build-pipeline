BeforeAll {
    $script:RunnerDir = Join-Path $PSScriptRoot "../../runner"
}

Describe "Runner Provisioning Scripts Syntax and Signatures" {
    Context "install-runner.ps1" {
        It "Declares required parameters and parameter sets" {
            $command = Get-Command (Join-Path $script:RunnerDir "install-runner.ps1")
            $command.Parameters.ContainsKey("Token") | Should -Be $true
            $command.Parameters.ContainsKey("RepoUrl") | Should -Be $true
            $command.Parameters.ContainsKey("OrgUrl") | Should -Be $true
            $command.Parameters.ContainsKey("Labels") | Should -Be $true
        }
    }

    Context "install-unity.ps1" {
        It "Declares ProjectVersionFile and module parameters" {
            $command = Get-Command (Join-Path $script:RunnerDir "install-unity.ps1")
            $command.Parameters.ContainsKey("ProjectVersionFile") | Should -Be $true
            $command.Parameters.ContainsKey("Modules") | Should -Be $true
        }
    }

    Context "license.ps1" {
        It "Validates Action parameter choices" {
            $command = Get-Command (Join-Path $script:RunnerDir "license.ps1")
            $actionParam = $command.Parameters["Action"]
            $validateSetAttr = $actionParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSetAttr.ValidValues | Should -Contain "Activate"
            $validateSetAttr.ValidValues | Should -Contain "Return"
            $validateSetAttr.ValidValues | Should -Contain "Status"
        }
    }

    Context "maintenance.ps1" {
        It "Declares disk threshold and pruning parameters" {
            $command = Get-Command (Join-Path $script:RunnerDir "maintenance.ps1")
            $command.Parameters.ContainsKey("FreeDiskThresholdGB") | Should -Be $true
            $command.Parameters.ContainsKey("LogMaxAgeDays") | Should -Be $true
            $command.Parameters.ContainsKey("WorkspaceMaxAgeDays") | Should -Be $true
        }
    }
}
