param(
  [string]$ConfigPath
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

$script:PrepareControllerAuditSession = $null
$auditUtilsPath = Join-Path $PSScriptRoot 'audit-utils.ps1'
if (Test-Path $auditUtilsPath) {
  . $auditUtilsPath
}

function Write-PrepareControllerAuditEvent {
  param(
    [Parameter(Mandatory = $true)][string]$Event,
    [string]$Level = 'info',
    [string]$Message = '',
    [object]$Data
  )

  if ($script:PrepareControllerAuditSession -and (Get-Command Write-AutopilotAuditEvent -ErrorAction SilentlyContinue)) {
    Write-AutopilotAuditEvent -Session $script:PrepareControllerAuditSession -Event $Event -Level $Level -Message $Message -Data $Data | Out-Null
  }
}

function Save-PrepareControllerAuditArtifact {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [object]$Content
  )

  if ($script:PrepareControllerAuditSession -and (Get-Command Save-AutopilotAuditArtifact -ErrorAction SilentlyContinue)) {
    Save-AutopilotAuditArtifact -Session $script:PrepareControllerAuditSession -Name $Name -Content $Content | Out-Null
  }
}

function Complete-PrepareControllerAuditSession {
  param(
    [Parameter(Mandatory = $true)][string]$Status,
    [string]$Message,
    [object]$Summary
  )

  if ($script:PrepareControllerAuditSession -and (Get-Command Complete-AutopilotAuditSession -ErrorAction SilentlyContinue)) {
    Complete-AutopilotAuditSession -Session $script:PrepareControllerAuditSession -Status $Status -Summary $Summary -Message $Message
  }
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

function Invoke-Git {
  param(
    [string]$RepoPath,
    [string[]]$Arguments
  )

  $stdoutPath = [System.IO.Path]::GetTempFileName()
  $stderrPath = [System.IO.Path]::GetTempFileName()
  try {
    $process = Start-Process -FilePath "git" -ArgumentList (@("-C", $RepoPath) + $Arguments) -Wait -NoNewWindow -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
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

$configBase = Split-Path -Parent $ConfigPath
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$repoPath = Resolve-AbsolutePath -BasePath $configBase -PathValue $config.controller.repoPath
$repoParent = Split-Path -Parent $repoPath
$summary = [ordered]@{
  configPath = $ConfigPath
  repoPath = $repoPath
  branch = $config.controller.branch
}

if (Get-Command New-AutopilotAuditSession -ErrorAction SilentlyContinue) {
  $script:PrepareControllerAuditSession = New-AutopilotAuditSession -Operation 'prepare-controller-main' -ManifestPath $ConfigPath -ScriptPath $PSCommandPath -Inputs @{
    configPath = $ConfigPath
    repoPath = $repoPath
    branch = $config.controller.branch
  }
  Save-PrepareControllerAuditArtifact -Name 'prepare-controller-config.json' -Content $config
}

try {
  New-Item -ItemType Directory -Force -Path $repoParent | Out-Null

  if (-not (Test-Path (Join-Path $repoPath ".git"))) {
    Write-Step "Cloning controller repository into canonical autopilot workspace"
    Write-PrepareControllerAuditEvent -Event 'controller_clone_started' -Message 'Cloning controller repository into the canonical autopilot workspace.' -Data @{
      repoUrl = $config.controller.repoUrl
      repoPath = $repoPath
    }
    $cloneProcess = Start-Process -FilePath "git" -ArgumentList @("-C", $repoParent, "clone", $config.controller.repoUrl, $repoPath) -Wait -NoNewWindow -PassThru
    if ($cloneProcess.ExitCode -ne 0) {
      throw "Failed to clone controller repository into $repoPath"
    }
  }

  Ensure-GitIdentity -RepoPath $repoPath -GitConfig $config.git

  Write-Step "Synchronizing canonical controller clone to origin/$($config.controller.branch)"
  Write-PrepareControllerAuditEvent -Event 'controller_sync_started' -Message 'Synchronizing canonical controller clone to the target branch.' -Data @{
    repoPath = $repoPath
    branch = $config.controller.branch
  }
  Invoke-Git -RepoPath $repoPath -Arguments @("fetch", "origin", $config.controller.branch) | Out-Null
  Invoke-Git -RepoPath $repoPath -Arguments @("checkout", "-B", $config.controller.branch, "origin/$($config.controller.branch)") | Out-Null
  Invoke-Git -RepoPath $repoPath -Arguments @("reset", "--hard", "origin/$($config.controller.branch)") | Out-Null
  Invoke-Git -RepoPath $repoPath -Arguments @("clean", "-fd") | Out-Null

  $summary.currentBranch = Invoke-Git -RepoPath $repoPath -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
  $summary.origin = Invoke-Git -RepoPath $repoPath -Arguments @("remote", "get-url", "origin")
  Complete-PrepareControllerAuditSession -Status 'success' -Message 'Canonical controller clone prepared successfully.' -Summary ([pscustomobject]$summary)
  Write-Host "Canonical controller clone ready at: $repoPath"
} catch {
  Write-PrepareControllerAuditEvent -Event 'prepare_controller_main_failed' -Level 'error' -Message $_.Exception.Message -Data ([pscustomobject]$summary)
  Complete-PrepareControllerAuditSession -Status 'failed' -Message $_.Exception.Message -Summary ([pscustomobject]$summary)
  throw
}
