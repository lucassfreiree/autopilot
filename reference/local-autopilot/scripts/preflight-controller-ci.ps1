param(
  [string]$ConfigPath,
  [switch]$InstallDependencies
)

$ErrorActionPreference = 'Stop'
$autopilotHome = if ($env:BB_DEVOPS_AUTOPILOT_HOME) {
  $env:BB_DEVOPS_AUTOPILOT_HOME
} else {
  Join-Path $env:LOCALAPPDATA 'BBDevOpsAutopilot'
}

if (-not $ConfigPath) {
  $ConfigPath = Join-Path $autopilotHome 'controller-release-autopilot.json'
}

$auditUtilsPath = Join-Path $autopilotHome 'audit-utils.ps1'
if (Test-Path $auditUtilsPath) {
  . $auditUtilsPath
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

function Invoke-CheckedProcess {
  param(
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$WorkingDirectory
  )

  $stdoutPath = [System.IO.Path]::GetTempFileName()
  $stderrPath = [System.IO.Path]::GetTempFileName()
  try {
    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -Wait -NoNewWindow -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $stdout = if (Test-Path $stdoutPath) { Get-Content -Raw -Path $stdoutPath } else { '' }
    $stderr = if (Test-Path $stderrPath) { Get-Content -Raw -Path $stderrPath } else { '' }
    return [pscustomobject]@{
      ExitCode = $process.ExitCode
      Output = ([string]::Concat($stdout, $stderr)).Trim()
    }
  } finally {
    Remove-Item -Path $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
  }
}

function Get-NpmRegistryUrls {
  param([string[]]$ConfigPaths)

  $urls = New-Object System.Collections.Generic.List[string]
  foreach ($path in $ConfigPaths) {
    if (-not (Test-Path $path)) {
      continue
    }

    foreach ($line in (Get-Content -Path $path)) {
      if ($line -match '^\s*(?:@[^:]+:)?registry\s*=\s*(https?://\S+)\s*$') {
        $urls.Add($matches[1])
      }
    }
  }

  return @($urls.ToArray() | Select-Object -Unique)
}

function Get-NodeToolChecks {
  param([string]$RepoPath)

  return [pscustomobject]@{
    tsc = Test-Path (Join-Path $RepoPath 'node_modules\.bin\tsc.cmd')
    eslint = Test-Path (Join-Path $RepoPath 'node_modules\.bin\eslint.cmd')
    jest = Test-Path (Join-Path $RepoPath 'node_modules\.bin\jest.cmd')
  }
}

function Get-DependencyBootstrapStatus {
  param([string]$RepoPath)

  $toolChecks = Get-NodeToolChecks -RepoPath $RepoPath
  return [pscustomobject]@{
    nodeModulesPath = Join-Path $RepoPath 'node_modules'
    nodeModulesExists = Test-Path (Join-Path $RepoPath 'node_modules')
    packageLockExists = Test-Path (Join-Path $RepoPath 'package-lock.json')
    tools = $toolChecks
    bootstrapComplete = [bool]($toolChecks.tsc -and $toolChecks.eslint -and $toolChecks.jest)
  }
}

function Test-RegistryReachability {
  param([string[]]$RegistryUrls)

  $results = New-Object System.Collections.Generic.List[object]
  foreach ($url in $RegistryUrls) {
    try {
      $uri = [System.Uri]$url
      $addresses = [System.Net.Dns]::GetHostAddresses($uri.Host)
      $results.Add([pscustomobject]@{
        url = $url
        host = $uri.Host
        reachable = $true
        addresses = @($addresses | ForEach-Object { $_.IPAddressToString })
      })
    } catch {
      $failedHost = $null
      try {
        $failedHost = ([System.Uri]$url).Host
      } catch {
      }
      $results.Add([pscustomobject]@{
        url = $url
        host = $failedHost
        reachable = $false
        error = $_.Exception.Message
      })
    }
  }

  return $results.ToArray()
}

function Get-LatestNpmLogs {
  param([int]$MaxCount = 2)

  $logsRoot = Join-Path $env:LOCALAPPDATA 'npm-cache\_logs'
  if (-not (Test-Path $logsRoot)) {
    return @()
  }

  return @(
    Get-ChildItem -Path $logsRoot -File |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First $MaxCount
  )
}

function Remove-DirectoryRobust {
  param(
    [string]$Path,
    [int]$MaxAttempts = 3
  )

  if (-not (Test-Path $Path)) {
    return $true
  }

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt += 1) {
    try {
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    } catch {
    }

    if (-not (Test-Path $Path)) {
      return $true
    }

    & cmd.exe /c "rmdir /s /q `"$Path`"" | Out-Null
    Start-Sleep -Milliseconds 750
    if (-not (Test-Path $Path)) {
      return $true
    }
  }

  return (-not (Test-Path $Path))
}

function Save-NpmLogsToAudit {
  param(
    [object]$Session,
    [string]$Prefix = 'npm-log'
  )

  if (-not $Session) {
    return @()
  }

  $savedLogs = New-Object System.Collections.Generic.List[string]
  $index = 0
  foreach ($log in (Get-LatestNpmLogs)) {
    $index += 1
    Save-AutopilotAuditArtifact -Session $Session -Name ("{0}-{1}.txt" -f $Prefix, $index) -Content (Get-Content -Raw -Path $log.FullName) -Format text | Out-Null
    $savedLogs.Add($log.FullName)
  }

  return $savedLogs.ToArray()
}

function Invoke-DependencyBootstrap {
  param(
    [string]$RepoPath,
    [object]$Session
  )

  $initialStatus = Get-DependencyBootstrapStatus -RepoPath $RepoPath
  if ($Session) {
    Save-AutopilotAuditArtifact -Session $Session -Name 'dependency-bootstrap-status-before.json' -Content $initialStatus | Out-Null
  }

  if ($initialStatus.nodeModulesExists -and -not $initialStatus.bootstrapComplete) {
    $cleanupOk = Remove-DirectoryRobust -Path $initialStatus.nodeModulesPath
    if ($Session) {
      Save-AutopilotAuditArtifact -Session $Session -Name 'dependency-bootstrap-cleanup-before.json' -Content ([pscustomobject]@{
        targetPath = $initialStatus.nodeModulesPath
        removed = $cleanupOk
      }) | Out-Null
    }
    if (-not $cleanupOk) {
      throw "Failed to remove incomplete node_modules before bootstrap: $($initialStatus.nodeModulesPath)"
    }
  }

  $registryUrls = Get-NpmRegistryUrls -ConfigPaths @(
    (Join-Path $RepoPath '.npmrc'),
    (Join-Path $env:USERPROFILE '.npmrc')
  )
  $registryChecks = Test-RegistryReachability -RegistryUrls $registryUrls
  if ($Session) {
    Save-AutopilotAuditArtifact -Session $Session -Name 'npm-registry-check.json' -Content $registryChecks | Out-Null
  }

  $hasUnreachableRegistry = @($registryChecks | Where-Object { -not $_.reachable }).Count -gt 0
  $cacheVerifyResult = Invoke-CheckedProcess -FilePath 'npm.cmd' -Arguments @('cache', 'verify') -WorkingDirectory $RepoPath
  if ($Session) {
    Save-AutopilotAuditArtifact -Session $Session -Name 'npm-cache-verify.txt' -Content $cacheVerifyResult.Output -Format text | Out-Null
  }
  if ($cacheVerifyResult.ExitCode -ne 0) {
    $savedLogs = Save-NpmLogsToAudit -Session $Session -Prefix 'npm-cache-verify-log'
    throw "npm cache verify failed before bootstrap. Logs: $($savedLogs -join ', ')`n$($cacheVerifyResult.Output)"
  }

  $installArguments = @('ci', '--no-audit', '--progress=false')
  $bootstrapMode = 'online'
  if ($hasUnreachableRegistry) {
    $installArguments += '--offline'
    $bootstrapMode = 'offline'
  }

  if ($Session) {
    Save-AutopilotAuditArtifact -Session $Session -Name 'dependency-bootstrap-plan.json' -Content ([pscustomobject]@{
      mode = $bootstrapMode
      npmArguments = $installArguments
      registryUrls = $registryUrls
    }) | Out-Null
  }

  $installResult = Invoke-CheckedProcess -FilePath 'npm.cmd' -Arguments $installArguments -WorkingDirectory $RepoPath
  if ($Session) {
    Save-AutopilotAuditArtifact -Session $Session -Name 'npm-ci.txt' -Content $installResult.Output -Format text | Out-Null
  }

  $finalStatus = Get-DependencyBootstrapStatus -RepoPath $RepoPath
  if ($Session) {
    Save-AutopilotAuditArtifact -Session $Session -Name 'dependency-bootstrap-status-after.json' -Content $finalStatus | Out-Null
  }

  if ($installResult.ExitCode -ne 0) {
    $cleanupAfterFailure = Remove-DirectoryRobust -Path $finalStatus.nodeModulesPath
    if ($Session) {
      Save-AutopilotAuditArtifact -Session $Session -Name 'dependency-bootstrap-cleanup-after-failure.json' -Content ([pscustomobject]@{
        targetPath = $finalStatus.nodeModulesPath
        removed = $cleanupAfterFailure
      }) | Out-Null
    }
    $savedLogs = Save-NpmLogsToAudit -Session $Session -Prefix 'npm-ci-log'
    if ($hasUnreachableRegistry) {
      $hosts = (@($registryChecks | Where-Object { -not $_.reachable } | ForEach-Object { $_.host }) | Select-Object -Unique) -join ', '
      throw "Corporate npm registry host(s) are not resolvable from this machine: $hosts. Tried npm ci in offline mode after cleaning incomplete node_modules, but the local npm cache was insufficient. CleanupAfterFailure=$cleanupAfterFailure. Logs: $($savedLogs -join ', ')`n$($installResult.Output)"
    }

    throw "npm ci failed after cleaning incomplete dependency bootstrap. CleanupAfterFailure=$cleanupAfterFailure. Logs: $($savedLogs -join ', ')`n$($installResult.Output)"
  }

  if (-not $finalStatus.bootstrapComplete) {
    $cleanupAfterIncomplete = Remove-DirectoryRobust -Path $finalStatus.nodeModulesPath
    if ($Session) {
      Save-AutopilotAuditArtifact -Session $Session -Name 'dependency-bootstrap-cleanup-after-incomplete.json' -Content ([pscustomobject]@{
        targetPath = $finalStatus.nodeModulesPath
        removed = $cleanupAfterIncomplete
      }) | Out-Null
    }
    $savedLogs = Save-NpmLogsToAudit -Session $Session -Prefix 'npm-ci-log'
    throw "npm dependency bootstrap completed without the required local tools. CleanupAfterIncomplete=$cleanupAfterIncomplete. Logs: $($savedLogs -join ', ')"
  }

  return [pscustomobject]@{
    mode = $bootstrapMode
    registryChecks = $registryChecks
    status = $finalStatus
  }
}

function Test-SwaggerEncoding {
  param([string]$RepoPath)

  $swaggerPath = Join-Path $RepoPath 'src\swagger\swagger.json'
  if (-not (Test-Path $swaggerPath)) {
    return [pscustomobject]@{ skipped = $true; reason = 'swagger.json not found' }
  }

  $bytes = [System.IO.File]::ReadAllBytes($swaggerPath)
  $content = [System.Text.Encoding]::UTF8.GetString($bytes)

  # U+FFFD â€” replacement character, indicator of encoding corruption
  $fffdCount = ($content.ToCharArray() | Where-Object { [int]$_ -eq 0xFFFD }).Count

  # Double-encoding: Ãƒ (U+00C3) followed by special chars â€” pattern of UTF-8 re-encoded as Windows-1252
  $atil = [char]0x00C3
  $doubleEncPatterns = @(
    "${atil}$([char]0x00A7)",  # ÃƒÂ§ â†’ Ã§
    "${atil}$([char]0x00A3)",  # ÃƒÂ£ â†’ Ã£
    "${atil}$([char]0x00A9)",  # ÃƒÂ© â†’ Ã©
    "${atil}$([char]0x00A1)",  # ÃƒÂ¡ â†’ Ã¡
    "${atil}$([char]0x00AD)",  # ÃƒÂ­ â†’ Ã­
    "${atil}$([char]0x00B3)",  # ÃƒÂ³ â†’ Ã³
    "${atil}$([char]0x00B5)"   # ÃƒÂµ â†’ Ãµ
  )
  $doubleEncCount = 0
  foreach ($pattern in $doubleEncPatterns) {
    $doubleEncCount += ([regex]::Matches($content, [regex]::Escape($pattern))).Count
  }

  return [pscustomobject]@{
    skipped          = $false
    swaggerPath      = $swaggerPath
    fffdCount        = $fffdCount
    doubleEncCount   = $doubleEncCount
    ok               = ($fffdCount -eq 0 -and $doubleEncCount -eq 0)
  }
}

$configBasePath = Split-Path -Parent $ConfigPath
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$repoPath = Resolve-AbsolutePath -BasePath $configBasePath -PathValue $config.controller.repoPath
$session = $null
if (Get-Command New-AutopilotAuditSession -ErrorAction SilentlyContinue) {
  $session = New-AutopilotAuditSession -Operation 'preflight-controller-ci' -ManifestPath $ConfigPath -ScriptPath $PSCommandPath -Inputs @{
    configPath = $ConfigPath
    repoPath = $repoPath
    installDependencies = [bool]$InstallDependencies
  }
}

try {
  $packagePath = Join-Path $repoPath 'package.json'
  $package = Get-Content -Raw -Path $packagePath | ConvertFrom-Json
  if ($session) {
    Save-AutopilotAuditArtifact -Session $session -Name 'package-json.json' -Content $package | Out-Null
  }

  $nodeModulesPath = Join-Path $repoPath 'node_modules'
  $bootstrapStatus = Get-DependencyBootstrapStatus -RepoPath $repoPath
  if ($session) {
    Save-AutopilotAuditArtifact -Session $session -Name 'dependency-bootstrap-status-current.json' -Content $bootstrapStatus | Out-Null
  }

  $bootstrapResult = $null
  if ($InstallDependencies -and (-not $bootstrapStatus.bootstrapComplete)) {
    $bootstrapResult = Invoke-DependencyBootstrap -RepoPath $repoPath -Session $session
    $bootstrapStatus = $bootstrapResult.status
  }

  if (-not $bootstrapStatus.nodeModulesExists) {
    throw "node_modules is missing at $repoPath. Run preflight-controller-ci.cmd -InstallDependencies once, or run npm ci manually, before expecting local lint/test validation."
  }

  $toolChecks = $bootstrapStatus.tools
  if ($session) {
    Save-AutopilotAuditArtifact -Session $session -Name 'node-tool-check.json' -Content $toolChecks | Out-Null
  }
  if (-not ($toolChecks.tsc -and $toolChecks.eslint -and $toolChecks.jest)) {
    throw "node_modules exists at $repoPath, but required local tools are missing. This usually means npm install/bootstrap did not complete successfully. Restore dependency bootstrap before running lint/test."
  }

  $swaggerEncResult = Test-SwaggerEncoding -RepoPath $repoPath
  if ($session) {
    Save-AutopilotAuditArtifact -Session $session -Name 'swagger-encoding-check.json' -Content $swaggerEncResult | Out-Null
  }
  if (-not $swaggerEncResult.skipped -and -not $swaggerEncResult.ok) {
    $msg = "swagger.json encoding check failed: fffdCount=$($swaggerEncResult.fffdCount) doubleEncCount=$($swaggerEncResult.doubleEncCount). Fix encoding before pushing. See agent-shared-learnings.md section 'Problemas Conhecidos'."
    throw $msg
  }

  $lintResult = Invoke-CheckedProcess -FilePath 'npm.cmd' -Arguments @('run', 'lint') -WorkingDirectory $repoPath
  if ($session) {
    Save-AutopilotAuditArtifact -Session $session -Name 'npm-run-lint.txt' -Content $lintResult.Output -Format text | Out-Null
  }
  if ($lintResult.ExitCode -ne 0) {
    throw "npm run lint failed.`n$($lintResult.Output)"
  }

  $testResult = Invoke-CheckedProcess -FilePath 'npm.cmd' -Arguments @('test', '--', '--runInBand') -WorkingDirectory $repoPath
  if ($session) {
    Save-AutopilotAuditArtifact -Session $session -Name 'npm-test.txt' -Content $testResult.Output -Format text | Out-Null
  }
  if ($testResult.ExitCode -ne 0) {
    throw "npm test -- --runInBand failed.`n$($testResult.Output)"
  }

  if ($session) {
    Complete-AutopilotAuditSession -Session $session -Status 'success' -Summary ([pscustomobject]@{
      repoPath = $repoPath
      installDependencies = [bool]$InstallDependencies
      dependencyBootstrapMode = if ($bootstrapResult) { $bootstrapResult.mode } else { 'not-requested' }
      lint = 'success'
      test = 'success'
    }) -Message 'Controller CI preflight succeeded.'
  }

  Write-Host 'Controller CI preflight succeeded.'
} catch {
  if ($session) {
    Complete-AutopilotAuditSession -Session $session -Status 'failed' -Summary ([pscustomobject]@{
      repoPath = $repoPath
      installDependencies = [bool]$InstallDependencies
    }) -Message $_.Exception.Message
  }
  throw
}
