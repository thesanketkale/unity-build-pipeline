# Contributing to unity-build-pipeline

Thank you for your interest in contributing to `unity-build-pipeline`! We welcome community contributions, bug reports, and workflow enhancements that improve CI/CD automation for Unity developers.

---

## Code of Conduct

All contributors and participants are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). Please report unacceptable behavior through GitHub Private Vulnerability Reporting or via project maintainer contact.

---

## Clean-Room Contribution Rule

This project is governed by strict clean-room software engineering standards:
1. All contributions must be original works authored by the contributor or derived from declared, MIT-compatible open-source dependencies.
2. Under no circumstances may proprietary code, confidential client assets, or internal configurations from commercial organizations, prior employers, or private client contracts be committed or referenced.
3. Sample scenes and assets must use synthetic, placeholder data only.

---

## Development & Testing Workflow

### Prerequisites
- PowerShell 7 (`pwsh`)
- Pester 5.x+ (`Install-Module -Name Pester -Scope CurrentUser -Force`)
- PSScriptAnalyzer (`Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force`)
- [actionlint](https://github.com/rhysd/actionlint) for GitHub Actions workflow linting

### Local Verification
Before opening a pull request, run the full verification suite locally:
```powershell
# Fast static analysis (< 30 seconds)
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1 fast

# Full verification including Pester test suite
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1 full
```
On Linux / macOS:
```bash
bash scripts/verify.sh full
```

---

## Unity Asset & `.meta` File Integrity

Any change adding or moving assets under `samples/` or `Assets/` MUST include matching `.meta` files committed in the same pull request:
- Never edit YAML files manually in a way that breaks Unity serialization.
- Ensure GUIDs remain stable and unique.
- The verification script will fail if any staged asset lacks its `.meta` file.

---

## Pull Request Guidelines

1. Fork the repository and create a feature branch (`feat/<name>`) or bugfix branch (`fix/<name>`).
2. Adhere to [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat(runner): ...`
   - `fix(scripts): ...`
   - `docs: ...`
   - `ci: ...`
3. Pin all third-party GitHub Actions to immutable 40-character commit SHAs with a trailing version comment:
   ```yaml
   uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
   ```
4. Submit your pull request using the provided [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md).
