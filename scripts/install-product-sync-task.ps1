[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SourceRoot = "",
    [Parameter(Mandatory = $false)]
    [string]$PersistentRoot = "",
    [Parameter(Mandatory = $false)]
    [string]$WorkspaceRoot = "",
    [Parameter(Mandatory = $false)]
    [string]$ProductRoot = "",
    [string]$TaskName = "AutopilotProductSync",
    [string]$Mode = "sync-pr"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($ProductRoot)) {
    $ProductRoot = $repoRoot
}

$ProductRoot = (Resolve-Path $ProductRoot).Path

if ([string]::IsNullOrWhiteSpace($PersistentRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($SourceRoot)) {
        $PersistentRoot = $SourceRoot
    } elseif (-not [string]::IsNullOrWhiteSpace($env:LOCAL_AUTOPILOT_ROOT)) {
        $PersistentRoot = $env:LOCAL_AUTOPILOT_ROOT
    } elseif (-not [string]::IsNullOrWhiteSpace($env:PERSISTENT_AUTOPILOT_ROOT)) {
        $PersistentRoot = $env:PERSISTENT_AUTOPILOT_ROOT
    } elseif (-not [string]::IsNullOrWhiteSpace($env:BB_DEVOPS_AUTOPILOT_HOME)) {
        $PersistentRoot = $env:BB_DEVOPS_AUTOPILOT_HOME
    }
}

if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($env:WORKSPACE_AUTOPILOT_ROOT)) {
        $WorkspaceRoot = $env:WORKSPACE_AUTOPILOT_ROOT
    } else {
        $WorkspaceRoot = Split-Path -Parent $ProductRoot
    }
}

if (-not [string]::IsNullOrWhiteSpace($PersistentRoot) -and (Test-Path $PersistentRoot)) {
    $PersistentRoot = (Resolve-Path $PersistentRoot).Path
}

if (-not [string]::IsNullOrWhiteSpace($WorkspaceRoot) -and (Test-Path $WorkspaceRoot)) {
    $WorkspaceRoot = (Resolve-Path $WorkspaceRoot).Path
}

$watchScript = Join-Path $repoRoot "scripts/watch-product-sync.ps1"
$escapedWatchScript = '"' + $watchScript + '"'
$escapedProductRoot = '"' + $ProductRoot + '"'
$arguments = "-NoProfile -ExecutionPolicy Bypass -File $escapedWatchScript -ProductRoot $escapedProductRoot -Mode $Mode"

if (-not [string]::IsNullOrWhiteSpace($PersistentRoot)) {
    $arguments += " -PersistentRoot " + '"' + $PersistentRoot + '"'
}

if (-not [string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    $arguments += " -WorkspaceRoot " + '"' + $WorkspaceRoot + '"'
}

$startupDir = [Environment]::GetFolderPath("Startup")
$startupLauncherPath = Join-Path $startupDir "$TaskName.cmd"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries

try {
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Write-Host ("Scheduled task '{0}' registered." -f $TaskName)
}
catch {
    $launcher = @"
@echo off
start "" /min powershell.exe $arguments
"@
    Set-Content -Path $startupLauncherPath -Value $launcher -Encoding ASCII
    Write-Warning ("Register-ScheduledTask failed. Installed startup launcher instead: {0}" -f $startupLauncherPath)
}
