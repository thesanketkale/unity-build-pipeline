# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-25

### Added
- **Windows Runner Provisioning:** PowerShell 7 automation scripts (`runner/install-runner.ps1`, `install-unity.ps1`, `license.ps1`, `maintenance.ps1`) for unattended Actions runner installation, Unity Hub and module deployment, licensing management, and scheduled cache pruning.
- **Library Cache Guard:** `scripts/Guard-LibraryCache.ps1` computes composite SHA-256 fingerprints across `ProjectVersion.txt`, `manifest.json`, and `packages-lock.json` to keep `Library/` intact for 2–4 minute incremental builds while safely pruning on dependency changes.
- **Generic Unity Build Automation:** Production-grade C# Editor script `scripts/BuildScript.cs` supporting batchmode builds for StandaloneWindows64 (Mono & IL2CPP), Android (APK/AAB with keystore signing), WebGL, and StandaloneLinux64.
- **Diagnostic Exit Code Mapper:** `scripts/Map-UnityExitCode.ps1` translates Unity batchmode numeric exit codes into actionable step annotations and error categories.
- **Version & Android BundleCode Resolver:** `scripts/Resolve-BuildVersion.ps1` calculates standard SemVer strings and monotonically increasing integer `bundleVersionCode` values from Git history.
- **Reusable GitHub Actions Workflows:**
  - `unity-test.yml`: Headless batchmode test execution for EditMode and PlayMode test suites with NUnit XML summaries in GitHub Actions Job Summaries.
  - `unity-build.yml`: Multiplatform build matrix supporting Windows, Android with ephemeral keystore lifecycle, and WebGL.
  - `unity-release.yml`: Automated release packaging, artifact compression, and GitHub Release drafting.
- **Minimal Unity Fixture Project:** Hand-authored test project (`samples/minimal-project`) with complete Unity 2022.3 LTS configuration, scene, scripts, EditMode & PlayMode tests, and strict `.meta` file integrity.
- **Automated Pester Test Suite:** Comprehensive test coverage (`tests/Pester/`) for all PowerShell helper modules and scripts.
- **Repository CI & Governance:** Least-privilege workflows (`ci.yml`, `release.yml`, `unity-selftest.yml`), Dependabot, issue forms, PR template, CODEOWNERS, MIT license, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, and NOTICE.
- **Comprehensive Operational Documentation:** In-depth technical guides for architecture, 10-minute runner setup, licensing analysis, Android signing, caching strategies, threat modeling, troubleshooting runbooks, GameCI modes comparison, and owner verification log.
