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
    [switch]$WhatIf,
    [switch]$SkipValidation
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

function Read-JsonFile {
    param([string]$Path)
    return Get-Content $Path -Raw | ConvertFrom-Json
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
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

function Is-TextFile {
    param(
        [string]$Path,
        [object[]]$TextExtensions
    )

    $ext = [System.IO.Path]::GetExtension($Path)
    return $TextExtensions -contains $ext
}

function Apply-Redactions {
    param(
        [string]$Content,
        [object[]]$Redactions
    )

    $updated = $Content
    foreach ($entry in $Redactions) {
        $updated = [System.Text.RegularExpressions.Regex]::Replace(
            $updated,
            [string]$entry.pattern,
            [string]$entry.replacement
        )
    }

    return $updated
}

function Assert-BlockedPatternsAbsent {
    param(
        [string]$Content,
        [string]$PathLabel,
        [object[]]$Patterns
    )

    foreach ($entry in $Patterns) {
        if ([System.Text.RegularExpressions.Regex]::IsMatch($Content, [string]$entry.pattern)) {
            throw "Blocked pattern '$($entry.name)' detected in $PathLabel"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    throw "SourceRoot is required. Use -SourceRoot or set LOCAL_AUTOPILOT_ROOT."
}

$SourceRoot = (Resolve-Path $SourceRoot).Path
$ProductRoot = (Resolve-Path $ProductRoot).Path
$MapPath = (Resolve-Path $MapPath).Path
$RulesPath = (Resolve-Path $RulesPath).Path

$map = Read-JsonFile -Path $MapPath
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$reportRoot = Join-Path $ProductRoot "var/product-export"
Ensure-Directory -Path $reportRoot

$copied = New-Object System.Collections.Generic.List[object]

foreach ($entry in $map.allowlist) {
    $sourcePath = Join-Path $SourceRoot $entry.source
    $targetPath = Join-Path $ProductRoot $entry.target

    if (-not (Test-Path $sourcePath)) {
        Write-Warning "Allowlist source not found: $sourcePath"
        continue
    }

    if ((Get-Item $sourcePath) -is [System.IO.DirectoryInfo]) {
        $files = Get-ChildItem -Path $sourcePath -Recurse -File
        foreach ($file in $files) {
            $relativeFromEntry = $file.FullName.Substring($sourcePath.Length).TrimStart('\')
            $relativeForRules = (Join-Path $entry.source $relativeFromEntry).Replace("\", "/")

            if (Matches-AnyGlob -RelativePath $relativeForRules -Globs $map.excludeGlobs) {
                continue
            }

            $destinationFile = Join-Path $targetPath $relativeFromEntry
            Ensure-Directory -Path (Split-Path -Parent $destinationFile)

            if ($WhatIf) {
                Write-Host "[WhatIf] copy $($file.FullName) -> $destinationFile"
                [void]$copied.Add(@{
                    source = $file.FullName
                    target = $destinationFile
                    mode   = "whatif"
                })
                continue
            }

            if ($entry.sanitize -and (Is-TextFile -Path $file.FullName -TextExtensions $map.textFileExtensions)) {
                $content = Get-Content $file.FullName -Raw
                $content = Apply-Redactions -Content $content -Redactions $map.pathRedactions
                Assert-BlockedPatternsAbsent -Content $content -PathLabel $relativeForRules -Patterns $map.blockedContentPatterns
                [System.IO.File]::WriteAllText($destinationFile, $content, $utf8NoBom)
            } else {
                Copy-Item -Path $file.FullName -Destination $destinationFile -Force
            }

            [void]$copied.Add(@{
                source = $file.FullName
                target = $destinationFile
            })
        }
    } else {
        Ensure-Directory -Path (Split-Path -Parent $targetPath)

        if ($WhatIf) {
            Write-Host "[WhatIf] copy $sourcePath -> $targetPath"
            [void]$copied.Add(@{
                source = $sourcePath
                target = $targetPath
                mode   = "whatif"
            })
            continue
        }

        if ($entry.sanitize -and (Is-TextFile -Path $sourcePath -TextExtensions $map.textFileExtensions)) {
            $content = Get-Content $sourcePath -Raw
            $content = Apply-Redactions -Content $content -Redactions $map.pathRedactions
            Assert-BlockedPatternsAbsent -Content $content -PathLabel $entry.source -Patterns $map.blockedContentPatterns
            [System.IO.File]::WriteAllText($targetPath, $content, $utf8NoBom)
        } else {
            Copy-Item -Path $sourcePath -Destination $targetPath -Force
        }

        [void]$copied.Add(@{
            source = $sourcePath
            target = $targetPath
        })
    }
}

$report = [pscustomobject]@{
    generatedAt = (Get-Date).ToString("o")
    sourceRoot  = $SourceRoot
    productRoot = $ProductRoot
    copiedFiles = $copied
}

[System.IO.File]::WriteAllText(
    (Join-Path $reportRoot "product-export-report.json"),
    ($report | ConvertTo-Json -Depth 8),
    $utf8NoBom
)

if (-not $SkipValidation -and -not $WhatIf) {
    & (Join-Path $repoRoot "scripts/validate-product-export.ps1") -RepoRoot $ProductRoot -RulesPath $RulesPath
}

Write-Host ("Export complete. Files processed: {0}" -f $copied.Count)
