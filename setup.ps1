[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Prune
)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot

# Source directory -> harness routing. A skill directory is linked only into the
# harness(es) marked $true here.
$Routes = @(
    [PSCustomObject]@{ Source = 'skills';        Claude = $true;  Gemini = $true;  Codex = $true  },
    [PSCustomObject]@{ Source = 'skills-claude'; Claude = $true;  Gemini = $false; Codex = $false },
    [PSCustomObject]@{ Source = 'skills-gemini'; Claude = $false; Gemini = $true;  Codex = $false },
    [PSCustomObject]@{ Source = 'skills-codex';  Claude = $false; Gemini = $false; Codex = $true  }
)

# Never linked, never copied, never inlined into any harness configuration.
$NeverLinked = @('AGENTS.md', '.agents', '.claude', 'docs', '.plans', 'tools')

Write-Host "=================================================="
Write-Host " SharedAgentSkills Bootstrap Setup"
Write-Host "=================================================="
if ($DryRun) {
    Write-Host "[DRY RUN MODE] No changes will be written to disk." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Routing:" -ForegroundColor Cyan
foreach ($r in $Routes) {
    $c = if ($r.Claude) { 'yes' } else { 'no ' }
    $g = if ($r.Gemini) { 'yes' } else { 'no ' }
    $x = if ($r.Codex) { 'yes' } else { 'no ' }
    Write-Host ("  {0,-16} -> Claude: {1}   Gemini: {2}   Codex: {3}" -f $r.Source, $c, $g, $x)
}
Write-Host ("  NEVER LINKED:    {0}" -f ($NeverLinked -join ', ')) -ForegroundColor DarkGray
Write-Host ""

# The shared plans repository holds every implementation plan, review, and
# walkthrough. It is a separate clone, not something this script creates: a
# directory created here would have no remote, so nothing would ever be pushed
# from it and it would silently diverge. Warn only.
#
# This warning matters. When the clone is missing, agents fall back to each
# repository's gitignored .plans/ and keep working, so nothing fails loudly --
# this message and the agent's own fallback announcement are the only two places
# a missing clone surfaces.
$plansRoot = $env:AGENT_PLANS_ROOT
if (-not $plansRoot) { $plansRoot = 'C:\hmp\plans' }
$plansOk = $false
$plansFound = $null
foreach ($candidate in @($plansRoot, (Join-Path (Split-Path -Parent $repoRoot) 'plans'))) {
    if ($candidate -and (Test-Path (Join-Path $candidate '.git'))) {
        Write-Host ("Plans repository: {0}" -f $candidate) -ForegroundColor DarkGray
        $plansOk = $true
        $plansFound = $candidate
        break
    }
}
if (-not $plansOk) {
    Write-Host "WARNING: the shared plans repository was not found." -ForegroundColor Yellow
    Write-Host "  Looked for AGENT_PLANS_ROOT, C:\hmp\plans, and a 'plans' directory beside this one." -ForegroundColor Yellow
    Write-Host "  Without it, every agent silently falls back to each repository's .plans/," -ForegroundColor Yellow
    Write-Host "  which is gitignored and local to this machine. Clone it with:" -ForegroundColor Yellow
    Write-Host "    git clone https://github.com/hyvanmielenpelit/plans.git C:\hmp\plans" -ForegroundColor Yellow
}

# Configure that clone so a bare `git pull` rebases instead of merging. The store
# is append-only, so a rebase replays cleanly and keeps the history linear -- and
# a linear history is what a reader traces when asking what was decided and when.
# A merge commit there carries no information.
#
# Set here because git config does NOT travel with a clone: every developer would
# otherwise have to run these two commands by hand, and this script is already the
# prerequisite everyone runs. Local to that clone; nothing else on the machine is
# affected, and `git config --unset` reverses it.
if ($plansOk) {
    $plansConfig = @(
        [PSCustomObject]@{ Key = 'pull.rebase';      Value = 'true' },
        [PSCustomObject]@{ Key = 'rebase.autoStash'; Value = 'true' }
    )
    foreach ($cfg in $plansConfig) {
        $current = & git -C $plansFound config --local --get $cfg.Key
        if ($current -eq $cfg.Value) { continue }
        if ($DryRun) {
            Write-Host ("  Would set {0}={1} in the plans clone" -f $cfg.Key, $cfg.Value) -ForegroundColor Yellow
        } else {
            & git -C $plansFound config --local $cfg.Key $cfg.Value
            Write-Host ("  Set {0}={1} in the plans clone" -f $cfg.Key, $cfg.Value) -ForegroundColor Green
        }
    }
}
Write-Host ""

$actions = @()

function Log-Action {
    param(
        [string]$Category,
        [string]$Target,
        [string]$Status,
        [string]$Message
    )
    $script:actions += [PSCustomObject]@{
        Category = $Category
        Target   = $Target
        Status   = $Status
        Message  = $Message
    }
    $color = switch ($Status) {
        'Created'  { 'Green' }
        'Updated'  { 'Green' }
        'Removed'  { 'Yellow' }
        'Skipped'  { 'Cyan' }
        'Aborted'  { 'Red' }
        default    { 'White' }
    }
    Write-Host ("[{0}] {1}: {2} ({3})" -f $Status, $Category, $Target, $Message) -ForegroundColor $color
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        if ($DryRun) {
            Log-Action 'Directory' $Path 'Created' 'Would create directory'
        } else {
            [System.IO.Directory]::CreateDirectory($Path) | Out-Null
            Log-Action 'Directory' $Path 'Created' 'Created directory'
        }
    } else {
        Log-Action 'Directory' $Path 'Skipped' 'Directory already exists'
    }
}

function Ensure-Junction {
    param(
        [string]$LinkPath,
        [string]$TargetPath
    )

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        Log-Action 'Junction' $LinkPath 'Aborted' "Target directory does not exist: $TargetPath"
        return
    }

    $item = Get-Item -LiteralPath $LinkPath -Force -ErrorAction SilentlyContinue
    if ($item) {
        $isReparse = [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)

        if ($isReparse) {
            $currentTarget = $item.Target
            if ($currentTarget -is [array]) { $currentTarget = $currentTarget[0] }
            $resolvedCurrent = if ($currentTarget) { Resolve-Path -LiteralPath $currentTarget -ErrorAction SilentlyContinue } else { $null }
            $normCurrent = if ($resolvedCurrent) {
                $resolvedCurrent.Path.TrimEnd('\')
            } elseif ($currentTarget) {
                ([string]$currentTarget).TrimEnd('\')
            } else {
                ''
            }
            $normDesired = (Resolve-Path $TargetPath).Path.TrimEnd('\')

            if ($normCurrent -eq $normDesired) {
                Log-Action 'Junction' $LinkPath 'Skipped' 'Junction already points to correct target'
                return
            } else {
                if ($DryRun) {
                    Log-Action 'Junction' $LinkPath 'Updated' "Would redirect junction from $currentTarget to $TargetPath"
                    return
                } else {
                    [System.IO.Directory]::Delete($LinkPath)
                    Log-Action 'Junction' $LinkPath 'Updated' "Removed stale junction pointing to $currentTarget"
                }
            }
        } else {
            $childCount = (Get-ChildItem -LiteralPath $LinkPath -Force).Count
            if ($childCount -gt 0) {
                Log-Action 'Junction' $LinkPath 'Aborted' "Path is a non-empty real directory. Manual review required."
                return
            } else {
                if ($DryRun) {
                    Log-Action 'Junction' $LinkPath 'Updated' 'Would replace empty directory with junction'
                    return
                } else {
                    [System.IO.Directory]::Delete($LinkPath)
                }
            }
        }
    }

    if ($DryRun) {
        Log-Action 'Junction' $LinkPath 'Created' "Would create junction -> $TargetPath"
    } else {
        $parent = [System.IO.Path]::GetDirectoryName($LinkPath)
        if (-not (Test-Path -LiteralPath $parent)) {
            [System.IO.Directory]::CreateDirectory($parent) | Out-Null
        }
        try {
            New-Item -ItemType Junction -Path $LinkPath -Target $TargetPath | Out-Null
            Log-Action 'Junction' $LinkPath 'Created' "Created junction -> $TargetPath"
        } catch {
            Log-Action 'Junction' $LinkPath 'Aborted' ("Could not create junction: {0}" -f $_.Exception.Message)
        }
    }
}

# Remove junctions under a harness skills directory whose target resolves under
# this repository but no longer exists (a renamed or deleted shared skill).
# Scoped to targets under $repoRoot, so a skill installed from another source is
# never touched.
function Remove-OrphanJunctions {
    param([string]$HarnessSkillsDir)

    if (-not (Test-Path -LiteralPath $HarnessSkillsDir)) { return }

    $entries = Get-ChildItem -LiteralPath $HarnessSkillsDir -Force -ErrorAction SilentlyContinue
    foreach ($entry in $entries) {
        $isReparse = [bool]($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
        if (-not $isReparse) { continue }

        $target = $entry.Target
        if (-not $target) { continue }
        if ($target -is [array]) { $target = $target[0] }

        # Only consider junctions that point into this repository.
        if (-not $target.TrimEnd('\').StartsWith($repoRoot.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        if (Test-Path -LiteralPath $target) { continue }

        if ($DryRun) {
            Log-Action 'Prune' $entry.FullName 'Removed' "Would remove orphan junction -> $target"
        } else {
            [System.IO.Directory]::Delete($entry.FullName)
            Log-Action 'Prune' $entry.FullName 'Removed' "Removed orphan junction -> $target"
        }
    }
}

# Replace the contents of the single marked region, or append one if absent.
# Idempotent against a region that already holds different content, and collapses
# any duplicate regions down to one.
function Set-MarkedRegion {
    param(
        [string]$Text,
        [string]$Body
    )

    $begin = '<!-- BEGIN SharedAgentSkills -->'
    $end = '<!-- END SharedAgentSkills -->'
    $desired = "$begin`r`n$Body`r`n$end"
    $pattern = '(?s)<!-- BEGIN SharedAgentSkills -->.*?<!-- END SharedAgentSkills -->'

    $first = [regex]::Match($Text, $pattern)
    if (-not $first.Success) {
        if ([string]::IsNullOrWhiteSpace($Text)) {
            return $desired + "`r`n"
        }
        return $Text.TrimEnd() + "`r`n`r`n" + $desired + "`r`n"
    }

    $result = $Text.Substring(0, $first.Index) + $desired + $Text.Substring($first.Index + $first.Length)

    # Collapse any further regions.
    while (([regex]::Matches($result, $pattern)).Count -gt 1) {
        $extra = ([regex]::Matches($result, $pattern))[1]
        $result = $result.Remove($extra.Index, $extra.Length)
    }

    return $result
}

function Assert-SingleRegion {
    param(
        [string]$Path
    )
    if ($DryRun) { return }
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $pattern = '(?s)<!-- BEGIN SharedAgentSkills -->.*?<!-- END SharedAgentSkills -->'
    $count = ([regex]::Matches($text, $pattern)).Count
    if ($count -ne 1) {
        throw "Expected exactly one SharedAgentSkills marked region in $Path but found $count."
    }
}

function Update-InlinedRules {
    param(
        [string]$TargetFile,
        [string]$HarnessRuleFile,
        [string]$BackupDir,
        [string]$Label
    )

    $agentsRuleFile = Join-Path $repoRoot 'rules\AGENTS.md'
    if (-not (Test-Path -LiteralPath $agentsRuleFile) -or -not (Test-Path -LiteralPath $HarnessRuleFile)) {
        Log-Action 'File' $TargetFile 'Aborted' "$Label rule source is missing"
        return
    }

    $neutralContent = [System.IO.File]::ReadAllText($agentsRuleFile, [System.Text.Encoding]::UTF8).Trim()
    $harnessContent = [System.IO.File]::ReadAllText($HarnessRuleFile, [System.Text.Encoding]::UTF8).Trim()
    $ruleContent = ($neutralContent + "`r`n`r`n" + $harnessContent) -replace "`r?`n", "`r`n"

    if (-not (Test-Path -LiteralPath $TargetFile)) {
        if ($DryRun) {
            Log-Action 'File' $TargetFile 'Created' "Would create $Label rules with an inlined marked region"
        } else {
            [System.IO.File]::WriteAllText($TargetFile, (Set-MarkedRegion -Text '' -Body $ruleContent), $utf8NoBom)
            Log-Action 'File' $TargetFile 'Created' "Created $Label rules with an inlined marked region"
        }
        Assert-SingleRegion $TargetFile
        return
    }

    $existingText = [System.IO.File]::ReadAllText($TargetFile, [System.Text.Encoding]::UTF8)
    $updatedText = Set-MarkedRegion -Text $existingText -Body $ruleContent
    if ($updatedText -eq $existingText) {
        Log-Action 'File' $TargetFile 'Skipped' "$Label inlined rules are already up to date"
    } elseif ($DryRun) {
        Log-Action 'File' $TargetFile 'Updated' "Would regenerate $Label inlined rules"
    } else {
        Ensure-Directory $BackupDir
        $stamp = (Get-Date).ToString('yyyyMMddHHmmss')
        $backupFile = Join-Path $BackupDir ((Split-Path -Leaf $TargetFile) + ".$stamp.bak")
        [System.IO.File]::WriteAllText($backupFile, $existingText, $utf8NoBom)
        [System.IO.File]::WriteAllText($TargetFile, $updatedText, $utf8NoBom)
        Log-Action 'File' $TargetFile 'Updated' "Regenerated $Label inlined rules (backup saved to $backupFile)"
    }
    Assert-SingleRegion $TargetFile
}

$userHome = [System.Environment]::GetFolderPath('UserProfile')
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$codexHomeExplicit = -not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)
$codexHome = if ($codexHomeExplicit) { $env:CODEX_HOME } else { Join-Path $userHome '.codex' }
$codexOnPath = Get-Command codex -ErrorAction SilentlyContinue
$codexBundled = @()
if ($env:LOCALAPPDATA) {
    $codexBundled = @(Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin\*\codex.exe') -File -ErrorAction SilentlyContinue)
}
$codexInstalled = $codexHomeExplicit -or (Test-Path -LiteralPath $codexHome) -or $codexOnPath -or ($codexBundled.Count -gt 0)
$codexSkillsDir = Join-Path $codexHome 'skills'
$codexAgentsMd = Join-Path $codexHome 'AGENTS.md'
$codexOverrideMd = Join-Path $codexHome 'AGENTS.override.md'
$codexBackupDir = Join-Path $codexHome 'backups'
$codexConfigFile = Join-Path $codexHome 'config.toml'

if ($codexInstalled) {
    Ensure-Directory $codexHome
    Ensure-Directory $codexSkillsDir
    Ensure-Directory $codexBackupDir

    if (Test-Path -LiteralPath $codexOverrideMd) {
        $overrideText = [System.IO.File]::ReadAllText($codexOverrideMd, [System.Text.Encoding]::UTF8)
        if (-not [string]::IsNullOrWhiteSpace($overrideText)) {
            Write-Host ("WARNING: {0} is non-empty and shadows the generated Codex global rules." -f $codexOverrideMd) -ForegroundColor Yellow
        }
    }

    if ($plansOk) {
        $configText = if (Test-Path -LiteralPath $codexConfigFile) {
            [System.IO.File]::ReadAllText($codexConfigFile, [System.Text.Encoding]::UTF8)
        } else {
            ''
        }
        $commentFree = (($configText -split "`r?`n") | ForEach-Object { $_ -replace '#.*$', '' }) -join "`n"
        $normalizedConfig = $commentFree.Replace('/', '\')
        while ($normalizedConfig.Contains('\\')) { $normalizedConfig = $normalizedConfig.Replace('\\', '\') }
        $normalizedPlans = $plansFound.Replace('/', '\').TrimEnd('\')
        $plansConfigured = $normalizedConfig.IndexOf($normalizedPlans, [System.StringComparison]::OrdinalIgnoreCase) -ge 0

        if ($plansConfigured) {
            Write-Host ("Codex writable roots already mention the plans repository: {0}" -f $plansFound) -ForegroundColor DarkGray
        } else {
            $hasSandboxWorkspaceWrite =
                $commentFree -match '(?im)^\s*\[sandbox_workspace_write\]\s*$' -or
                $commentFree -match '(?im)^\s*sandbox_workspace_write\.writable_roots\s*=' -or
                $commentFree -match '(?im)^\s*sandbox_workspace_write\s*=\s*\{'
            Write-Host ("WARNING: Codex config does not grant workspace-write access to {0}." -f $plansFound) -ForegroundColor Yellow
            if ($hasSandboxWorkspaceWrite) {
                Write-Host ("  Add '{0}' to the existing writable_roots array." -f $plansFound) -ForegroundColor Yellow
            } else {
                Write-Host ("  Append this table to {0}:" -f $codexConfigFile) -ForegroundColor Yellow
                Write-Host "    [sandbox_workspace_write]" -ForegroundColor Yellow
                Write-Host ("    writable_roots = ['{0}']" -f $plansFound) -ForegroundColor Yellow
            }
            Write-Host "  If access is profile-specific, merge it under [profiles.<name>.sandbox_workspace_write]." -ForegroundColor Yellow
            Write-Host "  This script never modifies config.toml." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "Codex was not detected; skipping Codex bootstrap." -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 1. Claude Code Discovery
# ---------------------------------------------------------------------------
$claudeDir = Join-Path $userHome '.claude'
$claudeSkillsDir = Join-Path $claudeDir 'skills'
$claudeRulesDir = Join-Path $claudeDir 'rules'
$claudeMdFile = Join-Path $claudeDir 'CLAUDE.md'
$claudeBackupDir = Join-Path $claudeDir 'backups'

Ensure-Directory $claudeDir
Ensure-Directory $claudeSkillsDir

# ---------------------------------------------------------------------------
# 2. Antigravity Discovery
# ---------------------------------------------------------------------------
$geminiConfigDir = Join-Path $userHome '.gemini\config'
$geminiAgentsMd = Join-Path $geminiConfigDir 'AGENTS.md'
$geminiBackupDir = Join-Path $geminiConfigDir 'backups'
$geminiSkillsJson = Join-Path $geminiConfigDir 'skills.json'

# Legacy directory, we keep the path variable to prune it from skills.json if it exists
$geminiSkillsDir = Join-Path $geminiConfigDir 'skills'

Ensure-Directory $geminiConfigDir

$geminiSkillPaths = @()
foreach ($route in $Routes) {
    if ($route.Gemini) {
        $sourceDir = Join-Path $repoRoot $route.Source
        if (Test-Path -LiteralPath $sourceDir) {
            $geminiSkillPaths += ($sourceDir -replace '\\', '/')
        }
    }
}

$parsedJson = $null
$existingJsonText = ""
if (Test-Path -LiteralPath $geminiSkillsJson) {
    $existingJsonText = [System.IO.File]::ReadAllText($geminiSkillsJson, [System.Text.Encoding]::UTF8)
    $parsedJson = if ([string]::IsNullOrWhiteSpace($existingJsonText)) { $null } else { $existingJsonText | ConvertFrom-Json }
}

if (-not $parsedJson) {
    $parsedJson = [PSCustomObject]@{ entries = @() }
} elseif (-not $parsedJson.PSObject.Properties['entries']) {
    $parsedJson | Add-Member -MemberType NoteProperty -Name 'entries' -Value @()
}

$needsUpdate = $false
if ($parsedJson.entries) {
    $oldEntryPath = ($geminiSkillsDir -replace '\\', '/')
    $cleanEntries = @($parsedJson.entries | Where-Object {
        $p = if ($_.PSObject.Properties['path']) { $_.path } else { '' }
        ($p -replace '\\', '/') -ne '~/.gemini/config/skills' -and
        ($p -replace '\\', '/') -ne $oldEntryPath -and
        $p -ne $geminiSkillsDir
    })

    if ($cleanEntries.Count -ne @($parsedJson.entries).Count) {
        $parsedJson.entries = $cleanEntries
        $needsUpdate = $true
    }

    foreach ($entry in $parsedJson.entries) {
        if ($entry.PSObject.Properties['path']) {
            $normalizedPath = ($entry.path -replace '\\', '/')
            if ($entry.path -ne $normalizedPath) {
                $entry.path = $normalizedPath
                $needsUpdate = $true
            }
        }
    }
}

foreach ($path in $geminiSkillPaths) {
    $entryExists = $false
    if ($parsedJson.entries) {
        foreach ($entry in $parsedJson.entries) {
            if ($entry.PSObject.Properties['path'] -and ($entry.path -replace '\\', '/') -eq $path) {
                $entryExists = $true
                break
            }
        }
    }
    if (-not $entryExists) {
        $parsedJson.entries += [PSCustomObject]@{ path = $path }
        $needsUpdate = $true
    }
}

if (-not $needsUpdate) {
    Log-Action 'File' $geminiSkillsJson 'Skipped' 'skills.json already contains required global skill entries'
} else {
    if ($DryRun) {
        Log-Action 'File' $geminiSkillsJson 'Updated' 'Would update global skill entries in skills.json'
    } else {
        Ensure-Directory $geminiBackupDir
        $stamp = (Get-Date).ToString('yyyyMMddHHmmss')
        $updatedJsonText = $parsedJson | ConvertTo-Json -Depth 100

        if (Test-Path -LiteralPath $geminiSkillsJson) {
            $backupFile = Join-Path $geminiBackupDir "skills.json.$stamp.bak"
            [System.IO.File]::WriteAllText($backupFile, $existingJsonText, $utf8NoBom)
            Log-Action 'File' $geminiSkillsJson 'Updated' "Updated global skill entries in skills.json (backup saved to $backupFile)"
        } else {
            Log-Action 'File' $geminiSkillsJson 'Created' "Created skills.json with global skill entries"
        }
        [System.IO.File]::WriteAllText($geminiSkillsJson, $updatedJsonText, $utf8NoBom)
    }
}

# Prune orphans before linking, so a rename is a remove-then-create rather than
# leaving a junction to a target that no longer exists.
if ($Prune) {
    Remove-OrphanJunctions $claudeSkillsDir
    if ($codexInstalled) {
        Remove-OrphanJunctions $codexSkillsDir
    }
}

# Link each source directory into the harnesses it is routed to.
foreach ($route in $Routes) {
    $sourceDir = Join-Path $repoRoot $route.Source
    if (-not (Test-Path -LiteralPath $sourceDir)) { continue }

    $skills = Get-ChildItem -LiteralPath $sourceDir -Directory
    foreach ($skill in $skills) {
        if ($route.Claude) {
            Ensure-Junction -LinkPath (Join-Path $claudeSkillsDir $skill.Name) -TargetPath $skill.FullName
        }
        if ($codexInstalled -and $route.Codex) {
            Ensure-Junction -LinkPath (Join-Path $codexSkillsDir $skill.Name) -TargetPath $skill.FullName
        }
    }
}

# Warn if a skill name appears in more than one source directory, or shadows a
# repository-local skill.
$seen = @{}
foreach ($route in $Routes) {
    $sourceDir = Join-Path $repoRoot $route.Source
    if (-not (Test-Path -LiteralPath $sourceDir)) { continue }
    foreach ($skill in (Get-ChildItem -LiteralPath $sourceDir -Directory)) {
        if ($seen.ContainsKey($skill.Name)) {
            Write-Host ("[WARN] Skill '{0}' exists in both '{1}' and '{2}'." -f $skill.Name, $seen[$skill.Name], $route.Source) -ForegroundColor Red
        } else {
            $seen[$skill.Name] = $route.Source
        }
    }
}
$localSkillsDir = Join-Path $repoRoot '.agents\skills'
if (Test-Path -LiteralPath $localSkillsDir) {
    foreach ($local in (Get-ChildItem -LiteralPath $localSkillsDir -Directory)) {
        if ($seen.ContainsKey($local.Name)) {
            Write-Host ("[WARN] Repository-local skill '{0}' shadows a linked skill of the same name." -f $local.Name) -ForegroundColor Red
        }
    }
}

# Junction the rules directory for Claude Code.
$rulesSourceDir = Join-Path $repoRoot 'rules'
if (Test-Path -LiteralPath $rulesSourceDir) {
    Ensure-Junction -LinkPath $claudeRulesDir -TargetPath $rulesSourceDir
}

# Claude Code import block. Both the neutral baseline and the Claude-only rules
# are imported; rules/GEMINI.md is deliberately not.
$claudeBody = "@rules/AGENTS.md`r`n@rules/CLAUDE.md"

if (-not (Test-Path -LiteralPath $claudeMdFile)) {
    if ($DryRun) {
        Log-Action 'File' $claudeMdFile 'Created' 'Would create ~/.claude/CLAUDE.md with shared import block'
    } else {
        [System.IO.File]::WriteAllText($claudeMdFile, (Set-MarkedRegion -Text '' -Body $claudeBody), $utf8NoBom)
        Log-Action 'File' $claudeMdFile 'Created' 'Created ~/.claude/CLAUDE.md with shared import block'
    }
} else {
    $existingText = [System.IO.File]::ReadAllText($claudeMdFile, [System.Text.Encoding]::UTF8)
    $updatedText = Set-MarkedRegion -Text $existingText -Body $claudeBody

    if ($updatedText -eq $existingText) {
        Log-Action 'File' $claudeMdFile 'Skipped' 'Import block already up to date'
    } else {
        if ($DryRun) {
            Log-Action 'File' $claudeMdFile 'Updated' 'Would regenerate the marked import block'
        } else {
            Ensure-Directory $claudeBackupDir
            $stamp = (Get-Date).ToString('yyyyMMddHHmmss')
            $backupFile = Join-Path $claudeBackupDir "CLAUDE.md.$stamp.bak"
            [System.IO.File]::WriteAllText($backupFile, $existingText, $utf8NoBom)
            [System.IO.File]::WriteAllText($claudeMdFile, $updatedText, $utf8NoBom)
            Log-Action 'File' $claudeMdFile 'Updated' "Regenerated import block (backup saved to $backupFile)"
        }
    }
}
Assert-SingleRegion $claudeMdFile

# Inlined rules are copies, not links, so they go stale until setup runs again.
$geminiRuleFile = Join-Path $repoRoot 'rules\GEMINI.md'
$codexRuleFile = Join-Path $repoRoot 'rules\CODEX.md'
Update-InlinedRules -TargetFile $geminiAgentsMd -HarnessRuleFile $geminiRuleFile -BackupDir $geminiBackupDir -Label 'Antigravity'
if ($codexInstalled) {
    Update-InlinedRules -TargetFile $codexAgentsMd -HarnessRuleFile $codexRuleFile -BackupDir $codexBackupDir -Label 'Codex'
}

Write-Host "`n=================================================="
Write-Host " Setup Summary"
Write-Host "=================================================="
$script:actions | Format-Table -AutoSize

Write-Host "Reminder: Antigravity and Codex receive rules/AGENTS.md plus their" -ForegroundColor DarkGray
Write-Host "harness rule as INLINED COPIES. Re-run this script after editing them." -ForegroundColor DarkGray
