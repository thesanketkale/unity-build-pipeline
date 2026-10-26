<#
.SYNOPSIS
    Maps Unity batchmode exit codes to human-readable diagnostics and GitHub Actions annotations.
.DESCRIPTION
    Translates numeric Unity Editor exit codes into categorized error descriptions.
    Optionally parses the Unity Editor log file to extract root cause errors and emits
    GitHub Actions workflow annotations (::error::).
.PARAMETER ExitCode
    The process exit code returned by Unity.exe.
.PARAMETER LogFile
    Optional path to the Unity batchmode logFile.
.PARAMETER NoAnnotation
    Suppresses GitHub Actions ::error:: workflow annotation output.
.EXAMPLE
    .\Map-UnityExitCode.ps1 -ExitCode 2 -LogFile "unity.log"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$ExitCode,

    [Parameter(Mandatory = $false)]
    [string]$LogFile,

    [Parameter(Mandatory = $false)]
    [switch]$NoAnnotation
)

$ErrorActionPreference = "Stop"

$ExitCodeTable = @{
    0   = @{ Category = "Success"; Description = "Operation completed successfully (Tests passed or Build succeeded)." }
    1   = @{ Category = "GeneralFailure"; Description = "General build failure, uncaught exception, or user script error." }
    2   = @{ Category = "CompilationError"; Description = "Scripts failed to compile. Check C# syntax or missing dependencies." }
    3   = @{ Category = "TestFailure"; Description = "One or more EditMode or PlayMode tests failed." }
    134 = @{ Category = "AbortSignal"; Description = "Unity aborted with SIGABRT (native crash or assertion failure)." }
    137 = @{ Category = "OutOfMemory"; Description = "Unity process was terminated due to memory exhaustion (OOM)." }
}

$Mapping = if ($ExitCodeTable.ContainsKey($ExitCode)) {
    $ExitCodeTable[$ExitCode]
} else {
    @{ Category = "Unknown"; Description = "Unity exited with undocumented exit code $ExitCode." }
}

$ExtractedErrors = [System.Collections.Generic.List[string]]::new()

if (-not [string]::IsNullOrWhiteSpace($LogFile) -and (Test-Path $LogFile)) {
    $logLines = Get-Content -Path $LogFile
    foreach ($line in $logLines) {
        if ($line -match "error CS\d+:" -or
            $line -match "(?i)Compilation failed:" -or
            $line -match "(?i)\[Licensing::Client\]" -or
            $line -match "(?i)Exception:" -or
            $line -match "(?i)Crash!!!" -or
            $line -match "(?i)Display: No graphic device found") {
            $trimmed = $line.Trim()
            if (-not $ExtractedErrors.Contains($trimmed)) {
                $ExtractedErrors.Add($trimmed)
            }
        }
    }
}

Write-Host "=== Unity Exit Code Diagnostic ===" -ForegroundColor Cyan
Write-Host "Exit Code:   $ExitCode"
Write-Host "Category:    $($Mapping.Category)"
Write-Host "Description: $($Mapping.Description)"

$annotationMsg = $null
if ($ExitCode -ne 0) {
    # Format message for GitHub Actions annotation
    $annotationMsg = "Unity failed with exit code $ExitCode ($($Mapping.Category)): $($Mapping.Description)"
    if ($ExtractedErrors.Count -gt 0) {
        $sampleErrors = ($ExtractedErrors | Select-Object -First 3) -join " | "
        $annotationMsg += " - Details: $sampleErrors"
    }

    $shouldAnnotate = ($ExitCode -ne 0) -and (-not $NoAnnotation) -and (-not $env:PESTER_TESTING)
    if ($shouldAnnotate) {
        Write-Host "::error::$annotationMsg"
    }
}

return [PSCustomObject]@{
    ExitCode          = $ExitCode
    Category          = $Mapping.Category
    Description       = $Mapping.Description
    ExtractedErrors   = $ExtractedErrors.ToArray()
    AnnotationMessage = $annotationMsg
}
