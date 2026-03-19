[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("status", "claim", "complete", "decision", "learning", "handoff", "event", "refresh-auto")]
    [string]$Action = "status",
    [string]$Agent,
    [string]$Description,
    [string[]]$Files = @(),
    [string]$Notes,
    [string]$TaskId,
    [string]$Title,
    [string]$Context,
    [string]$Problem,
    [string]$Solution,
    [string]$ReusablePattern,
    [string]$Decision,
    [string]$Rationale,
    [string]$NextStep,
    [string]$EntryStatus = "in_progress",
    [string]$Category = "general",
    [string]$Source = "",
    [string]$EventStatus = "info",
    [string]$MetadataJson = ""
)

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$syncRoot = Join-Path $workspaceRoot "ai-sync"
$statePath = Join-Path $syncRoot "STATE.json"
$latestPath = Join-Path $syncRoot "LATEST.md"
$autoPath = Join-Path $syncRoot "AUTO.md"
$eventsPath = Join-Path $syncRoot "EVENTS.jsonl"
$decisionsPath = Join-Path $syncRoot "DECISIONS.md"
$learningsPath = Join-Path $syncRoot "LEARNINGS.md"
$handoffPath = Join-Path $syncRoot "HANDOFF.md"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$persistentRoot = "<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot"

function Get-Timestamp {
    return (Get-Date).ToString("o")
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Append-Utf8Line {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    $prefix = ""
    if (Test-Path $Path) {
        $existing = Get-Content $Path -Raw
        if (-not [string]::IsNullOrWhiteSpace($existing) -and -not $existing.EndsWith([Environment]::NewLine)) {
            $prefix = [Environment]::NewLine
        }
    }

    [System.IO.File]::AppendAllText($Path, $prefix + $Line + [Environment]::NewLine, $utf8NoBom)
}

function Append-MarkdownBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Block
    )

    $existing = ""
    if (Test-Path $Path) {
        $existing = Get-Content $Path -Raw
    }

    $trimmed = $existing.TrimEnd()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        $content = $Block.Trim() + [Environment]::NewLine
    } else {
        $content = $trimmed + [Environment]::NewLine + [Environment]::NewLine + $Block.Trim() + [Environment]::NewLine
    }

    Write-Utf8File -Path $Path -Content $content
}

function Normalize-ObjectArray {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ,([object[]]@())
    }

    if ($Value -is [System.Array]) {
        $items = New-Object System.Collections.Generic.List[object]
        foreach ($item in $Value) {
            if ($null -ne $item) {
                [void]$items.Add($item)
            }
        }

        return ,([object[]]$items.ToArray())
    }

    return ,([object[]]@($Value))
}

function Normalize-StringArray {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value
    )

    $items = @()
    foreach ($entry in (Normalize-ObjectArray -Value $Value)) {
        if ($entry -is [string]) {
            $parts = $entry -split "\s*,\s*"
            foreach ($part in $parts) {
                if (-not [string]::IsNullOrWhiteSpace($part)) {
                    $items += $part
                }
            }
        } elseif ($null -ne $entry) {
            $items += [string]$entry
        }
    }

    return ,([string[]]$items)
}

function Normalize-StateCollections {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$State
    )

    $activeList = New-Object System.Collections.Generic.List[object]
    foreach ($task in (Normalize-ObjectArray -Value $State.activeTasks)) {
        if ($null -eq $task) {
            continue
        }

        if ($task.PSObject.Properties.Name.Contains("estimatedFiles")) {
            $task.estimatedFiles = Normalize-StringArray -Value $task.estimatedFiles
        }

        [void]$activeList.Add($task)
    }

    $completedList = New-Object System.Collections.Generic.List[object]
    foreach ($entry in (Normalize-ObjectArray -Value $State.recentCompleted)) {
        if ($null -eq $entry) {
            continue
        }

        if ($entry.PSObject.Properties.Name.Contains("filesChanged")) {
            $entry.filesChanged = Normalize-StringArray -Value $entry.filesChanged
        }

        [void]$completedList.Add($entry)
    }

    $State.activeTasks = $activeList.ToArray()
    $State.recentCompleted = $completedList.ToArray()
}

function Read-State {
    $state = Get-Content $statePath -Raw | ConvertFrom-Json

    if (-not $state.PSObject.Properties.Name.Contains("activeTasks")) {
        $state | Add-Member -NotePropertyName activeTasks -NotePropertyValue @()
    }

    if (-not $state.PSObject.Properties.Name.Contains("recentCompleted")) {
        $state | Add-Member -NotePropertyName recentCompleted -NotePropertyValue @()
    }

    Normalize-StateCollections -State $state
    return $state
}

function Write-State {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$State
    )

    $State.lastUpdated = Get-Timestamp
    Normalize-StateCollections -State $State
    $json = $State | ConvertTo-Json -Depth 10
    Write-Utf8File -Path $statePath -Content ($json + [Environment]::NewLine)
}

function New-TaskId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AgentName
    )

    $safeAgent = ($AgentName.ToLowerInvariant() -replace "[^a-z0-9-]", "-").Trim("-")
    return "task-{0}-{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $safeAgent
}

function Require-Value {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Missing required parameter: $Name"
    }
}

function Try-ReadJsonFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        return Get-Content $Path -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Parse-Metadata {
    param([string]$RawValue)

    if ([string]::IsNullOrWhiteSpace($RawValue)) {
        return $null
    }

    try {
        return $RawValue | ConvertFrom-Json
    } catch {
        return [pscustomobject]@{ raw = $RawValue }
    }
}

function Read-RecentEvents {
    param([int]$Take = 10)

    if (-not (Test-Path $eventsPath)) {
        return @()
    }

    $lines = Get-Content $eventsPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($lines.Count -eq 0) {
        return @()
    }

    $recent = $lines | Select-Object -Last $Take
    $events = New-Object System.Collections.Generic.List[object]
    foreach ($line in $recent) {
        try {
            [void]$events.Add(($line | ConvertFrom-Json))
        } catch {
        }
    }

    return $events.ToArray()
}

function Write-EventRecord {
    param(
        [string]$AgentName,
        [string]$EventCategory,
        [string]$StatusText,
        [string]$EventDescription,
        [string]$EventNotes,
        [object[]]$EventFiles,
        [string]$EventSource,
        [object]$Metadata
    )

    $normalizedFiles = @(Normalize-StringArray -Value $EventFiles)
    $record = [ordered]@{
        timestamp   = Get-Timestamp
        agent       = $AgentName
        category    = $EventCategory
        status      = $StatusText
        description = $EventDescription
        notes       = $EventNotes
        files       = [string[]]$normalizedFiles
        source      = $EventSource
        metadata    = $Metadata
    }

    Append-Utf8Line -Path $eventsPath -Line (($record | ConvertTo-Json -Depth 10 -Compress))
}

function Get-PersistentSnapshot {
    $controllerTasks = Try-ReadJsonFile -Path (Join-Path $persistentRoot "state\agent-tasks.json")
    $agentTasks = Try-ReadJsonFile -Path (Join-Path $persistentRoot "state\agent-project-tasks.json")
    $controllerState = Try-ReadJsonFile -Path (Join-Path $persistentRoot "state\controller-release-state.json")
    $agentState = Try-ReadJsonFile -Path (Join-Path $persistentRoot "state\agent-release-state.json")
    $geminiHomePath = Join-Path $HOME ".gemini\GEMINI.md"
    $globalGeminiConfigured = $false
    if (Test-Path $geminiHomePath) {
        $geminiHomeContent = Get-Content $geminiHomePath -Raw
        if ($null -eq $geminiHomeContent) {
            $geminiHomeContent = ""
        }

        $globalGeminiConfigured = -not [string]::IsNullOrWhiteSpace($geminiHomeContent.Trim())
    }

    return [pscustomobject]@{
        controllerTasks = $controllerTasks
        agentTasks = $agentTasks
        controllerState = $controllerState
        agentState = $agentState
        globalGeminiConfigured = $globalGeminiConfigured
        globalGeminiPath = $geminiHomePath
    }
}

function Update-AutoSummary {
    $state = Read-State
    $events = Read-RecentEvents -Take 10
    $snapshot = Get-PersistentSnapshot
    $activeTasks = Normalize-ObjectArray -Value $state.activeTasks
    $recentCompleted = Normalize-ObjectArray -Value $state.recentCompleted

    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add("# Automatic Shared Context")
    [void]$lines.Add("")
    [void]$lines.Add("Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm zzz')")
    [void]$lines.Add("")
    [void]$lines.Add("## Workspace Status")
    if ($activeTasks.Count -eq 0) {
        [void]$lines.Add("- Active tasks: none")
    } else {
        foreach ($task in $activeTasks) {
            [void]$lines.Add("- Active: $($task.claimedBy) | $($task.description) | $($task.claimedAt)")
        }
    }

    if ($recentCompleted.Count -eq 0) {
        [void]$lines.Add("- Recent completed: none")
    } else {
        foreach ($entry in ($recentCompleted | Select-Object -First 5)) {
            [void]$lines.Add("- Completed: $($entry.completedBy) | $($entry.description) | $($entry.completedAt)")
        }
    }

    [void]$lines.Add("")
    [void]$lines.Add("## Recent Agent Events")
    if ($events.Count -eq 0) {
        [void]$lines.Add("- No events recorded yet.")
    } else {
        foreach ($event in $events) {
            [void]$lines.Add("- $($event.timestamp) | $($event.agent) | $($event.category) | $($event.status) | $($event.description)")
        }
    }

    [void]$lines.Add("")
    [void]$lines.Add("## Persistent Autopilot Snapshot")
    if ($null -ne $snapshot.controllerTasks) {
        $controllerActiveCount = @(Normalize-ObjectArray -Value $snapshot.controllerTasks.activeTasks).Count
        [void]$lines.Add("- Controller registry: currentVersion=$($snapshot.controllerTasks.currentVersion) | activeTasks=$controllerActiveCount")
    } else {
        [void]$lines.Add("- Controller registry: unavailable")
    }

    if ($null -ne $snapshot.agentTasks) {
        $agentActiveCount = @(Normalize-ObjectArray -Value $snapshot.agentTasks.activeTasks).Count
        [void]$lines.Add("- Agent registry: currentVersion=$($snapshot.agentTasks.currentVersion) | activeTasks=$agentActiveCount")
    } else {
        [void]$lines.Add("- Agent registry: unavailable")
    }

    if ($null -ne $snapshot.controllerState) {
        [void]$lines.Add("- Controller release state: status=$($snapshot.controllerState.status)")
    }

    if ($null -ne $snapshot.agentState) {
        [void]$lines.Add("- Agent release state: status=$($snapshot.agentState.status)")
    }

    [void]$lines.Add("")
    [void]$lines.Add("## Bootstraps")
    [void]$lines.Add("- Workspace AGENTS: $(Test-Path (Join-Path $workspaceRoot 'AGENTS.md'))")
    [void]$lines.Add("- Workspace CLAUDE: $(Test-Path (Join-Path $workspaceRoot 'CLAUDE.md'))")
    [void]$lines.Add("- Workspace GEMINI: $(Test-Path (Join-Path $workspaceRoot 'GEMINI.md'))")
    [void]$lines.Add("- Global Gemini bootstrap configured: $($snapshot.globalGeminiConfigured)")
    [void]$lines.Add("- Global Gemini path: $($snapshot.globalGeminiPath)")

    Write-Utf8File -Path $autoPath -Content (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
}

function Invoke-EfficiencyMaintenance {
    $efficiencyScript = Join-Path $persistentRoot "autopilot-efficiency.ps1"
    if (-not (Test-Path $efficiencyScript)) {
        return
    }

    try {
        & $efficiencyScript -Mode opportunistic -Quiet | Out-Null
    } catch {
    }
}

switch ($Action) {
    "status" {
        $state = Read-State
        Write-Output ("Workspace: {0}" -f $state.workspace)
        Write-Output ("LastUpdated: {0}" -f $state.lastUpdated)

        $activeTasks = Normalize-ObjectArray -Value $state.activeTasks
        if ($activeTasks.Count -eq 0) {
            Write-Output "ActiveTasks: none"
        } else {
            Write-Output "ActiveTasks:"
            foreach ($task in $activeTasks) {
                Write-Output ("- {0} | {1} | {2}" -f $task.id, $task.claimedBy, $task.description)
            }
        }

        $recentCompleted = Normalize-ObjectArray -Value $state.recentCompleted
        if ($recentCompleted.Count -eq 0) {
            Write-Output "RecentCompleted: none"
        } else {
            Write-Output "RecentCompleted:"
            foreach ($entry in ($recentCompleted | Select-Object -First 5)) {
                Write-Output ("- {0} | {1} | {2}" -f $entry.completedAt, $entry.completedBy, $entry.description)
            }
        }
    }
    "claim" {
        Require-Value -Value $Agent -Name "Agent"
        Require-Value -Value $Description -Name "Description"

        $state = Read-State
        $activeTasks = Normalize-ObjectArray -Value $state.activeTasks
        if ($activeTasks.Count -gt 0) {
            $current = $activeTasks[0]
            throw "There is already an active task: $($current.id) claimed by $($current.claimedBy)"
        }

        $task = [pscustomobject]@{
            id             = New-TaskId -AgentName $Agent
            claimedAt      = Get-Timestamp
            claimedBy      = $Agent
            status         = "in_progress"
            description    = $Description
            estimatedFiles = Normalize-StringArray -Value $Files
        }

        $state.activeTasks = @($task)
        Write-State -State $state
        Write-EventRecord -AgentName $Agent -EventCategory "task_claimed" -StatusText "success" -EventDescription $Description -EventNotes $Notes -EventFiles $Files -EventSource $Source -Metadata (Parse-Metadata -RawValue $MetadataJson)
        Update-AutoSummary
        Invoke-EfficiencyMaintenance
        Write-Output ("Claimed: {0}" -f $task.id)
    }
    "complete" {
        $state = Read-State
        $activeTasks = Normalize-ObjectArray -Value $state.activeTasks

        $task = $null
        if (-not [string]::IsNullOrWhiteSpace($TaskId)) {
            $task = $activeTasks | Where-Object { $_.id -eq $TaskId } | Select-Object -First 1
        } elseif (-not [string]::IsNullOrWhiteSpace($Agent)) {
            $task = $activeTasks | Where-Object { $_.claimedBy -eq $Agent } | Select-Object -First 1
        } elseif ($activeTasks.Count -eq 1) {
            $task = $activeTasks[0]
        }

        if ($null -eq $task) {
            throw "Could not determine which active task to complete. Use -TaskId or -Agent."
        }

        $remaining = Normalize-ObjectArray -Value ($activeTasks | Where-Object { $_.id -ne $task.id })
        $descriptionValue = if ([string]::IsNullOrWhiteSpace($Description)) { $task.description } else { $Description }
        $filesValue = if ($Files.Count -gt 0) {
            Normalize-StringArray -Value $Files
        } else {
            Normalize-StringArray -Value $task.estimatedFiles
        }
        $completedBy = if ([string]::IsNullOrWhiteSpace($Agent)) { $task.claimedBy } else { $Agent }

        $completed = [pscustomobject]@{
            id            = $task.id
            completedAt   = Get-Timestamp
            completedBy   = $completedBy
            description   = $descriptionValue
            filesChanged  = $filesValue
            notes         = $Notes
        }

        $recentCompleted = Normalize-ObjectArray -Value $state.recentCompleted
        $state.activeTasks = $remaining
        $state.recentCompleted = @((@($completed) + $recentCompleted) | Select-Object -First 10)

        Write-State -State $state
        Write-EventRecord -AgentName $completedBy -EventCategory "task_completed" -StatusText "success" -EventDescription $descriptionValue -EventNotes $Notes -EventFiles $filesValue -EventSource $Source -Metadata (Parse-Metadata -RawValue $MetadataJson)
        Update-AutoSummary
        Invoke-EfficiencyMaintenance
        Write-Output ("Completed: {0}" -f $task.id)
    }
    "decision" {
        Require-Value -Value $Agent -Name "Agent"
        Require-Value -Value $Title -Name "Title"
        Require-Value -Value $Decision -Name "Decision"

        $block = @"
### $(Get-Date -Format "yyyy-MM-dd HH:mm zzz") | $Agent | $Title
- Decision: $Decision
- Rationale: $(if ([string]::IsNullOrWhiteSpace($Rationale)) { "(not provided)" } else { $Rationale })
- Notes: $(if ([string]::IsNullOrWhiteSpace($Notes)) { "(none)" } else { $Notes })
"@

        Append-MarkdownBlock -Path $decisionsPath -Block $block
        Write-EventRecord -AgentName $Agent -EventCategory "decision" -StatusText "recorded" -EventDescription $Title -EventNotes $Decision -EventFiles $Files -EventSource $Source -Metadata (Parse-Metadata -RawValue $MetadataJson)
        Update-AutoSummary
        Invoke-EfficiencyMaintenance
        Write-Output "Decision entry appended."
    }
    "learning" {
        Require-Value -Value $Agent -Name "Agent"
        Require-Value -Value $Title -Name "Title"
        Require-Value -Value $Context -Name "Context"
        Require-Value -Value $Problem -Name "Problem"
        Require-Value -Value $Solution -Name "Solution"
        Require-Value -Value $ReusablePattern -Name "ReusablePattern"

        $block = @"
### $(Get-Date -Format "yyyy-MM-dd HH:mm zzz") | $Agent | $Title
- Context: $Context
- Problem: $Problem
- Solution: $Solution
- ReusablePattern: $ReusablePattern
"@

        Append-MarkdownBlock -Path $learningsPath -Block $block
        Write-EventRecord -AgentName $Agent -EventCategory "learning" -StatusText "recorded" -EventDescription $Title -EventNotes $Solution -EventFiles $Files -EventSource $Source -Metadata (Parse-Metadata -RawValue $MetadataJson)
        Update-AutoSummary
        Invoke-EfficiencyMaintenance
        Write-Output "Learning entry appended."
    }
    "handoff" {
        Require-Value -Value $Agent -Name "Agent"
        Require-Value -Value $Description -Name "Description"

        $fileText = if ($Files.Count -eq 0) { "(none)" } else { (Normalize-StringArray -Value $Files) -join ", " }
        $block = @"
### $(Get-Date -Format "yyyy-MM-dd HH:mm zzz") | $Agent | $EntryStatus
- Summary: $Description
- Files: $fileText
- Notes: $(if ([string]::IsNullOrWhiteSpace($Notes)) { "(none)" } else { $Notes })
- NextStep: $(if ([string]::IsNullOrWhiteSpace($NextStep)) { "(none)" } else { $NextStep })
"@

        Append-MarkdownBlock -Path $handoffPath -Block $block
        Write-EventRecord -AgentName $Agent -EventCategory "handoff" -StatusText $EntryStatus -EventDescription $Description -EventNotes $Notes -EventFiles $Files -EventSource $Source -Metadata (Parse-Metadata -RawValue $MetadataJson)
        Update-AutoSummary
        Invoke-EfficiencyMaintenance
        Write-Output "Handoff entry appended."
    }
    "event" {
        Require-Value -Value $Agent -Name "Agent"
        Require-Value -Value $Description -Name "Description"

        Write-EventRecord -AgentName $Agent -EventCategory $Category -StatusText $EventStatus -EventDescription $Description -EventNotes $Notes -EventFiles $Files -EventSource $Source -Metadata (Parse-Metadata -RawValue $MetadataJson)
        Update-AutoSummary
        Invoke-EfficiencyMaintenance
        Write-Output "Event recorded."
    }
    "refresh-auto" {
        Update-AutoSummary
        Invoke-EfficiencyMaintenance
        Write-Output "Automatic summary refreshed."
    }
}
