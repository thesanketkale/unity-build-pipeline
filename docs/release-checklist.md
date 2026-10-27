# Release & Push Checklist

## CI/CD Warnings, Errors, and Presentation Fixes

Run full verification locally before pushing:
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1 full
```

To push changes to GitHub remote `origin/main`:
```bash
git push origin main
```
