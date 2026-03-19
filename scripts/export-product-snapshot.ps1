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
    [switch]$WhatIf,
    [switch]$SkipValidation
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

function Resolve-EntrySourceBase {
    param(
        [object]$Entry,
        [string]$ResolvedPersistentRoot,
        [string]$ResolvedWorkspaceRoot
    )

    $sourceKind = if ($Entry.PSObject.Properties.Name -contains "sourceRoot" -and -not [string]::IsNullOrWhiteSpace([string]$Entry.sourceRoot)) {
        [string]$Entry.sourceRoot
    } else {
        "persistent"
    }

    switch ($sourceKind.ToLowerInvariant()) {
        "workspace" {
            if ([string]::IsNullOrWhiteSpace($ResolvedWorkspaceRoot)) {
                throw "Allowlist entry '$($Entry.source)' requires WorkspaceRoot, but it was not resolved."
            }

            return $ResolvedWorkspaceRoot
        }
        "persistent" {
            if ([string]::IsNullOrWhiteSpace($ResolvedPersistentRoot)) {
                throw "Allowlist entry '$($Entry.source)' requires PersistentRoot, but it was not resolved."
            }

            return $ResolvedPersistentRoot
        }
        default {
            throw "Unknown sourceRoot '$sourceKind' in allowlist entry '$($Entry.source)'."
        }
    }
}

$PersistentRoot = Resolve-OptionalPath -Path $PersistentRoot
$WorkspaceRoot = Resolve-OptionalPath -Path $WorkspaceRoot
$MapPath = (Resolve-Path $MapPath).Path
$RulesPath = (Resolve-Path $RulesPath).Path

$map = Read-JsonFile -Path $MapPath
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$reportRoot = Join-Path $ProductRoot "var/product-export"
Ensure-Directory -Path $reportRoot

$copied = New-Object System.Collections.Generic.List[object]

foreach ($entry in $map.allowlist) {
    $entryRoot = Resolve-EntrySourceBase -Entry $entry -ResolvedPersistentRoot $PersistentRoot -ResolvedWorkspaceRoot $WorkspaceRoot
    $sourcePath = Join-Path $entryRoot $entry.source
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
                    sourceRoot = $entryRoot
                    mode = "whatif"
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
                sourceRoot = $entryRoot
            })
        }
    } else {
        Ensure-Directory -Path (Split-Path -Parent $targetPath)

        if ($WhatIf) {
            Write-Host "[WhatIf] copy $sourcePath -> $targetPath"
            [void]$copied.Add(@{
                source = $sourcePath
                target = $targetPath
                sourceRoot = $entryRoot
                mode = "whatif"
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
            sourceRoot = $entryRoot
        })
    }
}

$report = [pscustomobject]@{
    generatedAt = (Get-Date).ToString("o")
    persistentRoot = $PersistentRoot
    workspaceRoot = $WorkspaceRoot
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
