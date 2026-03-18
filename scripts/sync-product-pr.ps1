[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SourceRoot = "",
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

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = $env:LOCAL_AUTOPILOT_ROOT
}

if ([string]::IsNullOrWhiteSpace($ProductRoot)) {
    $ProductRoot = $repoRoot
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

function Invoke-Git {
    param([string[]]$GitArgs)

    $output = & git @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("git {0}`n{1}" -f ($GitArgs -join " "), ($output -join [Environment]::NewLine))
    }

    return ($output -join [Environment]::NewLine).Trim()
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
        url   = $remoteUrl
        owner = $match.Groups["owner"].Value
        repo  = $match.Groups["repo"].Value
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
        Authorization         = "Bearer $Token"
        Accept                = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
        "User-Agent"          = "autopilot-product-sync"
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
            body  = $Body
        }

        Write-Host ("Updated pull request #{0}: {1}" -f $updated.number, $updated.html_url)
        return
    }

    $created = Invoke-GitHubApi -Method "POST" -Uri "https://api.github.com/repos/$Owner/$Repo/pulls" -Token $token -Body @{
        title               = $Title
        head                = $SyncBranchName
        base                = $BaseBranchName
        body                = $Body
        maintainer_can_modify = $true
    }

    Write-Host ("Created pull request #{0}: {1}" -f $created.number, $created.html_url)
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    throw "SourceRoot is required. Use -SourceRoot or set LOCAL_AUTOPILOT_ROOT."
}

$SourceRoot = (Resolve-Path $SourceRoot).Path
$ProductRoot = (Resolve-Path $ProductRoot).Path
$MapPath = (Resolve-Path $MapPath).Path
$RulesPath = (Resolve-Path $RulesPath).Path
$exportScript = Join-Path $repoRoot "scripts/export-product-snapshot.ps1"
$originalBranch = Invoke-Git -GitArgs @("branch", "--show-current")

if ($WhatIf) {
    & $exportScript -SourceRoot $SourceRoot -ProductRoot $ProductRoot -MapPath $MapPath -RulesPath $RulesPath -WhatIf -SkipValidation
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

    & $exportScript -SourceRoot $SourceRoot -ProductRoot $ProductRoot -MapPath $MapPath -RulesPath $RulesPath

    Invoke-Git -GitArgs @("add", ".")
    $staged = Invoke-Git -GitArgs @("diff", "--cached", "--name-only")
    if ([string]::IsNullOrWhiteSpace($staged)) {
        Write-Host "No product changes detected after export."
        return
    }

    $changedFiles = @($staged -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $commitMessage = "{0} ({1})" -f $CommitPrefix, $timestamp
    $bodyLines = @(
        "Automated promotion from local Autopilot via allowlist export and sanitization.",
        "",
        "Changed files:",
        ($changedFiles | ForEach-Object { "- $_" })
    )
    $commitBody = $bodyLines -join [Environment]::NewLine

    Invoke-Git -GitArgs @("commit", "-m", $commitMessage, "-m", $commitBody)
    Invoke-Git -GitArgs @("push", "-u", "origin", $SyncBranch, "--force-with-lease")

    if (-not $SkipPullRequest) {
        $prTitle = $commitMessage
        $prBody = @(
            "## Automated Product Sync",
            "",
            "This pull request was generated automatically from the local Autopilot runtime.",
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
    if (-not [string]::IsNullOrWhiteSpace($originalBranch)) {
        Invoke-Git -GitArgs @("checkout", $originalBranch) | Out-Null
    }
}
