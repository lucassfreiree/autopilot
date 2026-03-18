[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = "",
    [Parameter(Mandatory = $false)]
    [string]$RulesPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRootDefault = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = $repoRootDefault
}

if ([string]::IsNullOrWhiteSpace($RulesPath)) {
    $RulesPath = Join-Path $repoRootDefault "config/product-export.rules.json"
}

$RepoRoot = (Resolve-Path $RepoRoot).Path
$RulesPath = (Resolve-Path $RulesPath).Path

function Read-JsonFile {
    param([string]$Path)
    return Get-Content $Path -Raw | ConvertFrom-Json
}

function New-Wildcard {
    param([string]$Pattern)
    return New-Object System.Management.Automation.WildcardPattern($Pattern, [System.Management.Automation.WildcardOptions]::IgnoreCase)
}

function Matches-AnyGlob {
    param(
        [string]$RelativePath,
        [object[]]$Globs
    )

    foreach ($glob in $Globs) {
        $matcher = New-Wildcard -Pattern $glob
        if ($matcher.IsMatch($RelativePath.Replace("\", "/"))) {
            return $true
        }
    }

    return $false
}

$rules = Read-JsonFile -Path $RulesPath
$errors = New-Object System.Collections.Generic.List[string]

foreach ($requiredFile in $rules.requiredRepoFiles) {
    $requiredPath = Join-Path $RepoRoot $requiredFile
    if (-not (Test-Path $requiredPath)) {
        [void]$errors.Add("Missing required file: $requiredFile")
    }
}

$files = Get-ChildItem -Path $RepoRoot -Recurse -File | Where-Object {
    $_.FullName -notmatch "\\.git\\"
}

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($RepoRoot.Length).TrimStart('\')

    if (Matches-AnyGlob -RelativePath $relativePath -Globs $rules.forbiddenPathGlobs) {
        [void]$errors.Add("Forbidden path found in repository: $relativePath")
        continue
    }

    if ($relativePath -like "var\*" -or $relativePath -like "var/*") {
        continue
    }

    if ($relativePath -in @("config\product-export.map.json", "config\product-export.rules.json")) {
        continue
    }

    $extension = [System.IO.Path]::GetExtension($file.FullName)
    if ($extension -notin @(".md", ".txt", ".ps1", ".cmd", ".json", ".yaml", ".yml", ".toml", ".sh")) {
        continue
    }

    $content = Get-Content $file.FullName -Raw
    foreach ($pattern in $rules.forbiddenContentPatterns) {
        if ([System.Text.RegularExpressions.Regex]::IsMatch($content, [string]$pattern.pattern)) {
            [void]$errors.Add("Forbidden content pattern '$($pattern.name)' found in $relativePath")
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    throw "Product export validation failed."
}

Write-Host "Product export validation passed."
