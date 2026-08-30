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
    [PSCustomObject]@{ Source = 'skills';        Claude = $true;  Gemini = $true  },
    [PSCustomObject]@{ Source = 'skills-claude'; Claude = $true;  Gemini = $false },
    [PSCustomObject]@{ Source = 'skills-gemini'; Claude = $false; Gemini = $true  }
)

# Never linked, never copied, never inlined into any harness configuration.
$NeverLinked = @('.agents', '.claude', 'docs', '.plans', 'tools')

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
    Write-Host ("  {0,-16} -> Claude: {1}   Gemini: {2}" -f $r.Source, $c, $g)
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

    if (Test-Path -LiteralPath $LinkPath) {
        $item = Get-Item -LiteralPath $LinkPath -Force
        $isReparse = [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)

        if ($isReparse) {
            $currentTarget = $item.Target
            $normCurrent = if ($currentTarget) { (Resolve-Path $currentTarget).Path.TrimEnd('\') } else { '' }
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
        New-Item -ItemType Junction -Path $LinkPath -Target $TargetPath | Out-Null
        Log-Action 'Junction' $LinkPath 'Created' "Created junction -> $TargetPath"
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

$userHome = [System.Environment]::GetFolderPath('UserProfile')
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

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
$geminiSkillsDir = Join-Path $geminiConfigDir 'skills'
$geminiAgentsMd = Join-Path $geminiConfigDir 'AGENTS.md'
$geminiBackupDir = Join-Path $geminiConfigDir 'backups'

Ensure-Directory $geminiConfigDir
Ensure-Directory $geminiSkillsDir

# Prune orphans before linking, so a rename is a remove-then-create rather than
# leaving a junction to a target that no longer exists.
if ($Prune) {
    Remove-OrphanJunctions $claudeSkillsDir
    Remove-OrphanJunctions $geminiSkillsDir
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
        if ($route.Gemini) {
            Ensure-Junction -LinkPath (Join-Path $geminiSkillsDir $skill.Name) -TargetPath $skill.FullName
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

# Antigravity inlined rules: the neutral baseline followed by the Gemini-only
# additions. This is a COPY, not a link, so it goes stale until setup runs again.
$agentsRuleFile = Join-Path $repoRoot 'rules\AGENTS.md'
$geminiRuleFile = Join-Path $repoRoot 'rules\GEMINI.md'

if (Test-Path -LiteralPath $agentsRuleFile) {
    $ruleContent = [System.IO.File]::ReadAllText($agentsRuleFile, [System.Text.Encoding]::UTF8).Trim()
    if (Test-Path -LiteralPath $geminiRuleFile) {
        $geminiContent = [System.IO.File]::ReadAllText($geminiRuleFile, [System.Text.Encoding]::UTF8).Trim()
        $ruleContent = $ruleContent + "`r`n`r`n" + $geminiContent
    }

    if (-not (Test-Path -LiteralPath $geminiAgentsMd)) {
        if ($DryRun) {
            Log-Action 'File' $geminiAgentsMd 'Created' 'Would create ~/.gemini/config/AGENTS.md with inlined rules'
        } else {
            [System.IO.File]::WriteAllText($geminiAgentsMd, (Set-MarkedRegion -Text '' -Body $ruleContent), $utf8NoBom)
            Log-Action 'File' $geminiAgentsMd 'Created' 'Created ~/.gemini/config/AGENTS.md with inlined rules'
        }
    } else {
        $existingAgentsText = [System.IO.File]::ReadAllText($geminiAgentsMd, [System.Text.Encoding]::UTF8)
        $updatedAgentsText = Set-MarkedRegion -Text $existingAgentsText -Body $ruleContent

        if ($updatedAgentsText -eq $existingAgentsText) {
            Log-Action 'File' $geminiAgentsMd 'Skipped' 'Inlined rules are already up to date'
        } else {
            if ($DryRun) {
                Log-Action 'File' $geminiAgentsMd 'Updated' 'Would regenerate inlined rules in marked region'
            } else {
                Ensure-Directory $geminiBackupDir
                $stamp = (Get-Date).ToString('yyyyMMddHHmmss')
                $backupFile = Join-Path $geminiBackupDir "AGENTS.md.$stamp.bak"
                [System.IO.File]::WriteAllText($backupFile, $existingAgentsText, $utf8NoBom)
                [System.IO.File]::WriteAllText($geminiAgentsMd, $updatedAgentsText, $utf8NoBom)
                Log-Action 'File' $geminiAgentsMd 'Updated' "Regenerated inlined rules (backup saved to $backupFile)"
            }
        }
    }
}
Assert-SingleRegion $geminiAgentsMd

Write-Host "`n=================================================="
Write-Host " Setup Summary"
Write-Host "=================================================="
$script:actions | Format-Table -AutoSize

Write-Host "Reminder: rules/AGENTS.md and rules/GEMINI.md reach Antigravity as an" -ForegroundColor DarkGray
Write-Host "INLINED COPY. Re-run this script after editing either file." -ForegroundColor DarkGray
