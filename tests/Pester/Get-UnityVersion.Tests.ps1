BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../scripts/Get-UnityVersion.ps1"
}

Describe "Get-UnityVersion" {
    Context "Version Parsing Logic" {
        It "Extracts editor version and changeset revision correctly" {
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
            $psDir = Join-Path $tempDir "ProjectSettings"
            New-Item -ItemType Directory -Path $psDir -Force | Out-Null

            $versionFile = Join-Path $psDir "ProjectVersion.txt"
            $versionContent = @(
                "m_EditorVersion: 2022.3.48f1",
                "m_EditorVersionWithRevision: 2022.3.48f1 (79c884501a30)"
            ) -join "`n"
            Set-Content -Path $versionFile -Value $versionContent

            try {
                $result = & $script:ScriptPath -ProjectPath $tempDir
                $result.Version | Should -Be "2022.3.48f1"
                $result.Changeset | Should -Be "79c884501a30"
            }
            finally {
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Parses sample project version file successfully" {
            $sampleRoot = Join-Path $PSScriptRoot "../../samples/minimal-project"
            $result = & $script:ScriptPath -ProjectPath $sampleRoot
            $result.Version | Should -Be "2022.3.48f1"
            $result.Changeset | Should -Be "79c884501a30"
        }

        It "Throws when ProjectVersion.txt does not exist" {
            { & $script:ScriptPath -ProjectPath "non_existent_folder_xyz" } | Should -Throw
        }
    }
}
