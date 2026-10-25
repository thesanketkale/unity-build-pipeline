<#
.SYNOPSIS
    Manages Unity Editor license activation, status checks, and license returns.
.DESCRIPTION
    Provides automated CLI helpers for Unity build server licensing. Masks credentials
    and executes official Unity batchmode licensing commands.
.PARAMETER Action
    The licensing action to perform: Activate, Return, or Status.
.PARAMETER Serial
    Unity serial key (e.g. XX-XXXX-XXXX-XXXX-XXXX-XXXX).
.PARAMETER Username
    Unity ID account username or email address.
.PARAMETER Password
    Unity ID account password.
.PARAMETER UnityPath
    Path to the Unity.exe binary. If omitted, attempts auto-detection via default paths.
.EXAMPLE
    .\license.ps1 -Action Status
.EXAMPLE
    .\license.ps1 -Action Activate -Serial "SC-XXXX-..." -Username "builder@example.com" -Password "secret"
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "Password")]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Activate", "Return", "Status")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$Serial,

    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [string]$Password,

    [Parameter(Mandatory = $false)]
    [string]$UnityPath
)

$ErrorActionPreference = "Stop"

Write-Host "=== Unity License Management [$Action] ===" -ForegroundColor Cyan

# Resolve Unity.exe path
$ResolvedUnityPath = $UnityPath
if ([string]::IsNullOrWhiteSpace($ResolvedUnityPath)) {
    $commonRoots = @(
        "C:\Program Files\Unity\Hub\Editor",
        "C:\Program Files\Unity"
    )
    foreach ($root in $commonRoots) {
        if (Test-Path $root) {
            $candidates = Get-ChildItem -Path $root -Filter "Unity.exe" -Recurse -ErrorAction SilentlyContinue
            if ($candidates.Count -gt 0) {
                $ResolvedUnityPath = $candidates[0].FullName
                break
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($ResolvedUnityPath) -or -not (Test-Path $ResolvedUnityPath)) {
    throw "Unity.exe executable not found. Specify -UnityPath explicitly."
}

Write-Host "Using Unity Editor: $ResolvedUnityPath" -ForegroundColor Cyan

switch ($Action) {
    "Status" {
        Write-Host "Checking current license status..." -ForegroundColor Cyan
        $logPath = Join-Path $env:TEMP "unity-license-status.log"
        $process = Start-Process -FilePath $ResolvedUnityPath -ArgumentList @("-batchmode", "-quit", "-nographics", "-logFile", $logPath) -Wait -PassThru -NoNewWindow
        
        if (Test-Path $logPath) {
            $logContent = Get-Content -Path $logPath -Raw
            if ($logContent -match "(License is valid|Successfully activated|License type:)") {
                Write-Host "Unity license is active." -ForegroundColor Green
            } elseif ($logContent -match "(No valid Unity license found|Failed to activate)") {
                Write-Warning "No active Unity license detected."
            } else {
                Write-Host "License status check completed (Exit code: $($process.ExitCode))."
            }
            Remove-Item -Path $logPath -Force -ErrorAction SilentlyContinue
        }
    }

    "Activate" {
        if ([string]::IsNullOrWhiteSpace($Serial) -or [string]::IsNullOrWhiteSpace($Username) -or [string]::IsNullOrWhiteSpace($Password)) {
            throw "License activation requires -Serial, -Username, and -Password."
        }

        Write-Host "Activating license for user $Username with serial [REDACTED]..." -ForegroundColor Cyan
        $logPath = Join-Path $env:TEMP "unity-license-activate.log"

        $argsList = @(
            "-batchmode",
            "-quit",
            "-nographics",
            "-serial", $Serial,
            "-username", $Username,
            "-password", $Password,
            "-logFile", $logPath
        )

        $process = Start-Process -FilePath $ResolvedUnityPath -ArgumentList $argsList -Wait -PassThru -NoNewWindow
        
        if (Test-Path $logPath) {
            $logContent = Get-Content -Path $logPath -Raw
            Remove-Item -Path $logPath -Force -ErrorAction SilentlyContinue
            if ($logContent -match "Failed to activate") {
                throw "Unity license activation failed: $logContent"
            }
        }

        if ($process.ExitCode -eq 0) {
            Write-Host "Unity license activated successfully." -ForegroundColor Green
        } else {
            throw "Unity license activation returned non-zero exit code: $($process.ExitCode)"
        }
    }

    "Return" {
        Write-Host "Returning active Unity license..." -ForegroundColor Cyan
        $logPath = Join-Path $env:TEMP "unity-license-return.log"
        $argsList = @(
            "-batchmode",
            "-quit",
            "-nographics",
            "-returnlicense",
            "-logFile", $logPath
        )

        $process = Start-Process -FilePath $ResolvedUnityPath -ArgumentList $argsList -Wait -PassThru -NoNewWindow
        if (Test-Path $logPath) {
            Remove-Item -Path $logPath -Force -ErrorAction SilentlyContinue
        }

        if ($process.ExitCode -eq 0) {
            Write-Host "Unity license returned successfully." -ForegroundColor Green
        } else {
            Write-Warning "Unity license return completed with code $($process.ExitCode)."
        }
    }
}
