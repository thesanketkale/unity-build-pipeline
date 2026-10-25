BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../scripts/Guard-LibraryCache.ps1"
}

Describe "Guard-LibraryCache" {
    Context "Cache Lifecycle and Invalidation" {
        It "Creates initial cache signature when no signature exists" {
            $testDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path (Join-Path $testDir "ProjectSettings") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $testDir "Packages") -Force | Out-Null

            Set-Content -Path (Join-Path $testDir "ProjectSettings/ProjectVersion.txt") -Value "m_EditorVersion: 2022.3.48f1"
            Set-Content -Path (Join-Path $testDir "Packages/manifest.json") -Value '{"dependencies":{}}'

            try {
                $result = & $script:ScriptPath -ProjectPath $testDir
                $result.Status | Should -Be "Invalidated"
                $result.Cleaned | Should -Be $true
                Test-Path (Join-Path $testDir ".library-cache-hash") | Should -Be $true
            }
            finally {
                Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Preserves Library folder when cache signature matches" {
            $testDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path (Join-Path $testDir "ProjectSettings") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $testDir "Packages") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $testDir "Library") -Force | Out-Null

            Set-Content -Path (Join-Path $testDir "ProjectSettings/ProjectVersion.txt") -Value "m_EditorVersion: 2022.3.48f1"
            Set-Content -Path (Join-Path $testDir "Packages/manifest.json") -Value '{"dependencies":{}}'
            Set-Content -Path (Join-Path $testDir "Library/dummy-cache.bin") -Value "cached-data"

            try {
                # First run initializes signature
                $null = & $script:ScriptPath -ProjectPath $testDir

                # Recreate dummy cache file because first run safely established signature
                New-Item -ItemType Directory -Path (Join-Path $testDir "Library") -Force | Out-Null
                Set-Content -Path (Join-Path $testDir "Library/dummy-cache.bin") -Value "cached-data"

                # Second run with identical files
                $secondResult = & $script:ScriptPath -ProjectPath $testDir
                $secondResult.Status | Should -Be "Preserved"
                $secondResult.Cleaned | Should -Be $false
                Test-Path (Join-Path $testDir "Library/dummy-cache.bin") | Should -Be $true
            }
            finally {
                Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Prunes Library folder when manifest files change" {
            $testDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path (Join-Path $testDir "ProjectSettings") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $testDir "Packages") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $testDir "Library") -Force | Out-Null

            Set-Content -Path (Join-Path $testDir "ProjectSettings/ProjectVersion.txt") -Value "m_EditorVersion: 2022.3.48f1"
            Set-Content -Path (Join-Path $testDir "Packages/manifest.json") -Value '{"dependencies":{}}'

            try {
                # Initialize
                $null = & $script:ScriptPath -ProjectPath $testDir

                # Create cached file
                New-Item -ItemType Directory -Path (Join-Path $testDir "Library") -Force | Out-Null
                $markerFile = Join-Path $testDir "Library/stale-marker.txt"
                Set-Content -Path $markerFile -Value "to-be-deleted"

                # Modify manifest
                Set-Content -Path (Join-Path $testDir "Packages/manifest.json") -Value '{"dependencies":{"com.unity.ugui":"1.0.0"}}'

                # Run guard
                $result = & $script:ScriptPath -ProjectPath $testDir
                $result.Status | Should -Be "Invalidated"
                Test-Path $markerFile | Should -Be $false
            }
            finally {
                Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
