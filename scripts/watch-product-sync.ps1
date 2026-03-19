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
    [Parameter(Mandatory = $false)]
    [string]$MapPath = "",
    [int]$DebounceSeconds = 30,
    [ValidateSet("export", "sync-pr")]
    [string]$Mode = "export"
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

if ([string]::IsNullOrWhiteSpace($MapPath)) {
    $MapPath = Join-Path $repoRoot "config/product-export.map.json"
}

function Resolve-OptionalPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    if (-not (Test-Path $Path)) {
        return $null
    }

    return (Resolve-Path $Path).Path
}

function Normalize-DirectoryPath {
    param([string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Read-JsonFile {
    param([string]$Path)
    return Get-Content $Path -Raw | ConvertFrom-Json
}

$PersistentRoot = Resolve-OptionalPath -Path $PersistentRoot
$WorkspaceRoot = Resolve-OptionalPath -Path $WorkspaceRoot
$MapPath = (Resolve-Path $MapPath).Path
$map = Read-JsonFile -Path $MapPath

$runnerScript = if ($Mode -eq "sync-pr") {
    Join-Path $repoRoot "scripts/sync-product-pr.ps1"
} else {
    Join-Path $repoRoot "scripts/export-product-snapshot.ps1"
}

$watchRoots = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace($PersistentRoot)) {
    [void]$watchRoots.Add((Normalize-DirectoryPath -Path $PersistentRoot))
}
if (-not [string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    $normalizedWorkspaceRoot = Normalize-DirectoryPath -Path $WorkspaceRoot
    if (-not ($watchRoots -contains $normalizedWorkspaceRoot)) {
        [void]$watchRoots.Add($normalizedWorkspaceRoot)
    }
}

if ($watchRoots.Count -eq 0) {
    throw "No watch roots resolved. Configure PersistentRoot or WorkspaceRoot."
}

$script:pending = $false
$script:lastEventAt = Get-Date
$script:ignoredRoots = New-Object System.Collections.Generic.List[string]
[void]$script:ignoredRoots.Add((Normalize-DirectoryPath -Path $ProductRoot))

if ($map.PSObject.Properties.Name -contains "watchIgnorePrefixes") {
    if ($PersistentRoot -and $map.watchIgnorePrefixes.PSObject.Properties.Name -contains "persistent") {
        foreach ($prefix in @($map.watchIgnorePrefixes.persistent)) {
            [void]$script:ignoredRoots.Add((Normalize-DirectoryPath -Path (Join-Path $PersistentRoot $prefix)))
        }
    }

    if ($WorkspaceRoot -and $map.watchIgnorePrefixes.PSObject.Properties.Name -contains "workspace") {
        foreach ($prefix in @($map.watchIgnorePrefixes.workspace)) {
            [void]$script:ignoredRoots.Add((Normalize-DirectoryPath -Path (Join-Path $WorkspaceRoot $prefix)))
        }
    }
}

function Test-IgnoredEventPath {
    param([string]$FullPath)

    if ([string]::IsNullOrWhiteSpace($FullPath)) {
        return $true
    }

    $normalizedPath = [System.IO.Path]::GetFullPath($FullPath)
    if ($normalizedPath -match '\\\.git(\\|$)') {
        return $true
    }

    foreach ($ignoredRoot in @($script:ignoredRoots | Select-Object -Unique)) {
        if ([string]::IsNullOrWhiteSpace($ignoredRoot)) {
            continue
        }

        if ($normalizedPath.StartsWith($ignoredRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

$handler = {
    $fullPath = $Event.SourceEventArgs.FullPath
    if (Test-IgnoredEventPath -FullPath $fullPath) {
        return
    }

    $script:pending = $true
    $script:lastEventAt = Get-Date
}

$watchers = New-Object System.Collections.Generic.List[System.IO.FileSystemWatcher]
$subscriptions = New-Object System.Collections.Generic.List[object]

foreach ($root in @($watchRoots | Select-Object -Unique)) {
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $root
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true
    [void]$watchers.Add($watcher)

    foreach ($eventName in @("Changed", "Created", "Deleted", "Renamed")) {
        [void]$subscriptions.Add((Register-ObjectEvent -InputObject $watcher -EventName $eventName -Action $handler))
    }
}

Write-Host "Watching local runtime for product-worthy changes..."
Write-Host ("PersistentRoot: {0}" -f $(if ($PersistentRoot) { $PersistentRoot } else { "(not set)" }))
Write-Host ("WorkspaceRoot: {0}" -f $(if ($WorkspaceRoot) { $WorkspaceRoot } else { "(not set)" }))
Write-Host "ProductRoot: $ProductRoot"
Write-Host "Mode: $Mode"

try {
    while ($true) {
        Start-Sleep -Seconds 2

        if (-not $script:pending) {
            continue
        }

        $elapsed = (Get-Date) - $script:lastEventAt
        if ($elapsed.TotalSeconds -lt $DebounceSeconds) {
            continue
        }

        $script:pending = $false
        Write-Host "Change detected. Running product sync pipeline..."
        try {
            & $runnerScript -PersistentRoot $PersistentRoot -WorkspaceRoot $WorkspaceRoot -ProductRoot $ProductRoot
        }
        catch {
            Write-Warning ("Product sync pipeline failed: {0}" -f $_.Exception.Message)
        }
    }
}
finally {
    foreach ($subscription in $subscriptions) {
        Unregister-Event -SourceIdentifier $subscription.Name -ErrorAction SilentlyContinue
    }

    foreach ($watcher in $watchers) {
        $watcher.Dispose()
    }
}
