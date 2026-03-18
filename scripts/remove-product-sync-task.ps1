[CmdletBinding()]
param(
    [string]$TaskName = "AutopilotProductSync"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$startupDir = [Environment]::GetFolderPath("Startup")
$startupLauncherPath = Join-Path $startupDir "$TaskName.cmd"

try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
    Write-Host ("Scheduled task '{0}' removed." -f $TaskName)
}
catch {
    Write-Warning ("Scheduled task '{0}' was not removed via Task Scheduler: {1}" -f $TaskName, $_.Exception.Message)
}

if (Test-Path $startupLauncherPath) {
    Remove-Item -Path $startupLauncherPath -Force
    Write-Host ("Startup launcher removed: {0}" -f $startupLauncherPath)
}
