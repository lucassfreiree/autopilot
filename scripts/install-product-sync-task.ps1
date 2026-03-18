[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SourceRoot = "",
    [Parameter(Mandatory = $false)]
    [string]$ProductRoot = "",
    [string]$TaskName = "AutopilotProductSync",
    [string]$Mode = "sync-pr"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = $env:LOCAL_AUTOPILOT_ROOT
}

if ([string]::IsNullOrWhiteSpace($ProductRoot)) {
    $ProductRoot = $repoRoot
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    throw "SourceRoot is required. Use -SourceRoot or set LOCAL_AUTOPILOT_ROOT."
}

$SourceRoot = (Resolve-Path $SourceRoot).Path
$ProductRoot = (Resolve-Path $ProductRoot).Path
$watchScript = Join-Path $repoRoot "scripts/watch-product-sync.ps1"
$escapedWatchScript = '"' + $watchScript + '"'
$escapedSourceRoot = '"' + $SourceRoot + '"'
$escapedProductRoot = '"' + $ProductRoot + '"'
$startupDir = [Environment]::GetFolderPath("Startup")
$startupLauncherPath = Join-Path $startupDir "$TaskName.cmd"

$arguments = "-NoProfile -ExecutionPolicy Bypass -File $escapedWatchScript -SourceRoot $escapedSourceRoot -ProductRoot $escapedProductRoot -Mode $Mode"
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
