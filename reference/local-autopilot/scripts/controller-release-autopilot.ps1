param(
  [string]$ConfigPath,
  [string]$Version,
  [string]$CommitMessage,
  [switch]$SkipMonitor,
  [switch]$SkipDeployUpdate
)

$ErrorActionPreference = "Stop"
$autopilotHome = if ($env:BB_DEVOPS_AUTOPILOT_HOME) {
  $env:BB_DEVOPS_AUTOPILOT_HOME
} else {
  Join-Path $env:LOCALAPPDATA "BBDevOpsAutopilot"
}

if (-not $ConfigPath) {
  $globalConfigPath = Join-Path $autopilotHome "controller-release-autopilot.json"
  $localConfigPath = Join-Path $PSScriptRoot "controller-release-autopilot.json"
  $ConfigPath = if (Test-Path $globalConfigPath) { $globalConfigPath } else { $localConfigPath }
}

$script:ControllerAuditSession = $null
$script:ControllerAuditSummary = [ordered]@{
  completionPoint = 'deploy_values_tag_update'
  configPath = $ConfigPath
  skipMonitor = [bool]$SkipMonitor
  skipDeployUpdate = [bool]$SkipDeployUpdate
}
$auditUtilsPath = Join-Path $PSScriptRoot 'audit-utils.ps1'
if (Test-Path $auditUtilsPath) {
  . $auditUtilsPath
}

function Set-ControllerAuditSummaryValue {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    $Value
  )

  if ($script:ControllerAuditSummary.Contains($Name)) {
    $script:ControllerAuditSummary[$Name] = $Value
  } else {
    $script:ControllerAuditSummary.Add($Name, $Value)
  }
}

function Update-ControllerAuditSummaryFromState {
  param([object]$State)

  if (-not $State) {
    return
  }

  $mapping = @{
    targetVersion = 'targetVersion'
    controllerCommit = 'controllerCommit'
    stateStatus = 'status'
    workflowRunId = 'workflowRunId'
    githubActionsReportDir = 'failureReportDir'
  }

  foreach ($summaryName in $mapping.Keys) {
    $stateName = $mapping[$summaryName]
    if ($State.PSObject.Properties.Name -contains $stateName) {
      Set-ControllerAuditSummaryValue -Name $summaryName -Value $State.$stateName
    }
  }
}

function Write-ControllerAuditEvent {
  param(
    [Parameter(Mandatory = $true)][string]$Event,
    [string]$Level = 'info',
    [string]$Message = '',
    [object]$Data
  )

  if ($script:ControllerAuditSession -and (Get-Command Write-AutopilotAuditEvent -ErrorAction SilentlyContinue)) {
    Write-AutopilotAuditEvent -Session $script:ControllerAuditSession -Event $Event -Level $Level -Message $Message -Data $Data | Out-Null
  }
}

function Save-ControllerAuditArtifact {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [object]$Content,
    [ValidateSet('json','text')][string]$Format = 'json',
    [string]$SourcePath
  )

  if ($script:ControllerAuditSession -and (Get-Command Save-AutopilotAuditArtifact -ErrorAction SilentlyContinue)) {
    Save-AutopilotAuditArtifact -Session $script:ControllerAuditSession -Name $Name -Content $Content -Format $Format -SourcePath $SourcePath | Out-Null
  }
}

function Complete-ControllerAuditSession {
  param(
    [Parameter(Mandatory = $true)][string]$Status,
    [string]$Message
  )

  if ($script:ControllerAuditSession -and (Get-Command Complete-AutopilotAuditSession -ErrorAction SilentlyContinue)) {
    Complete-AutopilotAuditSession -Session $script:ControllerAuditSession -Status $Status -Summary ([pscustomobject]$script:ControllerAuditSummary) -Message $Message
  }
}

function Exit-ControllerReleaseSuccess {
  param([string]$Message)

  Complete-ControllerAuditSession -Status 'success' -Message $Message
  if ($script:ControllerAuditSummary.targetVersion -and $script:ControllerAuditSummary.controllerCommit) {
    Write-Host ""
    Write-Host "Controller version published: $($script:ControllerAuditSummary.targetVersion)"
    Write-Host "Controller commit: $($script:ControllerAuditSummary.controllerCommit)"
  }
  exit 0
}

function Write-Step {
  param([string]$Message)
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Resolve-AbsolutePath {
  param(
    [string]$BasePath,
    [string]$PathValue
  )

  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return $PathValue
  }

  return [System.IO.Path]::GetFullPath((Join-Path $BasePath $PathValue))
}

function Resolve-Executable {
  param([string]$Command)

  # Use Get-Command to find it in PATH, which is the most reliable method.
  $found = Get-Command $Command -ErrorAction SilentlyContinue
  if ($found) {
    return $found.Source
  }

  # As a fallback for broken PATH environments, check common default installation locations.
  $fallbacks = @{
    "git"     = @(
        "C:\Program Files\Git\cmd\git.exe",
        "C:\Program Files (x86)\Git\cmd\git.exe"
    )
    "npm.cmd" = @(
        "C:\Program Files\nodejs\npm.cmd",
        "C:\Program Files (x86)\nodejs\npm.cmd"
    )
  }
  if ($fallbacks.ContainsKey($Command)) {
    foreach($path in $fallbacks[$Command]) {
        if (Test-Path $path) {
            Write-Host "Warning: Command '$Command' not found in PATH, using fallback location '$path'" -ForegroundColor Yellow
            return $path
        }
    }
  }

  # If it's still not found, the operation cannot proceed.
  throw "Could not find executable '$Command'. Please ensure it is in your system's PATH or the fallback path in Resolve-Executable is correct."
}

function Ensure-ParentDirectory {
  param([string]$FilePath)
  $directory = Split-Path -Parent $FilePath
  if ($directory) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
}

function Invoke-Git {
  param(
    [string]$RepoPath,
    [string[]]$Arguments
  )

  $stdoutPath = [System.IO.Path]::GetTempFileName()
  $stderrPath = [System.IO.Path]::GetTempFileName()
  $gitPath = Resolve-Executable -Command "git"
  try {
    $process = Start-Process -FilePath $gitPath -ArgumentList (@("-C", $RepoPath) + $Arguments) -Wait -NoNewWindow -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $stdout = if (Test-Path $stdoutPath) { Get-Content -Raw -Path $stdoutPath } else { "" }
    $stderr = if (Test-Path $stderrPath) { Get-Content -Raw -Path $stderrPath } else { "" }
    $combined = [string]::Concat($stdout, $stderr).Trim()
    if ($process.ExitCode -ne 0) {
      throw "git $($Arguments -join ' ') failed.`n$combined"
    }
    return $combined
  } finally {
    Remove-Item -Path $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
  }
}

function Ensure-GitIdentity {
  param(
    [string]$RepoPath,
    [object]$GitConfig
  )

  if ($GitConfig.userName) {
    Invoke-Git -RepoPath $RepoPath -Arguments @("config", "user.name", $GitConfig.userName) | Out-Null
  }
  if ($GitConfig.userEmail) {
    Invoke-Git -RepoPath $RepoPath -Arguments @("config", "user.email", $GitConfig.userEmail) | Out-Null
  }
}

function Invoke-ProcessChecked {
  param(
    [string]$FilePath,
    [string[]]$ArgumentList,
    [string]$WorkingDirectory
  )

  $executablePath = Resolve-Executable -Command $FilePath
  $process = Start-Process -FilePath $executablePath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory -Wait -NoNewWindow -PassThru
  if ($process.ExitCode -ne 0) {
    throw "$FilePath $($ArgumentList -join ' ') failed with exit code $($process.ExitCode)."
  }
}

function Get-NextPatchVersion {
  param([string]$CurrentVersion)

  if ($CurrentVersion -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
    throw "Unsupported semantic version: $CurrentVersion"
  }

  return "{0}.{1}.{2}" -f $matches[1], $matches[2], ([int]$matches[3] + 1)
}

function Get-ControllerBaseVersion {
  param(
    [string]$RepoPath,
    [string]$Branch,
    [string]$PackageJsonPath
  )

  $packageJson = Invoke-Git -RepoPath $RepoPath -Arguments @("show", "origin/$Branch`:$PackageJsonPath")
  return ((ConvertFrom-Json -InputObject $packageJson).version)
}

function Set-JsonFile {
  param(
    [string]$FilePath,
    [object]$Content
  )

  $json = $Content | ConvertTo-Json -Depth 100
  Ensure-ParentDirectory -FilePath $FilePath
  [System.IO.File]::WriteAllText($FilePath, $json + [Environment]::NewLine)
}

function Get-FileSha256 {
  param([string]$FilePath)
  $hash = Get-FileHash -Algorithm SHA256 -Path $FilePath
  return $hash.Hash.ToLowerInvariant()
}

function Update-ControllerVersionFiles {
  param(
    [string]$RepoPath,
    [object]$ControllerConfig,
    [string]$TargetVersion
  )

  $packageJsonPath = Join-Path $RepoPath $ControllerConfig.packageJsonPath
  $swaggerJsonPath = Join-Path $RepoPath $ControllerConfig.swaggerJsonPath

  $package = Get-Content -Raw -Path $packageJsonPath | ConvertFrom-Json
  if ($package.version -ne $TargetVersion) {
    $package.version = $TargetVersion
    Set-JsonFile -FilePath $packageJsonPath -Content $package

    $lockPath = Join-Path $RepoPath $ControllerConfig.packageLockJsonPath
    if (Test-Path $lockPath) {
      $lines = [System.Collections.Generic.List[string]]([System.IO.File]::ReadAllLines($lockPath, [System.Text.Encoding]::UTF8))
      foreach ($idx in @(2, 8)) {
        if ($lines[$idx] -match '"version":') {
          $lines[$idx] = $lines[$idx] -replace '"version": "[^"]+"', "`"version`": `"$TargetVersion`""
        }
      }
      [System.IO.File]::WriteAllLines($lockPath, $lines, [System.Text.Encoding]::UTF8)
    }
  }

  if (Test-Path $swaggerJsonPath) {
    $swagger = Get-Content -Raw -Path $swaggerJsonPath | ConvertFrom-Json
    if ($swagger.info) {
      $swagger.info.version = $TargetVersion
      Set-JsonFile -FilePath $swaggerJsonPath -Content $swagger
    }
  }
}

function Test-ExcludedPath {
  param(
    [string]$PathValue,
    [string[]]$ExcludePaths
  )

  $normalized = $PathValue.Replace("/", "\\")
  foreach ($exclude in $ExcludePaths) {
    $normalizedExclude = $exclude.Replace("/", "\\")
    if ($normalized.StartsWith($normalizedExclude, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
    if ($normalized -eq $normalizedExclude) {
      return $true
    }
  }
  return $false
}

function Get-WorkingTreeEntries {
  param(
    [string]$RepoPath,
    [string[]]$ExcludePaths
  )

  $raw = Invoke-Git -RepoPath $RepoPath -Arguments @("status", "--porcelain=v1", "--untracked-files=all")
  if (-not $raw) {
    return @()
  }

  $entries = @()
  foreach ($line in ($raw -split "`r?`n")) {
    if (-not $line) {
      continue
    }

    $status = $line.Substring(0, 2)
    $payload = $line.Substring(3)

    if ($payload -like "* -> *") {
      $parts = $payload -split " -> ", 2
      $oldPath = $parts[0]
      $newPath = $parts[1]
      if ((Test-ExcludedPath -PathValue $oldPath -ExcludePaths $ExcludePaths) -and
          (Test-ExcludedPath -PathValue $newPath -ExcludePaths $ExcludePaths)) {
        continue
      }
      $entries += [pscustomobject]@{
        Kind = "rename"
        OldPath = $oldPath
        Path = $newPath
        Status = $status
      }
      continue
    }

    if (Test-ExcludedPath -PathValue $payload -ExcludePaths $ExcludePaths) {
      continue
    }

    $kind = if ($status.Contains("D")) { "delete" } else { "add" }
    $entries += [pscustomobject]@{
      Kind = $kind
      OldPath = $null
      Path = $payload
      Status = $status
    }
  }

  return $entries
}

function Get-ChangeFingerprint {
  param(
    [string]$RepoPath,
    [object[]]$Entries
  )

  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($entry in ($Entries | Sort-Object Kind, OldPath, Path, Status)) {
    $prefix = "$($entry.Kind)|$($entry.Status)|$($entry.OldPath)|$($entry.Path)"
    if ($entry.Kind -eq "delete") {
      $lines.Add($prefix)
      continue
    }

    $filePath = Join-Path $RepoPath $entry.Path
    if (Test-Path $filePath) {
      $lines.Add("$prefix|$(Get-FileSha256 -FilePath $filePath)")
    } else {
      $lines.Add($prefix)
    }
  }

  if ($lines.Count -eq 0) {
    return ""
  }

  $joined = [string]::Join("`n", $lines)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
  $memory = New-Object System.IO.MemoryStream(,$bytes)
  try {
    return (Get-FileHash -Algorithm SHA256 -InputStream $memory).Hash.ToLowerInvariant()
  } finally {
    $memory.Dispose()
  }
}

function Load-State {
  param([string]$StateFilePath)
  if (-not (Test-Path $StateFilePath)) {
    return $null
  }
  return Get-Content -Raw -Path $StateFilePath | ConvertFrom-Json
}

function Save-State {
  param(
    [string]$StateFilePath,
    [object]$State
  )
  Set-JsonFile -FilePath $StateFilePath -Content $State
  Update-ControllerAuditSummaryFromState -State $State
  Write-ControllerAuditEvent -Event 'state_saved' -Message 'Release state persisted.' -Data @{
    path = $StateFilePath
    status = if ($State.PSObject.Properties.Name -contains 'status') { $State.status } else { $null }
    targetVersion = if ($State.PSObject.Properties.Name -contains 'targetVersion') { $State.targetVersion } else { $null }
    controllerCommit = if ($State.PSObject.Properties.Name -contains 'controllerCommit') { $State.controllerCommit } else { $null }
  }
  Save-ControllerAuditArtifact -Name 'state-current.json' -Content $State
}

function Set-StateProperty {
  param(
    [object]$State,
    [string]$Name,
    $Value
  )

  if ($State.PSObject.Properties.Name -contains $Name) {
    $State.$Name = $Value
  } else {
    $State | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  }
}

function Get-GitHubToken {
  param(
    [object]$PathsConfig,
    [string]$ConfigBasePath
  )

  $token = $env:GITHUB_TOKEN
  if (-not $token) {
    $token = $env:GH_TOKEN
  }
  if (-not $token) {
    $workspaceTokenPath = Resolve-AbsolutePath -BasePath $ConfigBasePath -PathValue $PathsConfig.workspaceGitHubTokenPath
    if (Test-Path $workspaceTokenPath) {
      $encrypted = (Get-Content -Raw -Path $workspaceTokenPath).Trim()
      if ($encrypted) {
        $secure = ConvertTo-SecureString -String $encrypted
        $token = [System.Net.NetworkCredential]::new("", $secure).Password
      }
    }
  }
  if (-not $token) {
    throw "Set GITHUB_TOKEN, GH_TOKEN or save the encrypted token before running the autopilot."
  }
  return $token
}

function Invoke-GitHubJson {
  param(
    [string]$Token,
    [string]$Uri
  )

  $headers = @{
    Authorization = "Bearer $Token"
    Accept = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent" = "controller-release-autopilot"
  }

  return Invoke-RestMethod -Headers $headers -Uri $Uri -Method Get
}

function Get-GitLabToken {
  param(
    [object]$PathsConfig,
    [string]$ConfigBasePath
  )

  $token = $env:GITLAB_TOKEN
  if (-not $token) { $token = $env:CI_JOB_TOKEN }
  if (-not $token) {
    $tokenPath = if ($PathsConfig.workspaceGitLabTokenPath) { $PathsConfig.workspaceGitLabTokenPath } elseif ($PathsConfig.workspaceVcsTokenPath) { $PathsConfig.workspaceVcsTokenPath } else { $PathsConfig.workspaceGitHubTokenPath }
    if ($tokenPath) {
      $absPath = Resolve-AbsolutePath -BasePath $ConfigBasePath -PathValue $tokenPath
      if (Test-Path $absPath) {
        $encrypted = (Get-Content -Raw -Path $absPath).Trim()
        if ($encrypted) {
          $secure = ConvertTo-SecureString -String $encrypted
          $token = [System.Net.NetworkCredential]::new("", $secure).Password
        }
      }
    }
  }
  if (-not $token) {
    throw "Set GITLAB_TOKEN or save the encrypted token at workspaceVcsTokenPath before running the autopilot."
  }
  return $token
}

function Get-CiToken {
  param(
    [object]$Config,
    [object]$PathsConfig,
    [string]$ConfigBasePath
  )

  if ($Config.ciProvider -eq "gitlab") {
    return Get-GitLabToken -PathsConfig $PathsConfig -ConfigBasePath $ConfigBasePath
  }
  return Get-GitHubToken -PathsConfig $PathsConfig -ConfigBasePath $ConfigBasePath
}

function Invoke-GitLabJson {
  param(
    [string]$Token,
    [string]$Uri
  )

  $headers = @{
    "PRIVATE-TOKEN" = $Token
    "User-Agent" = "controller-release-autopilot"
  }

  return Invoke-RestMethod -Headers $headers -Uri $Uri -Method Get
}

function Save-GitLabPipelineDiagnostics {
  param(
    [string]$Token,
    [string]$GitLabBaseUrl,
    [string]$ProjectPath,
    [int64]$PipelineId,
    [string]$ReportBaseDir
  )

  New-Item -ItemType Directory -Force -Path $ReportBaseDir | Out-Null
  $encodedPath = [uri]::EscapeDataString($ProjectPath)

  $jobsUri = "$GitLabBaseUrl/api/v4/projects/$encodedPath/pipelines/$PipelineId/jobs?per_page=100"
  $jobs = Invoke-GitLabJson -Token $Token -Uri $jobsUri
  $jobs | ConvertTo-Json -Depth 100 | Set-Content -Path (Join-Path $ReportBaseDir "jobs.json")

  $summaryLines = New-Object System.Collections.Generic.List[string]
  foreach ($job in $jobs) {
    if ($job.status -ne "success") {
      $summaryLines.Add("JOB: $($job.name) [$($job.status)]")
    }
  }
  if ($summaryLines.Count -eq 0) {
    $summaryLines.Add("No failed jobs returned by GitLab API.")
  }
  $summaryLines | Set-Content -Path (Join-Path $ReportBaseDir "summary.txt")
}

function Wait-GitLabPipeline {
  param(
    [string]$Token,
    [string]$GitLabBaseUrl,
    [string]$ProjectPath,
    [string]$HeadSha,
    [object]$ActionsConfig,
    [string]$ReportBaseDir
  )

  $encodedPath = [uri]::EscapeDataString($ProjectPath)
  $pipeline = $null
  $deadline = (Get-Date).AddSeconds($ActionsConfig.appearTimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $pipelinesUri = "$GitLabBaseUrl/api/v4/projects/$encodedPath/pipelines?sha=$HeadSha&per_page=5"
    $pipelines = Invoke-GitLabJson -Token $Token -Uri $pipelinesUri
    $pipeline = $pipelines | Select-Object -First 1
    if ($pipeline) { break }
    Start-Sleep -Seconds $ActionsConfig.pollIntervalSeconds
  }

  if (-not $pipeline) {
    throw "No GitLab CI pipeline was found for commit $HeadSha."
  }

  $pipelineUrl = "$GitLabBaseUrl/$ProjectPath/-/pipelines/$($pipeline.id)"
  Write-Host "Pipeline URL: $pipelineUrl"

  $completeDeadline = (Get-Date).AddSeconds($ActionsConfig.completionTimeoutSeconds)
  $startTime = Get-Date
  while ((Get-Date) -lt $completeDeadline) {
    $pipelineUri = "$GitLabBaseUrl/api/v4/projects/$encodedPath/pipelines/$($pipeline.id)"
    $pipeline = Invoke-GitLabJson -Token $Token -Uri $pipelineUri
    $elapsed = (Get-Date) - $startTime
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Pipeline status: $($pipeline.status) (Tempo decorrido: $([math]::Round($elapsed.TotalMinutes, 1)) min)"

    $monitorData = [pscustomobject]@{
      lastCheck      = (Get-Date).ToString("o")
      elapsedMinutes = [math]::Round($elapsed.TotalMinutes, 1)
      runId          = $pipeline.id
      status         = $pipeline.status
      conclusion     = $pipeline.status
      url            = $pipelineUrl
    }
    $monitorData | ConvertTo-Json | Set-Content -Path (Join-Path (Split-Path -Parent $ReportBaseDir) "live-monitor.json") -Encoding UTF8

    if ($pipeline.status -in @("success", "failed", "canceled", "skipped")) { break }
    Start-Sleep -Seconds $ActionsConfig.pollIntervalSeconds
  }

  if ($pipeline.status -notin @("success", "failed", "canceled", "skipped")) {
    throw "GitLab CI pipeline $($pipeline.id) timed out before completion."
  }

  if ($pipeline.status -ne "success") {
    Save-GitLabPipelineDiagnostics -Token $Token -GitLabBaseUrl $GitLabBaseUrl -ProjectPath $ProjectPath -PipelineId $pipeline.id -ReportBaseDir $ReportBaseDir
    throw "GitLab CI pipeline failed with status '$($pipeline.status)'. Diagnostics saved in $ReportBaseDir."
  }

  return [pscustomobject]@{
    id         = $pipeline.id
    status     = "completed"
    conclusion = "success"
    html_url   = $pipelineUrl
  }
}

function Wait-CiRun {
  param(
    [string]$Token,
    [object]$Config,
    [string]$HeadSha,
    [object]$ActionsConfig,
    [string]$ReportBaseDir
  )

  if ($Config.ciProvider -eq "gitlab") {
    $gitlabBase = if ($Config.gitlabBaseUrl) { $Config.gitlabBaseUrl } else { "<PRIVATE_INTERNAL_URL>" }
    $projectPath = "$($Config.controller.owner)/$($Config.controller.repo)"
    return Wait-GitLabPipeline -Token $Token -GitLabBaseUrl $gitlabBase -ProjectPath $projectPath -HeadSha $HeadSha -ActionsConfig $ActionsConfig -ReportBaseDir $ReportBaseDir
  }

  return Wait-WorkflowRun -Token $Token -Owner $Config.controller.owner -Repo $Config.controller.repo -HeadSha $HeadSha -ActionsConfig $ActionsConfig -ReportBaseDir $ReportBaseDir
}

function Save-RunDiagnostics {
  param(
    [string]$Token,
    [string]$Owner,
    [string]$Repo,
    [int64]$RunId,
    [string]$ReportBaseDir
  )

  New-Item -ItemType Directory -Force -Path $ReportBaseDir | Out-Null

  $jobsUri = "https://api.github.com/repos/$Owner/$Repo/actions/runs/$RunId/jobs?per_page=100"
  $jobs = Invoke-GitHubJson -Token $Token -Uri $jobsUri
  $jobsPath = Join-Path $ReportBaseDir "jobs.json"
  $jobs | ConvertTo-Json -Depth 100 | Set-Content -Path $jobsPath

  $summaryLines = New-Object System.Collections.Generic.List[string]
  foreach ($job in $jobs.jobs) {
    if ($job.conclusion -ne "success") {
      $summaryLines.Add("JOB: $($job.name) [$($job.conclusion)]")
      foreach ($step in $job.steps) {
        if ($step.conclusion -and $step.conclusion -ne "success") {
          $summaryLines.Add("  STEP: $($step.name) [$($step.conclusion)]")
        }
      }
    }
  }

  $summaryPath = Join-Path $ReportBaseDir "summary.txt"
  if ($summaryLines.Count -eq 0) {
    $summaryLines.Add("No failed jobs were returned by the Actions API.")
  }
  $summaryLines | Set-Content -Path $summaryPath

  $headers = @{
    Authorization = "Bearer $Token"
    Accept = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent" = "controller-release-autopilot"
  }

  $logsZip = Join-Path $ReportBaseDir "logs.zip"
  $logsDir = Join-Path $ReportBaseDir "logs"
  $logsUri = "https://api.github.com/repos/$Owner/$Repo/actions/runs/$RunId/logs"
  Invoke-WebRequest -Headers $headers -Uri $logsUri -OutFile $logsZip | Out-Null
  if (Test-Path $logsDir) {
    Remove-Item -Recurse -Force $logsDir
  }
  Expand-Archive -Path $logsZip -DestinationPath $logsDir -Force
}

function Wait-WorkflowRun {
  param(
    [string]$Token,
    [string]$Owner,
    [string]$Repo,
    [string]$HeadSha,
    [object]$ActionsConfig,
    [string]$ReportBaseDir
  )

  $run = $null
  $deadline = (Get-Date).AddSeconds($ActionsConfig.appearTimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $runsUri = "https://api.github.com/repos/$Owner/$Repo/actions/runs?per_page=20&head_sha=$HeadSha"
    $result = Invoke-GitHubJson -Token $Token -Uri $runsUri
    $run = $result.workflow_runs | Select-Object -First 1
    if ($run) {
      break
    }
    Start-Sleep -Seconds $ActionsConfig.pollIntervalSeconds
  }

  if (-not $run) {
    throw "No GitHub Actions run was found for commit $HeadSha."
  }

  Write-Host "Run URL: $($run.html_url)"

  $completeDeadline = (Get-Date).AddSeconds($ActionsConfig.completionTimeoutSeconds)
  $startTime = Get-Date
  while ((Get-Date) -lt $completeDeadline) {
    $runUri = "https://api.github.com/repos/$Owner/$Repo/actions/runs/$($run.id)"
    $run = Invoke-GitHubJson -Token $Token -Uri $runUri
    $elapsed = (Get-Date) - $startTime
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Workflow status: $($run.status) / $($run.conclusion) (Tempo decorrido: $([math]::Round($elapsed.TotalMinutes, 1)) min)"
    
    # Cria um heartbeat para que os Agentes (Gemini/Claude/Codex) possam ler o status em tempo real
    $monitorData = [pscustomobject]@{
      lastCheck = (Get-Date).ToString("o")
      elapsedMinutes = [math]::Round($elapsed.TotalMinutes, 1)
      runId = $run.id
      status = $run.status
      conclusion = $run.conclusion
      url = $run.html_url
    }
    $monitorData | ConvertTo-Json | Set-Content -Path (Join-Path (Split-Path -Parent $ReportBaseDir) "live-monitor.json") -Encoding UTF8

    if ($run.status -eq "completed") {
      break
    }
    Start-Sleep -Seconds $ActionsConfig.pollIntervalSeconds
  }

  if ($run.status -ne "completed") {
    throw "GitHub Actions run $($run.id) timed out before completion."
  }

  if ($run.conclusion -ne "success") {
    Save-RunDiagnostics -Token $Token -Owner $Owner -Repo $Repo -RunId $run.id -ReportBaseDir $ReportBaseDir
    throw "GitHub Actions run failed with conclusion '$($run.conclusion)'. Diagnostics saved in $ReportBaseDir."
  }

  return $run
}

function Set-DeployValuesTag {
  param(
    [string]$FilePath,
    [string]$Version,
    [string]$UpdateMode = "tag",
    [string]$ImageRegistryPrefix = ""
  )

  $lines = [System.Collections.Generic.List[string]](Get-Content -Path $FilePath)

  # Mode: image-line â€” updates "image: <registry>/<repo>:OLD" â†’ ":NEW"
  if ($UpdateMode -eq "image-line") {
    if (-not $ImageRegistryPrefix) {
      throw "imageRegistryPrefix is required when imageUpdateMode is 'image-line'."
    }
    $escaped = [regex]::Escape($ImageRegistryPrefix)
    $pattern = "^(\s*image:\s*$escaped):.*$"
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match $pattern) {
        $lines[$i] = ($lines[$i] -replace "$escaped:.*", "$ImageRegistryPrefix`:$Version")
        Set-Content -Path $FilePath -Value $lines
        return
      }
    }
    throw "Could not find image line matching '$ImageRegistryPrefix' in $FilePath."
  }

  # Mode: tag (default) â€” updates deployment.containers.tag: "OLD"
  $insideDeployment = $false
  $insideContainers = $false

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    if ($line -match '^\s{2}deployment:\s*$') {
      $insideDeployment = $true
      $insideContainers = $false
      continue
    }

    if ($insideDeployment -and $line -match '^\s{4}containers:\s*$') {
      $insideContainers = $true
      continue
    }

    if ($insideContainers -and $line -match '^\s{6}tag:\s*".*"\s*$') {
      $lines[$i] = '      tag: "' + $Version + '"'
      Set-Content -Path $FilePath -Value $lines
      return
    }

    if ($insideDeployment -and $line -match '^\s{2}[A-Za-z]') {
      $insideDeployment = $false
      $insideContainers = $false
    }
  }

  throw "Could not find deployment.containers.tag in $FilePath."
}

function Update-DeployRepository {
  param(
    [object]$DeployConfig,
    [object]$PathsConfig,
    [object]$GitConfig,
    [string]$Version,
    [string]$ConfigBasePath,
    [string]$Token = ""
  )

  $cacheRoot = Resolve-AbsolutePath -BasePath $ConfigBasePath -PathValue $PathsConfig.cacheDir
  if ($DeployConfig.repoPath) {
    $repoPath = Resolve-AbsolutePath -BasePath $ConfigBasePath -PathValue $DeployConfig.repoPath
  } else {
    $repoPath = Join-Path $cacheRoot "deploy-psc-sre-automacao-controller"
  }
  Set-ControllerAuditSummaryValue -Name 'deployRepoPath' -Value $repoPath

  New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null

  # Build authenticated URL if token is provided
  $cloneUrl = $DeployConfig.repoUrl
  if ($Token) {
    $uri = [System.Uri]$DeployConfig.repoUrl
    $cloneUrl = "$($uri.Scheme)://x-token:$Token@$($uri.Host)$($uri.PathAndQuery)"
  }

  if (-not (Test-Path (Join-Path $repoPath ".git"))) {
    Write-Step "Cloning deploy repository"
    $cloneProcess = Start-Process -FilePath (Resolve-Executable -Command "git") -ArgumentList @("-C", $cacheRoot, "clone", $cloneUrl, $repoPath) -Wait -NoNewWindow -PassThru
    if ($cloneProcess.ExitCode -ne 0) {
      throw "Failed to clone deploy repository into $repoPath"
    }
  }

  Ensure-GitIdentity -RepoPath $repoPath -GitConfig $GitConfig

  # Inject token into remote URL for fetch/push if provided
  if ($Token) {
    Invoke-Git -RepoPath $repoPath -Arguments @("remote", "set-url", "origin", $cloneUrl) | Out-Null
  }

  Write-Step "Updating deploy repository branch $($DeployConfig.branch)"
  Invoke-Git -RepoPath $repoPath -Arguments @("fetch", "origin", $DeployConfig.branch) | Out-Null
  Invoke-Git -RepoPath $repoPath -Arguments @("checkout", "-B", $DeployConfig.branch, "origin/$($DeployConfig.branch)") | Out-Null
  Invoke-Git -RepoPath $repoPath -Arguments @("reset", "--hard", "origin/$($DeployConfig.branch)") | Out-Null
  Invoke-Git -RepoPath $repoPath -Arguments @("clean", "-fd") | Out-Null

  $valuesPath = Join-Path $repoPath $DeployConfig.valuesPath
  $updateMode = if ($DeployConfig.imageUpdateMode) { $DeployConfig.imageUpdateMode } else { "tag" }
  $imagePrefix = if ($DeployConfig.imageRegistryPrefix) { $DeployConfig.imageRegistryPrefix } else { "" }
  Set-DeployValuesTag -FilePath $valuesPath -Version $Version -UpdateMode $updateMode -ImageRegistryPrefix $imagePrefix

  Invoke-Git -RepoPath $repoPath -Arguments @("add", "--", $DeployConfig.valuesPath) | Out-Null
  $status = Invoke-Git -RepoPath $repoPath -Arguments @("status", "--short")
  if (-not $status) {
    Write-Step "Deploy repository already points to version $Version"
    return
  }

  $repoName = if ($DeployConfig.repoUrl) { [System.IO.Path]::GetFileNameWithoutExtension($DeployConfig.repoUrl.Split('/')[-1]) } else { "psc-sre-automacao-controller" }
  $message = "chore(release): promote $repoName to $Version"
  $commitMessageFile = [System.IO.Path]::GetTempFileName()
  try {
    Set-Content -Path $commitMessageFile -Value $message -NoNewline
    Invoke-Git -RepoPath $repoPath -Arguments @("commit", "-F", $commitMessageFile) | Out-Null
  } finally {
    Remove-Item -Path $commitMessageFile -Force -ErrorAction SilentlyContinue
  }
  Invoke-Git -RepoPath $repoPath -Arguments @("push", "origin", "HEAD:$($DeployConfig.branch)") | Out-Null
  Write-ControllerAuditEvent -Event 'deploy_repo_updated' -Message 'Deploy repository values.yaml tag was committed and pushed.' -Data @{
    repoPath = $repoPath
    branch = $DeployConfig.branch
    valuesPath = $DeployConfig.valuesPath
    version = $Version
  }
}

function Sync-AgentTasksJson {
  param(
    [string]$AgentTasksPath,
    [string]$Version,
    [string]$CommitSha,
    [long]$CiRunId
  )

  if (-not (Test-Path $AgentTasksPath)) {
    Write-Step "agent-tasks.json not found at $AgentTasksPath â€” skipping sync."
    return
  }

  try {
    $raw = Get-Content -Raw -Path $AgentTasksPath | ConvertFrom-Json
  } catch {
    Write-Step "Warning: could not parse agent-tasks.json â€” skipping sync. Error: $($_.Exception.Message)"
    return
  }

  $shortSha = if ($CommitSha.Length -ge 7) { $CommitSha.Substring(0, 7) } else { $CommitSha }
  $now = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')

  # Update top-level version fields
  $raw.currentVersion = $Version
  $raw.currentCommit  = $shortSha
  $raw.deployedTag    = $Version

  # Clear active tasks
  $raw.activeTasks = @()

  # Build new completed entry
  $newEntry = [pscustomobject]@{
    id                 = "task-$(Get-Date -Format 'yyyyMMdd')-autopilot"
    completedAt        = $now
    completedBy        = "controller-release-autopilot"
    version            = $Version
    commitSha          = $shortSha
    description        = "Release automatizado pelo controller-release-autopilot.ps1"
    filesChanged       = @()
    ciRunId            = $CiRunId
    ciConclusion       = "success"
    valuesYamlPromoted = $true
  }

  # Prepend new entry and keep only the 5 most recent
  $existing = if ($raw.recentCompleted) { @($raw.recentCompleted) } else { @() }
  $updated = @($newEntry) + $existing | Select-Object -First 5
  $raw.recentCompleted = $updated

  $raw | ConvertTo-Json -Depth 10 | Set-Content -Path $AgentTasksPath -Encoding UTF8 -NoNewline
  Write-Step "agent-tasks.json synced: version=$Version commit=$shortSha"
}

function Complete-DeployPromotion {
  param(
    [object]$Config,
    [string]$ConfigBasePath,
    [object]$State,
    [string]$Version,
    [string]$StateFilePath
  )

  Write-Step "Updating deploy repository to version $Version on $($Config.deploy.branch)"
  Update-DeployRepository -DeployConfig $Config.deploy -PathsConfig $Config.paths -GitConfig $Config.git -Version $Version -ConfigBasePath $ConfigBasePath
  if ($Config.PSObject.Properties.Name -contains 'deployCap' -and $Config.deployCap) {
    Write-Step "Updating GitLab CAP repository to version $Version on $($Config.deployCap.branch)"
    $gitLabToken = Get-GitLabToken -PathsConfig $Config.paths -ConfigBasePath $ConfigBasePath
    Update-DeployRepository -DeployConfig $Config.deployCap -PathsConfig $Config.paths -GitConfig $Config.git -Version $Version -ConfigBasePath $ConfigBasePath -Token $gitLabToken
  }
  $State.status = "deploy_updated"
  $State.updatedAt = (Get-Date).ToString("o")
  Set-StateProperty -State $State -Name "argocdBlockedReason" -Value $null
  Save-State -StateFilePath $StateFilePath -State $State

  $agentTasksPath = if ($Config.paths.PSObject.Properties.Name -contains 'agentTasksRegistry') {
    Resolve-AbsolutePath -BasePath $ConfigBasePath -PathValue $Config.paths.agentTasksRegistry
  } else {
    Join-Path (Split-Path -Parent $StateFilePath) 'agent-tasks.json'
  }
  $ciRunId = if ($State.PSObject.Properties.Name -contains 'workflowRunId') { [long]$State.workflowRunId } else { 0 }
  Sync-AgentTasksJson -AgentTasksPath $agentTasksPath -Version $Version -CommitSha $State.controllerCommit -CiRunId $ciRunId

  Write-Step "Deploy promotion finished at values.yaml update."
}

$configBase = Split-Path -Parent $ConfigPath
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$controllerRepoPath = Resolve-AbsolutePath -BasePath $configBase -PathValue $config.controller.repoPath
$stateFilePath = Resolve-AbsolutePath -BasePath $configBase -PathValue $config.paths.stateFilePath
$lockFilePath = Resolve-AbsolutePath -BasePath $configBase -PathValue $config.paths.lockFilePath
Set-ControllerAuditSummaryValue -Name 'controllerRepoPath' -Value $controllerRepoPath
Set-ControllerAuditSummaryValue -Name 'stateFilePath' -Value $stateFilePath
Set-ControllerAuditSummaryValue -Name 'deployBranch' -Value $config.deploy.branch

if (Get-Command New-AutopilotAuditSession -ErrorAction SilentlyContinue) {
  $script:ControllerAuditSession = New-AutopilotAuditSession -Operation 'controller-release-autopilot' -ManifestPath $ConfigPath -ScriptPath $PSCommandPath -Inputs @{
    configPath = $ConfigPath
    versionOverride = $Version
    commitMessageOverride = $CommitMessage
    skipMonitor = [bool]$SkipMonitor
    skipDeployUpdate = [bool]$SkipDeployUpdate
  }
  Save-ControllerAuditArtifact -Name 'controller-release-config.json' -Content $config
  Write-ControllerAuditEvent -Event 'config_loaded' -Message 'Controller release runtime configuration loaded.' -Data @{
    controllerRepoPath = $controllerRepoPath
    stateFilePath = $stateFilePath
    lockFilePath = $lockFilePath
  }
}

if (Test-Path $lockFilePath) {
  Write-Step "Another autopilot execution is already in progress. Exiting."
  Set-ControllerAuditSummaryValue -Name 'stateStatus' -Value 'skipped_locked'
  Write-ControllerAuditEvent -Event 'lock_detected' -Level 'warning' -Message 'Another release execution already holds the lock.' -Data @{ lockFilePath = $lockFilePath }
  Exit-ControllerReleaseSuccess -Message 'Skipped because another autopilot execution already holds the release lock.'
}

Ensure-ParentDirectory -FilePath $lockFilePath
Set-Content -Path $lockFilePath -Value (Get-Date).ToString("o")
Write-ControllerAuditEvent -Event 'lock_acquired' -Message 'Release lock acquired.' -Data @{ lockFilePath = $lockFilePath }

try {
  if (-not (Test-Path (Join-Path $controllerRepoPath ".git"))) {
    throw "Canonical controller clone was not found at $controllerRepoPath. Run prepare-controller-main.cmd first."
  }

  Ensure-GitIdentity -RepoPath $controllerRepoPath -GitConfig $config.git
  Invoke-Git -RepoPath $controllerRepoPath -Arguments @("fetch", "origin", $config.controller.branch) | Out-Null

  $currentBranch = Invoke-Git -RepoPath $controllerRepoPath -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
  if ($currentBranch -ne $config.controller.branch) {
    throw "Canonical controller clone is on '$currentBranch'. Expected '$($config.controller.branch)'. Run prepare-controller-main.cmd before editing."
  }

  Write-Step "Inspecting controller changes on canonical main clone"
  $managedReleaseFiles = @(
    $config.controller.packageJsonPath,
    $config.controller.packageLockJsonPath,
    $config.controller.swaggerJsonPath
  )
  $effectiveExcludes = @($config.controller.excludePaths + $managedReleaseFiles)
  $baseEntries = Get-WorkingTreeEntries -RepoPath $controllerRepoPath -ExcludePaths $effectiveExcludes
  $state = Load-State -StateFilePath $stateFilePath
  Write-ControllerAuditEvent -Event 'working_tree_inspected' -Message 'Controller working tree inspected.' -Data @{ entryCount = $baseEntries.Count }
  Save-ControllerAuditArtifact -Name 'working-tree-entries.json' -Content $baseEntries
  if ($state) {
    Update-ControllerAuditSummaryFromState -State $state
    Save-ControllerAuditArtifact -Name 'state-initial.json' -Content $state
  }

  if ($baseEntries.Count -eq 0) {
    if ($state -and $state.controllerCommit -and $state.targetVersion) {
      if ($state.status -eq "pushed" -and -not $SkipMonitor) {
        $token = Get-CiToken -Config $config -PathsConfig $config.paths -ConfigBasePath $configBase
        $reportsRoot = Resolve-AbsolutePath -BasePath $configBase -PathValue $config.paths.reportsDir
        $reportDir = Join-Path $reportsRoot ("controller-" + $state.controllerCommit.Substring(0, 7))
        Set-ControllerAuditSummaryValue -Name 'githubActionsReportDir' -Value $reportDir
        $ciProviderLabel = if ($config.ciProvider -eq "gitlab") { "GitLab CI" } else { "GitHub Actions" }
        Write-Step "Resuming $ciProviderLabel monitoring for $($state.controllerCommit)"
        Write-ControllerAuditEvent -Event 'workflow_monitor_resumed' -Message "Resuming $ciProviderLabel monitoring from persisted state." -Data @{
          controllerCommit = $state.controllerCommit
          reportDir = $reportDir
        }
        try {
          $run = Wait-CiRun -Token $token -Config $config -HeadSha $state.controllerCommit -ActionsConfig $config.actions -ReportBaseDir $reportDir
        } catch {
          $state.status = "build_failed"
          $state.updatedAt = (Get-Date).ToString("o")
          Set-StateProperty -State $state -Name "failureReportDir" -Value $reportDir
          Save-State -StateFilePath $stateFilePath -State $state
          throw
        }

        $state.status = "build_succeeded"
        Set-StateProperty -State $state -Name "workflowRunId" -Value $run.id
        $state.updatedAt = (Get-Date).ToString("o")
        Save-State -StateFilePath $stateFilePath -State $state
        Save-ControllerAuditArtifact -Name 'workflow-run.json' -Content $run

        if (-not $SkipDeployUpdate) {
          Complete-DeployPromotion -Config $config -ConfigBasePath $configBase -State $state -Version $state.targetVersion -StateFilePath $stateFilePath
        }

        Exit-ControllerReleaseSuccess -Message 'Controller release resumed successfully from persisted pushed state.'
      }

      if ($state.status -eq "build_succeeded" -and -not $SkipDeployUpdate) {
        Write-Step "Resuming deploy promotion to $($config.deploy.branch) for version $($state.targetVersion)"
        Complete-DeployPromotion -Config $config -ConfigBasePath $configBase -State $state -Version $state.targetVersion -StateFilePath $stateFilePath

        Exit-ControllerReleaseSuccess -Message 'Deploy promotion resumed successfully from persisted build_succeeded state.'
      }

      if (($state.status -eq "deploy_updated_pending_argocd" -or $state.status -eq "deploy_updated" -or $state.status -eq "argocd_synced") -and -not $SkipDeployUpdate) {
        if ($state.status -ne "deploy_updated") {
          $state.status = "deploy_updated"
          $state.updatedAt = (Get-Date).ToString("o")
          Set-StateProperty -State $state -Name "argocdBlockedReason" -Value $null
          Save-State -StateFilePath $stateFilePath -State $state
        }
        Write-Step "The release cycle is already complete at deploy values.yaml promotion."

        Exit-ControllerReleaseSuccess -Message 'Release cycle was already complete at deploy promotion.'
      }
    }

    if ($state -and $state.status -eq "build_failed") {
      Write-Step "No new code changes detected since the last failed build."
      Set-ControllerAuditSummaryValue -Name 'stateStatus' -Value 'build_failed'
      Exit-ControllerReleaseSuccess -Message 'No new code changes detected after the last failed build.'
    } else {
      Write-Step "No controller code changes detected. Nothing to publish."
      Set-ControllerAuditSummaryValue -Name 'stateStatus' -Value 'no_changes'
      Exit-ControllerReleaseSuccess -Message 'No controller code changes detected.'
    }
  }

  $fingerprint = Get-ChangeFingerprint -RepoPath $controllerRepoPath -Entries $baseEntries
  if ($state -and $state.changeFingerprint -eq $fingerprint) {
    Write-Step "Current controller change set was already processed in commit $($state.controllerCommit) with status $($state.status)."
    Write-ControllerAuditEvent -Event 'change_set_already_processed' -Message 'Current controller change set matches the persisted fingerprint.' -Data @{
      controllerCommit = $state.controllerCommit
      stateStatus = $state.status
    }
    Exit-ControllerReleaseSuccess -Message 'Current controller change set was already processed.'
  }

  $token = $null
  if (-not $SkipMonitor) {
    $token = Get-CiToken -Config $config -PathsConfig $config.paths -ConfigBasePath $configBase
  }

  $targetVersion = if ($Version) {
    $Version
  } elseif ($state -and $state.status -eq "build_failed" -and $state.targetVersion) {
    $state.targetVersion
  } else {
    $baseVersion = Get-ControllerBaseVersion -RepoPath $controllerRepoPath -Branch $config.controller.branch -PackageJsonPath $config.controller.packageJsonPath
    Get-NextPatchVersion -CurrentVersion $baseVersion
  }
  Set-ControllerAuditSummaryValue -Name 'targetVersion' -Value $targetVersion
  Write-ControllerAuditEvent -Event 'target_version_selected' -Message 'Release version selected.' -Data @{ targetVersion = $targetVersion }

  $message = if ($CommitMessage) {
    $CommitMessage
  } elseif ($state -and $state.status -eq "build_failed" -and $state.targetVersion -eq $targetVersion) {
    "fix(ci): correct controller build for $targetVersion"
  } else {
    "chore(release): publish controller $targetVersion"
  }

  Write-Step "Updating controller version files to $targetVersion"
  Update-ControllerVersionFiles -RepoPath $controllerRepoPath -ControllerConfig $config.controller -TargetVersion $targetVersion

  $changes = Get-WorkingTreeEntries -RepoPath $controllerRepoPath -ExcludePaths $config.controller.excludePaths
  if ($changes.Count -eq 0) {
    Write-Step "No controller changes were found to publish after version update."
    Set-ControllerAuditSummaryValue -Name 'stateStatus' -Value 'no_changes_after_version_update'
    Exit-ControllerReleaseSuccess -Message 'No controller changes were found to publish after version update.'
  }
  Save-ControllerAuditArtifact -Name 'post-version-working-tree.json' -Content $changes

  Write-Step "Creating release commit directly on $($config.controller.branch)"
  Invoke-Git -RepoPath $controllerRepoPath -Arguments @("reset") | Out-Null
  Invoke-Git -RepoPath $controllerRepoPath -Arguments @("add", "-A", "--", ".") | Out-Null

  $staged = Invoke-Git -RepoPath $controllerRepoPath -Arguments @("diff", "--cached", "--name-only")
  if (-not $staged) {
    Write-Step "No staged controller changes were produced."
    Set-ControllerAuditSummaryValue -Name 'stateStatus' -Value 'no_staged_changes'
    Exit-ControllerReleaseSuccess -Message 'No staged controller changes were produced.'
  }
  Save-ControllerAuditArtifact -Name 'staged-files.txt' -Content $staged -Format text

  $commitMessageFile = [System.IO.Path]::GetTempFileName()
  try {
    Set-Content -Path $commitMessageFile -Value $message -NoNewline
    Invoke-Git -RepoPath $controllerRepoPath -Arguments @("commit", "-F", $commitMessageFile) | Out-Null
  } finally {
    Remove-Item -Path $commitMessageFile -Force -ErrorAction SilentlyContinue
  }
  $commitSha = Invoke-Git -RepoPath $controllerRepoPath -Arguments @("rev-parse", "HEAD")
  Set-ControllerAuditSummaryValue -Name 'controllerCommit' -Value $commitSha
  Write-ControllerAuditEvent -Event 'controller_commit_created' -Message 'Controller release commit created.' -Data @{
    commit = $commitSha
    targetVersion = $targetVersion
    message = $message
  }

  Write-Step "Pushing controller commit $commitSha to origin/$($config.controller.branch)"
  Invoke-Git -RepoPath $controllerRepoPath -Arguments @("push", "origin", $config.controller.branch) | Out-Null
  Write-ControllerAuditEvent -Event 'controller_commit_pushed' -Message 'Controller release commit pushed to origin.' -Data @{
    commit = $commitSha
    branch = $config.controller.branch
  }

  $state = [pscustomobject]@{
    updatedAt = (Get-Date).ToString("o")
    status = "pushed"
    baseBranch = $config.controller.branch
    targetVersion = $targetVersion
    controllerCommit = $commitSha
    lastPushedCommit = $commitSha
    changeFingerprint = $fingerprint
  }
  Save-State -StateFilePath $stateFilePath -State $state

  if (-not $SkipMonitor) {
    $reportsRoot = Resolve-AbsolutePath -BasePath $configBase -PathValue $config.paths.reportsDir
    $reportDir = Join-Path $reportsRoot ("controller-" + $commitSha.Substring(0, 7))
    Set-ControllerAuditSummaryValue -Name 'githubActionsReportDir' -Value $reportDir
    $ciProviderLabel = if ($config.ciProvider -eq "gitlab") { "GitLab CI" } else { "GitHub Actions" }
    Write-Step "Monitoring $ciProviderLabel for $commitSha"
    Write-ControllerAuditEvent -Event 'workflow_monitor_started' -Message "Monitoring $ciProviderLabel for the pushed controller commit." -Data @{
      controllerCommit = $commitSha
      reportDir = $reportDir
    }
    try {
      $run = Wait-CiRun -Token $token -Config $config -HeadSha $commitSha -ActionsConfig $config.actions -ReportBaseDir $reportDir
    } catch {
      $state.status = "build_failed"
      $state.updatedAt = (Get-Date).ToString("o")
      Set-StateProperty -State $state -Name "failureReportDir" -Value $reportDir
      Save-State -StateFilePath $stateFilePath -State $state
      throw
    }

    $state.status = "build_succeeded"
    Set-StateProperty -State $state -Name "workflowRunId" -Value $run.id
    $state.updatedAt = (Get-Date).ToString("o")
    Save-State -StateFilePath $stateFilePath -State $state
    Save-ControllerAuditArtifact -Name 'workflow-run.json' -Content $run
    Write-Step "Controller build completed successfully: run $($run.id)"
  }

  if (-not $SkipDeployUpdate) {
    Complete-DeployPromotion -Config $config -ConfigBasePath $configBase -State $state -Version $targetVersion -StateFilePath $stateFilePath
  }

  Exit-ControllerReleaseSuccess -Message 'Controller release cycle finished successfully at deploy promotion.'
} catch {
  Write-ControllerAuditEvent -Event 'controller_release_failed' -Level 'error' -Message $_.Exception.Message -Data @{
    stateStatus = $script:ControllerAuditSummary.stateStatus
    targetVersion = $script:ControllerAuditSummary.targetVersion
    controllerCommit = $script:ControllerAuditSummary.controllerCommit
  }
  Complete-ControllerAuditSession -Status 'failed' -Message $_.Exception.Message
  throw
} finally {
  Remove-Item -Path $lockFilePath -Force -ErrorAction SilentlyContinue
}
