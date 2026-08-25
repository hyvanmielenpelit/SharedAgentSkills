[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot

Write-Host "=================================================="
Write-Host " SharedAgentSkills Bootstrap Setup"
Write-Host "=================================================="
if ($DryRun) {
    Write-Host "[DRY RUN MODE] No changes will be written to disk." -ForegroundColor Yellow
}

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
            # Normalize paths for comparison
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
            # Real directory
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

$userHome = [System.Environment]::GetFolderPath('UserProfile')
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# 1. Claude Code Discovery
$claudeDir = Join-Path $userHome '.claude'
$claudeSkillsDir = Join-Path $claudeDir 'skills'
$claudeRulesDir = Join-Path $claudeDir 'rules'
$claudeMdFile = Join-Path $claudeDir 'CLAUDE.md'
$claudeBackupDir = Join-Path $claudeDir 'backups'

Ensure-Directory $claudeDir
Ensure-Directory $claudeSkillsDir

# Junction each skill in skills/
$skillsSourceDir = Join-Path $repoRoot 'skills'
if (Test-Path -LiteralPath $skillsSourceDir) {
    $skills = Get-ChildItem -LiteralPath $skillsSourceDir -Directory
    foreach ($skill in $skills) {
        $dest = Join-Path $claudeSkillsDir $skill.Name
        Ensure-Junction -LinkPath $dest -TargetPath $skill.FullName
    }
}

# Junction rules
$rulesSourceDir = Join-Path $repoRoot 'rules'
if (Test-Path -LiteralPath $rulesSourceDir) {
    Ensure-Junction -LinkPath $claudeRulesDir -TargetPath $rulesSourceDir
}

# Claude Code CLAUDE.md include
$claudeBlock = @'
<!-- BEGIN SharedAgentSkills -->
@rules/CLAUDE.md
<!-- END SharedAgentSkills -->
'@

if (-not (Test-Path -LiteralPath $claudeMdFile)) {
    if ($DryRun) {
        Log-Action 'File' $claudeMdFile 'Created' 'Would create ~/.claude/CLAUDE.md with shared import block'
    } else {
        [System.IO.File]::WriteAllText($claudeMdFile, $claudeBlock, $utf8NoBom)
        Log-Action 'File' $claudeMdFile 'Created' 'Created ~/.claude/CLAUDE.md with shared import block'
    }
} else {
    $existingText = [System.IO.File]::ReadAllText($claudeMdFile, [System.Text.Encoding]::UTF8)
    if ($existingText -notmatch '<!-- BEGIN SharedAgentSkills -->') {
        if ($DryRun) {
            Log-Action 'File' $claudeMdFile 'Updated' 'Would append shared import block'
        } else {
            Ensure-Directory $claudeBackupDir
            $stamp = (Get-Date).ToString('yyyyMMddHHmmss')
            $backupFile = Join-Path $claudeBackupDir "CLAUDE.md.$stamp.bak"
            [System.IO.File]::WriteAllText($backupFile, $existingText, $utf8NoBom)
            
            $newText = $existingText.TrimEnd() + "`r`n`r`n" + $claudeBlock + "`r`n"
            [System.IO.File]::WriteAllText($claudeMdFile, $newText, $utf8NoBom)
            Log-Action 'File' $claudeMdFile 'Updated' "Appended import block (backup saved to $backupFile)"
        }
    } else {
        Log-Action 'File' $claudeMdFile 'Skipped' 'Import block already present in ~/.claude/CLAUDE.md'
    }
}

# 2. Antigravity Discovery
$geminiConfigDir = Join-Path $userHome '.gemini\config'
$geminiSkillsDir = Join-Path $geminiConfigDir 'skills'
$geminiAgentsMd = Join-Path $geminiConfigDir 'AGENTS.md'
$geminiBackupDir = Join-Path $geminiConfigDir 'backups'

Ensure-Directory $geminiConfigDir
Ensure-Directory $geminiSkillsDir

if (Test-Path -LiteralPath $skillsSourceDir) {
    $skills = Get-ChildItem -LiteralPath $skillsSourceDir -Directory
    foreach ($skill in $skills) {
        $dest = Join-Path $geminiSkillsDir $skill.Name
        Ensure-Junction -LinkPath $dest -TargetPath $skill.FullName
    }
}

# Inlined Antigravity rules regeneration
$agentsRuleFile = Join-Path $repoRoot 'rules\AGENTS.md'
if (Test-Path -LiteralPath $agentsRuleFile) {
    $ruleContent = [System.IO.File]::ReadAllText($agentsRuleFile, [System.Text.Encoding]::UTF8).Trim()
    $markedRegion = "<!-- BEGIN SharedAgentSkills -->`r`n$ruleContent`r`n<!-- END SharedAgentSkills -->"
    
    if (Test-Path -LiteralPath $geminiAgentsMd) {
        $existingAgentsText = [System.IO.File]::ReadAllText($geminiAgentsMd, [System.Text.Encoding]::UTF8)
        $pattern = '(?s)<!-- BEGIN SharedAgentSkills -->.*?<!-- END SharedAgentSkills -->'
        
        if ($existingAgentsText -match $pattern) {
            $updatedAgentsText = [System.Text.RegularExpressions.Regex]::Replace($existingAgentsText, $pattern, $markedRegion)
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
        } else {
            if ($DryRun) {
                Log-Action 'File' $geminiAgentsMd 'Updated' 'Would append marked inlined rules block'
            } else {
                Ensure-Directory $geminiBackupDir
                $stamp = (Get-Date).ToString('yyyyMMddHHmmss')
                $backupFile = Join-Path $geminiBackupDir "AGENTS.md.$stamp.bak"
                [System.IO.File]::WriteAllText($backupFile, $existingAgentsText, $utf8NoBom)
                
                $updatedAgentsText = $existingAgentsText.TrimEnd() + "`r`n`r`n" + $markedRegion + "`r`n"
                [System.IO.File]::WriteAllText($geminiAgentsMd, $updatedAgentsText, $utf8NoBom)
                Log-Action 'File' $geminiAgentsMd 'Updated' "Appended inlined rules block (backup saved to $backupFile)"
            }
        }
    } else {
        if ($DryRun) {
            Log-Action 'File' $geminiAgentsMd 'Created' 'Would create ~/.gemini/config/AGENTS.md with inlined rules'
        } else {
            [System.IO.File]::WriteAllText($geminiAgentsMd, $markedRegion + "`r`n", $utf8NoBom)
            Log-Action 'File' $geminiAgentsMd 'Created' 'Created ~/.gemini/config/AGENTS.md with inlined rules'
        }
    }
}

Write-Host "`n=================================================="
Write-Host " Setup Summary"
Write-Host "=================================================="
$script:actions | Format-Table -AutoSize
