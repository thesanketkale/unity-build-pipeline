# AGENTS.md: unity-build-pipeline

Shared rules for every AI agent on this repo, in Claude Code (through CLAUDE.md) and Google Antigravity (which reads this file directly).

## Project
- What it is: Self-hosted GitHub Actions pipeline for Unity: Windows runner provisioning, Library caching, EditMode and PlayMode tests, Windows, Android and WebGL builds, keystore signing and versioned releases.
- Users: Unity game developers, technical artists, XR engineers, and DevOps practitioners managing CI/CD on self-hosted Windows hardware.
- Related repos and contracts:
  - `unity-openxr-foundation` (standalone XR starter consuming these workflows)
  - `unity-ui-context` (uGUI inspection tool tested via self-hosted CI)
  - `reusable-workflows` (DevOps baseline and workflow library)

## Stack packs
- github-actions

## Commands
- Install: `pwsh -Command "Install-Module -Name Pester, PSScriptAnalyzer -Scope CurrentUser -Force"`
- Run locally: none (workflow and runner automation library)
- Run tests: `pwsh -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Pester -Path tests/Pester -Output Detailed"`
- Verify fast: `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1 fast` (or `bash scripts/verify.sh fast`)
- Verify full: `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1 full` (or `bash scripts/verify.sh full`)
- Disposable database: none

## Git
- Base branch: main
- Branches: `feat/<slug>`, `fix/<slug>`, `chore/<slug>`
- PR: manual

## Conventions
- Automation scripts use PowerShell 7 (`pwsh`) with strict mode, typed parameters, and PSScriptAnalyzer compliance.
- Scripts are PowerShell 7 (`#requires -Version 7`) with strict mode, `-ErrorAction Stop` and `ShouldProcess` (`-WhatIf`) on every change to the machine. Pester mocks every call that touches the network, the registry, services, disks or Unity, so tests change nothing.
- All third-party GitHub Actions MUST be pinned to verified 40-character commit SHAs with trailing version comments.
- Workflows declare top-level `permissions: {}` and explicit least-privilege permissions per job; `timeout-minutes` and `concurrency` on every workflow; explicit `shell:`; LF line endings; no `${{ github.event.* }}` inside `run:` (use `env:`); OIDC for cloud login. Check with `actionlint`.
- No workflow with a self-hosted job triggers on `pull_request` or `pull_request_target`. `scripts/check-self-hosted-triggers.ps1` enforces it. Self-hosted jobs use the concurrency group `unity-${{ runner.name }}`.
- Keystore material is a base64 secret written to a temporary file, passed by environment variable and deleted in an `if: always()` step. It is never echoed.
- Licence guidance cites the current Unity documentation with its URL and the date it was read, and makes no legal claims.
- Never delete `Library/` arbitrarily; `Library/` is kept between runs on persistent runners and cleared only by `scripts/Guard-LibraryCache.ps1` when manifest/packages/version change.
- All sample Unity assets in `samples/` MUST maintain strict `.meta` file integrity.
- This is a public MIT repository written clean-room: no code, assets, names or data from client or employer projects. Sample data is synthetic. Never hardcode secrets or private client names.
- The standards and this repository's requirements are in `.pipeline/SPEC.md` (local, never committed). Requirement IDs appear in AC lines as `AC-n [ID]` and in test names.
- Docs describe only what exists and was run. What an agent cannot run (push, live cloud, signing, a Unity Editor, GitHub settings) is a `[USER]` item in `docs/release-checklist.md` and is never described as tested.
- Commits are small and follow `<type>(<scope>): <goal> [step N]`. Dates are real and history is never rewritten.
- Dependencies need MIT-compatible licences. Record stack choices and open-decision outcomes in `docs/adr/`.

## Design
- none (--no-design)

## Safety: agents never do these. They prepare the command and hand it over.
- Agents never install a runner, use a registration token, activate a licence or start a Unity build. Registration tokens are never stored or logged, and a test asserts it.
- Run batchmode Unity builds on production machines without user consent.
- Modify live runner services or install software outside the isolated test harness.
- Extract or write Android production keystores or cloud credentials to disk.
- Push directly to protected release branches or overwrite published git tags.
- Never push, tag, create releases, change GitHub settings or run `git filter-repo`; write the command into `docs/release-checklist.md` instead.
- Never print secret values: show only file, line, rule and the last four characters.
