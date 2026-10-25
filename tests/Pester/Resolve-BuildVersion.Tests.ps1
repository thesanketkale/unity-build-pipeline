BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../scripts/Resolve-BuildVersion.ps1"
}

Describe "Resolve-BuildVersion" {
    Context "Version and BundleCode Computation" {
        It "Returns valid SemVer and bundleVersionCode for repository root" {
            $repoRoot = Join-Path $PSScriptRoot "../.."
            $result = & $script:ScriptPath -RepoRoot $repoRoot -BaseVersion "0.1.0"

            $result.SemanticVersion | Should -Not -BeNullOrEmpty
            $result.AndroidBundleVersionCode | Should -BeGreaterThan 0
            $result.ShortSha | Should -Not -BeNullOrEmpty
        }

        It "Calculates bundleVersionCode with monotonic integer schema" {
            $repoRoot = Join-Path $PSScriptRoot "../.."
            $result = & $script:ScriptPath -RepoRoot $repoRoot -BaseVersion "1.2.3"

            # Major=1, Minor=2, Patch=3 => 1 * 1,000,000 + 2 * 10,000 + 3 * 100 = 1,020,300 + commit offset
            $result.AndroidBundleVersionCode | Should -BeGreaterOrEqual 1020300
        }
    }
}
