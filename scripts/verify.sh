#!/usr/bin/env bash
# scripts/verify.sh: cross-platform verification script for unity-build-pipeline
set -o pipefail
MODE="${1:-full}"
case "$MODE" in fast|full) ;; *) echo "usage: verify.sh [fast|full]" >&2; exit 64 ;; esac
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

# Ensure agent-team managed tools (~/.agent-team/bin) are in PATH
if [ -d "$HOME/.agent-team/bin" ]; then
  case ":$PATH:" in *":$HOME/.agent-team/bin:"*) ;; *) PATH="$HOME/.agent-team/bin:$PATH" ;; esac
fi

FAILED=""; SKIPPED=""; RAN=0
step() {
  local label="$1"; shift
  printf '\n> %s\n' "$label"; RAN=$((RAN + 1))
  if "$@"; then printf 'ok  %s\n' "$label"; else printf 'FAIL %s\n' "$label"; FAILED="$FAILED, $label"; fi
}
skip() {
  case "$SKIPPED," in *", $1,"*) return 0 ;; esac
  printf 'SKIPPED %s\n' "$1" >&2; SKIPPED="$SKIPPED, $1"
}
have() { if command -v "$1" >/dev/null 2>&1 || [ -x "$1" ]; then return 0; fi; skip "$1 (not installed)"; return 1; }

cleanroom_guard() {
  local bad=0
  for forbidden in "Vue""XR" "Trium"" Designs" "Fudge""3d"; do
    if git grep -I -q "$forbidden" -- ':(exclude)scripts/verify.*' 2>/dev/null; then
      echo "ERROR: Forbidden string '$forbidden' detected in repository!"
      bad=1
    fi
  done
  return $bad
}

meta_check() {
  local bad=0
  if [ -d "samples/minimal-project/Assets" ]; then
    while IFS= read -r f; do
      case "$f" in *.meta|*/.*|*~|*~/*) continue ;; esac
      if [ ! -f "$f.meta" ]; then
        echo "ERROR: Missing .meta file for $f"
        bad=1
      fi
    done < <(find "samples/minimal-project/Assets" -type f)
  fi
  return $bad
}

pssa_check() {
  if have pwsh; then
    pwsh -NoProfile -ExecutionPolicy Bypass -Command "
      Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue
      \$settings = if (Test-Path './PSScriptAnalyzerSettings.psd1') { './PSScriptAnalyzerSettings.psd1' } else { \$null }
      \$targets = @('runner', 'scripts') | Where-Object { Test-Path \$_ }
      \$hasErrors = \$false
      foreach (\$target in \$targets) {
        \$params = @{ Path = \$target; Recurse = \$true }
        if (\$settings) { \$params['Settings'] = \$settings }
        \$res = Invoke-ScriptAnalyzer @params
        \$issues = \$res | Where-Object { \$_.Severity -in @('Error', 'Warning') }
        if (\$issues) {
          \$issues | Format-Table ScriptName, Line, Severity, Message | Out-String | Write-Host
          \$hasErrors = \$true
        }
      }
      if (\$hasErrors) { exit 1 }
    " || return 1
  fi
  return 0
}

actionlint_check() {
  if [ -d ".github/workflows" ]; then
    if have actionlint; then
      actionlint || return 1
    fi
  fi
  return 0
}

yamllint_check() {
  if [ -d ".github/workflows" ]; then
    if have yamllint; then
      yamllint -c .yamllint.yml .github/workflows/ || return 1
    fi
  fi
  return 0
}

pester_check() {
  if [ -d "tests/Pester" ]; then
    if have pwsh; then
      pwsh -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Pester -Path tests/Pester -Output Detailed" || return 1
    else
      skip "pwsh (Pester tests skipped on non-PowerShell host)"
    fi
  fi
  return 0
}

triggers_check() {
  if [ -f "scripts/check-self-hosted-triggers.ps1" ]; then
    if have pwsh; then
      pwsh -NoProfile -ExecutionPolicy Bypass -File "scripts/check-self-hosted-triggers.ps1" || return 1
    fi
  fi
  return 0
}

# ---------------------------------------------------------------- FAST ----
fast_checks() {
  step "clean-room keyword & secret guard" cleanroom_guard
  step "unity .meta file integrity" meta_check
  step "powershell static analysis (PSScriptAnalyzer)" pssa_check
  step "actionlint workflow validation" actionlint_check
  step "yamllint workflow validation" yamllint_check
}

# ---------------------------------------------------------------- FULL ----
full_checks() {
  fast_checks
  step "pester unit tests" pester_check
  if [ -f "scripts/check-self-hosted-triggers.ps1" ]; then
    step "self-hosted trigger check" triggers_check
  fi
}

if [ "$MODE" = "fast" ]; then
  fast_checks
elif [ "$MODE" = "full" ]; then
  full_checks
fi

if [ -n "$FAILED" ]; then
  printf '\nverify %s: FAILED (%s)\n' "$MODE" "${FAILED#, }"
  exit 1
fi
if [ -n "$SKIPPED" ]; then
  printf '\nverify %s: INCOMPLETE. %d checks passed, NOT VERIFIED (skipped): %s\n' "$MODE" "$RAN" "${SKIPPED#, }"
  exit 0
fi
if [ "$RAN" -eq 0 ]; then
  printf '\nverify %s: NO CHECKS RAN. Nothing is configured yet; fill fast_checks/full_checks.\n' "$MODE"
  if [ "$MODE" = "full" ]; then exit 3; fi
  exit 0
fi
printf '\nverify %s: OK (%d checks passed)\n' "$MODE" "$RAN"
exit 0
