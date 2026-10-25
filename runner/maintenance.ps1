<#
.SYNOPSIS
    Scheduled maintenance task for self-hosted Windows Unity build runners.
.DESCRIPTION
    Monitors available disk space, prunes stale workspaces and old build logs,
    and optionally recycles the GitHub Actions runner service to reclaim system memory.
.PARAMETER RunnerWorkDir
    Path to the runner working directory where repository checkouts reside.
.PARAMETER FreeDiskThresholdGB
    Minimum free disk space threshold in gigabytes before warnings are emitted.
.PARAMETER LogMaxAgeDays
    Maximum age in days for build and diagnostic log files before deletion.
.PARAMETER WorkspaceMaxAgeDays
    Maximum age in days for untouched repository workspaces before pruning.
.PARAMETER ServiceName
    Name or pattern of the GitHub Actions Windows Service to monitor.
.PARAMETER RestartService
    Switch to restart the runner service during maintenance.
.EXAMPLE
    .\maintenance.ps1 -RunnerWorkDir "C:\actions-runner\_work" -FreeDiskThresholdGB 40
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RunnerWorkDir = "C:\actions-runner\_work",

    [Parameter(Mandatory = $false)]
    [int]$FreeDiskThresholdGB = 50,

    [Parameter(Mandatory = $false)]
    [int]$LogMaxAgeDays = 14,

    [Parameter(Mandatory = $false)]
    [int]$WorkspaceMaxAgeDays = 30,

    [Parameter(Mandatory = $false)]
    [string]$ServiceName = "actions.runner.*",

    [Parameter(Mandatory = $false)]
    [switch]$RestartService
)

$ErrorActionPreference = "Stop"

Write-Host "=== Self-Hosted Runner Maintenance Run ===" -ForegroundColor Cyan
$Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
Write-Host "Execution Timestamp: $Timestamp"

# 1. Disk Space Monitoring
$DriveLetter = [System.IO.Path]::GetPathRoot($RunnerWorkDir)
$Drive = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $DriveLetter.TrimEnd('\') }

if ($null -ne $Drive) {
    $FreeGB = [math]::Round($Drive.FreeSpace / 1GB, 2)
    $TotalGB = [math]::Round($Drive.Size / 1GB, 2)
    Write-Host "Drive $DriveLetter Free Space: $FreeGB GB / $TotalGB GB" -ForegroundColor Cyan

    if ($FreeGB -lt $FreeDiskThresholdGB) {
        Write-Warning "Disk space alert: Drive $DriveLetter has only $FreeGB GB free, below the threshold of $FreeDiskThresholdGB GB!"
    } else {
        Write-Host "Disk space is healthy." -ForegroundColor Green
    }
} else {
    Write-Warning "Could not query drive information for path '$RunnerWorkDir'."
}

# 2. Prune Stale Log Files
if (Test-Path $RunnerWorkDir) {
    Write-Host "Scanning for logs older than $LogMaxAgeDays days in '$RunnerWorkDir'..." -ForegroundColor Cyan
    $LogCutoff = (Get-Date).AddDays(-$LogMaxAgeDays)
    $StaleLogs = Get-ChildItem -Path $RunnerWorkDir -Filter "*.log" -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $LogCutoff }

    $PrunedLogsCount = 0
    foreach ($log in $StaleLogs) {
        try {
            Remove-Item -Path $log.FullName -Force -ErrorAction SilentlyContinue
            $PrunedLogsCount++
        } catch {
            Write-Warning "Failed to delete log: $($log.FullName)"
        }
    }
    Write-Host "Pruned $PrunedLogsCount stale log file(s)." -ForegroundColor Green

    # 3. Prune Untouched Workspaces
    Write-Host "Scanning for workspaces untouched for more than $WorkspaceMaxAgeDays days..." -ForegroundColor Cyan
    $WorkspaceCutoff = (Get-Date).AddDays(-$WorkspaceMaxAgeDays)
    $Workspaces = Get-ChildItem -Path $RunnerWorkDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $WorkspaceCutoff }

    $PrunedWorkspacesCount = 0
    foreach ($ws in $Workspaces) {
        Write-Host "Pruning stale workspace: $($ws.FullName)" -ForegroundColor Yellow
        try {
            Remove-Item -Path $ws.FullName -Recurse -Force -ErrorAction SilentlyContinue
            $PrunedWorkspacesCount++
        } catch {
            Write-Warning "Failed to remove workspace: $($ws.FullName)"
        }
    }
    Write-Host "Pruned $PrunedWorkspacesCount stale workspace folder(s)." -ForegroundColor Green
}

# 4. Optional Service Recycling
if ($RestartService) {
    Write-Host "Recycling runner service matching '$ServiceName'..." -ForegroundColor Cyan
    $Services = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    foreach ($svc in $Services) {
        Write-Host "Restarting service: $($svc.Name)" -ForegroundColor Cyan
        Restart-Service -Name $svc.Name -Force
        Write-Host "Service $($svc.Name) restarted successfully." -ForegroundColor Green
    }
}

Write-Host "Runner maintenance cycle completed successfully." -ForegroundColor Green
