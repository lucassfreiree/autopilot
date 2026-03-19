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
    [Parameter(Mandatory = $false)]
    [string]$RulesPath = "",
    [string]$BaseBranch = "main",
    [string]$SyncBranch = "",
    [string]$CommitPrefix = "chore(product-sync): promote autopilot updates",
    [switch]$SkipPullRequest,
    [switch]$WhatIf
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

if ([string]::IsNullOrWhiteSpace($RulesPath)) {
    $RulesPath = Join-Path $repoRoot "config/product-export.rules.json"
}

if ([string]::IsNullOrWhiteSpace($SyncBranch)) {
    if (-not [string]::IsNullOrWhiteSpace($env:PRODUCT_SYNC_BRANCH)) {
        $SyncBranch = $env:PRODUCT_SYNC_BRANCH
    } else {
        $SyncBranch = "sync/autopilot"
    }
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

function Invoke-Git {
    param([string[]]$GitArgs)

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()

    try {
        $process = Start-Process -FilePath "git" -ArgumentList $GitArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $stdout = @()
        $stderr = @()

        if (Test-Path $stdoutPath) {
            $stdout = Get-Content -Path $stdoutPath
        }

        if (Test-Path $stderrPath) {
            $stderr = Get-Content -Path $stderrPath
        }

        $combined = @($stdout + $stderr | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($process.ExitCode -ne 0) {
            throw ("git {0}`n{1}" -f ($GitArgs -join " "), ($combined -join [Environment]::NewLine))
        }

        return ($combined -join [Environment]::NewLine).Trim()
    }
    finally {
        Remove-Item -Path $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
    }
}

function Get-OriginMetadata {
    $remoteUrl = Invoke-Git -GitArgs @("config", "--get", "remote.origin.url")
    if ([string]::IsNullOrWhiteSpace($remoteUrl)) {
        throw "remote.origin.url is not configured."
    }

    $match = [regex]::Match($remoteUrl, "github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)(?:\.git)?$")
    if (-not $match.Success) {
        throw "Could not parse GitHub owner/repo from origin URL: $remoteUrl"
    }

    return [pscustomobject]@{
        url = $remoteUrl
        owner = $match.Groups["owner"].Value
        repo = $match.Groups["repo"].Value
    }
}

function Get-PullRequestToken {
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_PR_TOKEN)) {
        return $env:GITHUB_PR_TOKEN
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        return $env:GITHUB_TOKEN
    }

    return $null
}

function Invoke-GitHubApi {
    param(
        [string]$Method,
        [string]$Uri,
        [string]$Token,
        [object]$Body
    )

    $headers = @{
        Authorization = "Bearer $Token"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
        "User-Agent" = "autopilot-product-sync"
    }

    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers
    }

    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 10)
}

function Create-Or-UpdatePullRequest {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$BaseBranchName,
        [string]$SyncBranchName,
        [string]$Title,
        [string]$Body
    )

    $token = Get-PullRequestToken
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Warning "Skipping PR automation because GITHUB_PR_TOKEN or GITHUB_TOKEN is not set."
        return
    }

    $headQuery = [System.Uri]::EscapeDataString("${Owner}:$SyncBranchName")
    $baseQuery = [System.Uri]::EscapeDataString($BaseBranchName)
    $existing = @(Invoke-GitHubApi -Method "GET" -Uri "https://api.github.com/repos/$Owner/$Repo/pulls?state=open&head=$headQuery&base=$baseQuery" -Token $token -Body $null)

    if ($existing.Count -gt 0) {
        $prNumber = $existing[0].number
        $updated = Invoke-GitHubApi -Method "PATCH" -Uri "https://api.github.com/repos/$Owner/$Repo/pulls/$prNumber" -Token $token -Body @{
            title = $Title
            body = $Body
        }

        Write-Host ("Updated pull request #{0}: {1}" -f $updated.number, $updated.html_url)
        return
    }

    $created = Invoke-GitHubApi -Method "POST" -Uri "https://api.github.com/repos/$Owner/$Repo/pulls" -Token $token -Body @{
        title = $Title
        head = $SyncBranchName
        base = $BaseBranchName
        body = $Body
        maintainer_can_modify = $true
    }

    Write-Host ("Created pull request #{0}: {1}" -f $created.number, $created.html_url)
}

$PersistentRoot = Resolve-OptionalPath -Path $PersistentRoot
$WorkspaceRoot = Resolve-OptionalPath -Path $WorkspaceRoot
$MapPath = (Resolve-Path $MapPath).Path
$RulesPath = (Resolve-Path $RulesPath).Path
$exportScript = Join-Path $repoRoot "scripts/export-product-snapshot.ps1"

Push-Location $ProductRoot
$originalBranch = Invoke-Git -GitArgs @("branch", "--show-current")

if ($WhatIf) {
    & $exportScript -PersistentRoot $PersistentRoot -WorkspaceRoot $WorkspaceRoot -ProductRoot $ProductRoot -MapPath $MapPath -RulesPath $RulesPath -WhatIf -SkipValidation
    Write-Host ("Would push branch '{0}' and create or update a PR into '{1}'." -f $SyncBranch, $BaseBranch)
    exit 0
}

try {
    $status = Invoke-Git -GitArgs @("status", "--porcelain")
    if (-not [string]::IsNullOrWhiteSpace($status)) {
        throw "Product repository must be clean before running sync-product-pr.ps1."
    }

    $origin = Get-OriginMetadata
    Invoke-Git -GitArgs @("fetch", "origin")
    Invoke-Git -GitArgs @("checkout", $BaseBranch)
    Invoke-Git -GitArgs @("pull", "--ff-only", "origin", $BaseBranch)
    Invoke-Git -GitArgs @("checkout", "-B", $SyncBranch, "origin/$BaseBranch")

    & $exportScript -PersistentRoot $PersistentRoot -WorkspaceRoot $WorkspaceRoot -ProductRoot $ProductRoot -MapPath $MapPath -RulesPath $RulesPath

    Invoke-Git -GitArgs @("add", ".")
    $staged = Invoke-Git -GitArgs @("diff", "--cached", "--name-only")
    if ([string]::IsNullOrWhiteSpace($staged)) {
        Write-Host "No product changes detected after export."
        return
    }

    $changedFiles = @($staged -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $commitMessage = "{0} ({1})" -f $CommitPrefix, $timestamp
    $commitBody = @(
        "Automated promotion from local Autopilot via allowlist export and sanitization.",
        "",
        "Persistent root: $(if ($PersistentRoot) { $PersistentRoot } else { '(not resolved)' })",
        "Workspace root: $(if ($WorkspaceRoot) { $WorkspaceRoot } else { '(not resolved)' })",
        "",
        "Changed files:",
        ($changedFiles | ForEach-Object { "- $_" })
    ) -join [Environment]::NewLine

    Invoke-Git -GitArgs @("commit", "-m", $commitMessage, "-m", $commitBody)
    Invoke-Git -GitArgs @("push", "-u", "origin", $SyncBranch, "--force-with-lease")

    if (-not $SkipPullRequest) {
        $prTitle = $commitMessage
        $prBody = @(
            "## Automated Product Sync",
            "",
            "This pull request was generated automatically from the local Autopilot runtime.",
            "",
            "### Source Roots",
            "- Persistent root: $(if ($PersistentRoot) { $PersistentRoot } else { '(not resolved)' })",
            "- Workspace root: $(if ($WorkspaceRoot) { $WorkspaceRoot } else { '(not resolved)' })",
            "",
            "### Changed files",
            ($changedFiles | ForEach-Object { "- $_" }),
            "",
            "### Safety gates",
            "- allowlist export applied",
            "- sanitization applied",
            "- repository validation passed"
        ) -join [Environment]::NewLine

        Create-Or-UpdatePullRequest -Owner $origin.owner -Repo $origin.repo -BaseBranchName $BaseBranch -SyncBranchName $SyncBranch -Title $prTitle -Body $prBody
    }
}
finally {
    try {
        if (-not [string]::IsNullOrWhiteSpace($originalBranch)) {
            Invoke-Git -GitArgs @("checkout", $originalBranch) | Out-Null
        }
    }
    finally {
        Pop-Location
    }
}
