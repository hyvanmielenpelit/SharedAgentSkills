<#
.SYNOPSIS
    Regenerate a project repository's .claude/skills/ pointer stubs from the
    canonical .agents/skills/ bodies.

.DESCRIPTION
    Project repositories keep full skill bodies in .agents/skills/<underscore>/
    and a thin pointer stub in .claude/skills/<kebab>/. The stub's frontmatter
    description is what Claude Code indexes for triggering, so a canonical whose
    description changes without its stub being regenerated will trigger on stale
    wording, or not at all.

    This script regenerates every stub from its canonical, and reports canonicals
    with no stub and stubs with no canonical.

.PARAMETER Repo
    Path to the project repository root.

.PARAMETER Check
    Report differences and exit non-zero instead of writing anything.

.EXAMPLE
    .\tools\sync_stubs.ps1 -Repo C:\hmp\MobileGnollHackLogger
    .\tools\sync_stubs.ps1 -Repo C:\hmp\GnollHack -Check
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$agentsSkills = Join-Path $Repo '.agents\skills'
$claudeSkills = Join-Path $Repo '.claude\skills'

if (-not (Test-Path -LiteralPath $agentsSkills)) {
    Write-Error "No .agents/skills directory under $Repo"
    exit 2
}

function ConvertTo-Kebab {
    param([string]$Name)
    return $Name.Replace('_', '-')
}

# Read the YAML frontmatter block verbatim, plus the parsed name/description.
function Get-Frontmatter {
    param([string]$Path)

    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $normalized = $text.Replace("`r`n", "`n")
    if (-not $normalized.StartsWith("---`n")) { return $null }

    $endIndex = $normalized.IndexOf("`n---", 4)
    if ($endIndex -lt 0) { return $null }

    $block = $normalized.Substring(4, $endIndex - 4)
    return [PSCustomObject]@{ Block = $block }
}

# Detect the line-ending convention from the CANONICAL file, not the stub. The canonical
# is the source of truth and follows the repository's convention; an individual stub may
# have escaped normalization, and preserving that would perpetuate the anomaly.
function Get-Eol {
    param([string]$CanonicalPath)
    if (Test-Path -LiteralPath $CanonicalPath) {
        $bytes = [System.IO.File]::ReadAllBytes($CanonicalPath)
        $cr = 0
        foreach ($b in $bytes) { if ($b -eq 0x0D) { $cr++ } }
        if ($cr -eq 0) { return "`n" }
    }
    return "`r`n"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$canonicalDirs = Get-ChildItem -LiteralPath $agentsSkills -Directory | Sort-Object Name
$problems = 0
$written = 0
$upToDate = 0

foreach ($dir in $canonicalDirs) {
    $canonical = Join-Path $dir.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $canonical)) {
        Write-Host ("MISSING  {0}\SKILL.md" -f $dir.Name) -ForegroundColor Red
        $problems++
        continue
    }

    $fm = Get-Frontmatter $canonical
    if ($null -eq $fm) {
        Write-Host ("BAD FM   {0}\SKILL.md has no parsable frontmatter" -f $dir.Name) -ForegroundColor Red
        $problems++
        continue
    }

    $kebab = ConvertTo-Kebab $dir.Name
    $stubDir = Join-Path $claudeSkills $kebab
    $stubFile = Join-Path $stubDir 'SKILL.md'

    # The stub carries the canonical frontmatter with the name kebab-cased.
    $stubBlock = $fm.Block -replace ('(?m)^name:\s*' + [regex]::Escape($dir.Name) + '\s*$'), ("name: " + $kebab)

    $body = @"
---
$stubBlock
---

The full skill lives in this repository's tool-neutral agent directory (``.agents/``),
which is shared with other AI coding agents. This file is only a pointer.

Read ``.agents/skills/$($dir.Name)/SKILL.md`` (path relative to the repository root) in full
before proceeding, and follow it. Any ``references/`` files it links are relative to that
same directory.
"@

    $eol = Get-Eol $canonical
    $content = ($body.Replace("`r`n", "`n")).Replace("`n", $eol)

    $existing = $null
    if (Test-Path -LiteralPath $stubFile) {
        $existing = [System.IO.File]::ReadAllText($stubFile, [System.Text.Encoding]::UTF8)
    }

    if ($existing -eq $content) {
        $upToDate++
        continue
    }

    if ($Check) {
        if ($null -eq $existing) {
            Write-Host ("NO STUB  {0} -> {1}" -f $dir.Name, $kebab) -ForegroundColor Red
        } else {
            Write-Host ("STALE    {0} -> {1}" -f $dir.Name, $kebab) -ForegroundColor Yellow
        }
        $problems++
    } else {
        if (-not (Test-Path -LiteralPath $stubDir)) {
            [System.IO.Directory]::CreateDirectory($stubDir) | Out-Null
        }
        [System.IO.File]::WriteAllText($stubFile, $content, $utf8NoBom)
        Write-Host ("WROTE    {0} -> {1}" -f $dir.Name, $kebab) -ForegroundColor Green
        $written++
    }
}

# Stubs with no canonical.
$orphans = @()
if (Test-Path -LiteralPath $claudeSkills) {
    $expected = @{}
    foreach ($dir in $canonicalDirs) { $expected[(ConvertTo-Kebab $dir.Name)] = $true }
    foreach ($stub in (Get-ChildItem -LiteralPath $claudeSkills -Directory)) {
        if (-not $expected.ContainsKey($stub.Name)) {
            Write-Host ("ORPHAN   .claude/skills/{0} has no canonical" -f $stub.Name) -ForegroundColor Red
            $orphans += $stub.Name
            $problems++
        }
    }
}

Write-Host ""
Write-Host ("Canonicals: {0}   up to date: {1}   written: {2}   orphan stubs: {3}" -f `
    $canonicalDirs.Count, $upToDate, $written, $orphans.Count)

if ($Check -and $problems -gt 0) {
    Write-Host ("FAIL: {0} problem(s)." -f $problems) -ForegroundColor Red
    exit 1
}

if ($problems -gt 0 -and -not $Check) {
    Write-Host ("Completed with {0} problem(s) that require manual attention." -f $problems) -ForegroundColor Yellow
    exit 1
}

Write-Host "OK" -ForegroundColor Green
exit 0
