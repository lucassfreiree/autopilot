[CmdletBinding()]
param(
    [string]$TaskName = "AutopilotProductSync"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
Write-Host ("Scheduled task '{0}' removed." -f $TaskName)
