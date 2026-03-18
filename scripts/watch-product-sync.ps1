[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SourceRoot = "",
    [Parameter(Mandatory = $false)]
    [string]$ProductRoot = "",
    [int]$DebounceSeconds = 30,
    [ValidateSet("export", "sync-pr")]
    [string]$Mode = "export"
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

$runnerScript = if ($Mode -eq "sync-pr") {
    Join-Path $repoRoot "scripts/sync-product-pr.ps1"
} else {
    Join-Path $repoRoot "scripts/export-product-snapshot.ps1"
}
$pending = $false
$lastEventAt = Get-Date

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $SourceRoot
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

$handler = {
    $script:pending = $true
    $script:lastEventAt = Get-Date
}

$subscriptions = @(
    Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $handler,
    Register-ObjectEvent -InputObject $watcher -EventName Created -Action $handler,
    Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $handler,
    Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $handler
)

Write-Host "Watching local runtime for product-worthy changes..."
Write-Host "SourceRoot: $SourceRoot"
Write-Host "ProductRoot: $ProductRoot"
Write-Host "Mode: $Mode"

try {
    while ($true) {
        Start-Sleep -Seconds 2

        if (-not $pending) {
            continue
        }

        $elapsed = (Get-Date) - $lastEventAt
        if ($elapsed.TotalSeconds -lt $DebounceSeconds) {
            continue
        }

        $pending = $false
        Write-Host "Change detected. Running product sync pipeline..."
        & $runnerScript -SourceRoot $SourceRoot -ProductRoot $ProductRoot
    }
}
finally {
    foreach ($subscription in $subscriptions) {
        Unregister-Event -SourceIdentifier $subscription.Name -ErrorAction SilentlyContinue
    }

    $watcher.Dispose()
}
