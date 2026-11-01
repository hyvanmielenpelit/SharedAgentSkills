<#
.SYNOPSIS
Lists the steps that developer runbooks in the plans repository still leave open.

.DESCRIPTION
Reads one scope of the shared plans repository, for example hyvanmielenpelit/GnollHack.
In each task directory it pairs the latest developer_runbook[_<round>]_v<N>.md with
walkthrough[_<round>].md and parses the walkthrough's "## Runbook status" table, whose
header is exactly:

    | ID | Kind | Where | What | State | Date | Note |

Open states are remaining, failed and blocked. Closed states are done, waived and
superseded. A walkthrough with a status table and no runbook is valid; a runbook with no
walkthrough is counted as planned, because no status exists yet. Fenced code blocks are
ignored, so a walkthrough may quote the format.

Every condition that could hide a step is an error, and an error makes the run exit 1: a
misnamed runbook, or a misnamed walkthrough beside a runbook or holding a status section; a
missing, repeated or differently spelled status heading; a malformed table, or table rows
after the first table of a section; an empty ID, Kind or Where; an unknown state; a duplicate
ID; or a runbook whose "## At a Glance" table, "## Steps" section and the status table
disagree on IDs, Kinds or Where values.

Reads only runbooks and walkthroughs, and writes nothing.

Exit codes: 0 no problems, 1 problems found, 2 the script could not run.

.PARAMETER Scope
The scope below the plans root: <organization>/<repository>.

.PARAMETER Where
Keep the steps whose Where contains this text.

.PARAMETER Kind
Keep the steps of exactly this kind.

.PARAMETER Task
Keep the tasks whose <date>/<task> name contains this text.

.PARAMETER PlansRoot
The plans repository. By default AGENT_PLANS_ROOT, then C:\hmp\plans, then a plans directory
beside this repository.

.EXAMPLE
.\Get-OpenRunbookSteps.ps1 -Scope hyvanmielenpelit/GnollHack

.EXAMPLE
.\Get-OpenRunbookSteps.ps1 -Scope hyvanmielenpelit/GnollHack -Where 'Steam Deck' -Kind TEST
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $Scope,
    [string] $Where,
    [string] $Kind,
    [string] $Task,
    [string] $PlansRoot
)

$ErrorActionPreference = 'Stop'
trap {
    Write-Output "ERROR: the script could not run: $_"
    exit 2
}

$StatusHeading = '## Runbook status'
$StatusHeader = '| ID | Kind | Where | What | State | Date | Note |'
$GlanceHeading = '## At a Glance'
$OpenStates = @('remaining', 'failed', 'blocked')
$ClosedStates = @('done', 'waived', 'superseded')

function Resolve-PlansRoot {
    param([string] $Explicit)
    if ($Explicit) {
        if (Test-Path -LiteralPath (Join-Path $Explicit '.git')) {
            return (Resolve-Path -LiteralPath $Explicit).ProviderPath
        }
        return $null
    }
    $candidates = @()
    if ($env:AGENT_PLANS_ROOT) { $candidates += $env:AGENT_PLANS_ROOT }
    $candidates += 'C:\hmp\plans'
    $candidates += (Join-Path $PSScriptRoot '..\..\plans')
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $candidate '.git')) {
            return (Resolve-Path -LiteralPath $candidate).ProviderPath
        }
    }
    return $null
}

# The lines of a file, with fenced code blocks blanked out.
function Get-DocumentLines {
    param([string] $Path)
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    $fence = ''
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $trimmed = $lines[$i].Trim()
        if ($fence) {
            if ($trimmed -match '^(`{3,}|~{3,})$' -and $trimmed[0] -eq $fence[0] -and $trimmed.Length -ge $fence.Length) {
                $fence = ''
            }
            $lines[$i] = ''
        }
        elseif ($trimmed -match '^(`{3,}|~{3,})') {
            $fence = $Matches[1]
            $lines[$i] = ''
        }
    }
    return ,$lines
}

function Split-TableRow {
    param([string] $Line)
    $masked = $Line.Trim().Trim('|').Replace('\|', [string][char]1)
    $cells = @()
    foreach ($cell in $masked.Split('|')) {
        $cells += $cell.Replace([string][char]1, '|').Trim()
    }
    return ,$cells
}

# The first table of a section, and whether more table rows follow it in that section.
function Get-SectionTable {
    param([string[]] $Lines, [string] $Heading)
    $rows = New-Object System.Collections.ArrayList
    $start = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -eq $Heading) { $start = $i + 1; break }
    }
    if ($start -lt 0) { return $null }
    $ended = $false
    $extra = $false
    for ($i = $start; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i].Trim()
        if ($line.StartsWith('#')) { break }
        if ($line.StartsWith('|')) {
            if ($ended) { $extra = $true }
            else { [void]$rows.Add($line) }
        }
        elseif ($rows.Count -gt 0) { $ended = $true }
    }
    return [pscustomobject]@{ Rows = $rows.ToArray(); Extra = $extra }
}

# The problem with a table's shape, or an empty string.
function Get-TableProblem {
    param($Table, [string] $Name)
    if ($Table.Rows.Count -lt 2) { return "the $Name table has no header and separator" }
    if ($Table.Rows[1] -notmatch '^\|[\s:|-]+\|$') { return "the $Name table's second line is not a separator" }
    if ($Table.Extra) { return "the $Name section has table rows after a blank line or prose; keep one unbroken table" }
    return ''
}

# The S and M IDs that the Steps section defines.
function Get-StepsSectionIds {
    param([string[]] $Lines)
    $ids = @{}
    $inside = $false
    foreach ($line in $Lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^##\s') { $inside = ($trimmed -eq '## Steps'); continue }
        if (-not $inside) { continue }
        if ($trimmed -match '^###\s+(S\d+)\b') { $ids[$Matches[1]] = $true }
        elseif ($trimmed -match '^\|\s*(M\d+)\s*\|') { $ids[$Matches[1]] = $true }
    }
    return $ids
}

function ConvertTo-Href {
    param([string] $Path)
    return $Path.Replace('\', '/')
}

function ConvertTo-Cell {
    param([string] $Text)
    return $Text.Replace('|', '\|')
}

$root = Resolve-PlansRoot $PlansRoot
if (-not $root) {
    Write-Output 'ERROR: no plans repository found (-PlansRoot, AGENT_PLANS_ROOT, C:\hmp\plans, or beside this repository).'
    exit 2
}
$scopeDir = Join-Path $root ($Scope.Replace('/', '\'))
if (-not (Test-Path -LiteralPath $scopeDir -PathType Container)) {
    Write-Output "ERROR: scope not found: $scopeDir"
    exit 2
}

$steps = New-Object System.Collections.ArrayList
$planned = New-Object System.Collections.ArrayList
$problems = New-Object System.Collections.ArrayList

$dateDirs = Get-ChildItem -LiteralPath $scopeDir -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }
foreach ($dateDir in $dateDirs) {
    foreach ($taskDir in (Get-ChildItem -LiteralPath $dateDir.FullName -Directory)) {
        $taskName = "$($dateDir.Name)/$($taskDir.Name)"
        if ($Task -and $taskName -notlike "*$Task*") { continue }

        # A round is '' for the first round, or its letter for a follow-up round.
        $runbooks = @{}
        foreach ($file in (Get-ChildItem -LiteralPath $taskDir.FullName -File -Filter 'developer_runbook*')) {
            if ($file.Name -match '^developer_runbook(?:_([A-Z]))?_v(\d+)\.md$') {
                $round = [string]$Matches[1]
                $version = [int]$Matches[2]
                if (-not $runbooks.ContainsKey($round) -or $runbooks[$round].Version -lt $version) {
                    $runbooks[$round] = [pscustomobject]@{ Version = $version; File = $file }
                }
            }
            else {
                [void]$problems.Add("$taskName/$($file.Name): not a runbook name; use developer_runbook[_<round>]_v<N>.md")
            }
        }
        $walkthroughs = @{}
        foreach ($file in (Get-ChildItem -LiteralPath $taskDir.FullName -File -Filter 'walkthrough*')) {
            if ($file.Name -match '^walkthrough(?:_([A-Z]))?\.md$') {
                $walkthroughs[[string]$Matches[1]] = $file
            }
            elseif ($runbooks.Count -gt 0 -or
                    @((Get-DocumentLines $file.FullName) -match '(?i)^#{1,6}\s*runbook status').Count -gt 0) {
                [void]$problems.Add("$taskName/$($file.Name): not a walkthrough name; use walkthrough[_<round>].md")
            }
        }

        $rounds = @($runbooks.Keys) + @($walkthroughs.Keys) | Sort-Object -Unique
        foreach ($round in $rounds) {
            $runbook = if ($runbooks.ContainsKey($round)) { $runbooks[$round].File } else { $null }
            $walkthrough = if ($walkthroughs.ContainsKey($round)) { $walkthroughs[$round] } else { $null }
            $display = if ($round) { "$taskName ($round)" } else { $taskName }
            if (-not $walkthrough) {
                [void]$planned.Add([pscustomobject]@{ Task = $display; Runbook = $runbook })
                continue
            }
            $name = "$taskName/$($walkthrough.Name)"

            $lines = Get-DocumentLines $walkthrough.FullName
            $headings = @($lines -match '(?i)^#{1,6}\s*runbook status')
            if ($headings.Count -eq 0) {
                if ($runbook) {
                    [void]$problems.Add("${name}: a runbook exists but the walkthrough has no '$StatusHeading' section")
                }
                continue
            }
            if ($headings.Count -gt 1) {
                [void]$problems.Add("${name}: more than one status section")
                continue
            }
            if ($headings[0].Trim() -cne $StatusHeading) {
                [void]$problems.Add("${name}: the status heading must be exactly '$StatusHeading', not '$($headings[0].Trim())'")
                continue
            }
            $table = Get-SectionTable $lines $StatusHeading
            if ($table.Rows.Count -lt 1 -or $table.Rows[0] -ne $StatusHeader) {
                [void]$problems.Add("${name}: the status table's header must be exactly '$StatusHeader'")
                continue
            }
            $problem = Get-TableProblem $table 'status'
            if ($problem) {
                [void]$problems.Add("${name}: $problem")
                continue
            }

            $link = if ($runbook) { $runbook } else { $walkthrough }
            $seen = @{}
            foreach ($row in ($table.Rows | Select-Object -Skip 2)) {
                $cells = Split-TableRow $row
                if ($cells.Count -ne 7) {
                    [void]$problems.Add("${name}: a status row does not have 7 cells: $row")
                    continue
                }
                $id = $cells[0]
                if (-not $id -or -not $cells[1] -or -not $cells[2]) {
                    [void]$problems.Add("${name}: a status row has an empty ID, Kind or Where: $row")
                    continue
                }
                if ($seen.ContainsKey($id)) {
                    [void]$problems.Add("${name}: duplicate ID $id")
                    continue
                }
                $seen[$id] = $cells
                $state = $cells[4]
                if ($OpenStates -notcontains $state -and $ClosedStates -notcontains $state) {
                    [void]$problems.Add("${name}: $id has unknown state '$state'")
                    continue
                }
                if ($OpenStates -contains $state) {
                    [void]$steps.Add([pscustomobject]@{
                        Task = $display; Order = $steps.Count; Id = $id; Kind = $cells[1]; Where = $cells[2]
                        What = $cells[3]; State = $state; Note = $cells[6]; Link = $link
                    })
                }
            }

            if ($runbook) {
                $runbookName = "$taskName/$($runbook.Name)"
                $runbookLines = Get-DocumentLines $runbook.FullName
                $glance = Get-SectionTable $runbookLines $GlanceHeading
                if ($null -eq $glance) {
                    [void]$problems.Add("${runbookName}: no '$GlanceHeading' section")
                    continue
                }
                $problem = Get-TableProblem $glance 'At a Glance'
                if ($problem) {
                    [void]$problems.Add("${runbookName}: $problem")
                    continue
                }
                $glanceRows = @{}
                foreach ($row in ($glance.Rows | Select-Object -Skip 2)) {
                    $cells = Split-TableRow $row
                    $glanceRows[$cells[0]] = $cells
                }
                if ($glanceRows.Count -eq 0) {
                    [void]$problems.Add("${runbookName}: the At a Glance table has no rows")
                }
                foreach ($id in $glanceRows.Keys) {
                    if (-not $seen.ContainsKey($id)) {
                        [void]$problems.Add("${name}: $id is in the runbook but has no status row")
                    }
                    elseif ($seen[$id][1] -cne $glanceRows[$id][1] -or $seen[$id][2] -cne $glanceRows[$id][2]) {
                        [void]$problems.Add("${name}: $id has a different Kind or Where in the runbook")
                    }
                }
                foreach ($id in $seen.Keys) {
                    if (-not $glanceRows.ContainsKey($id)) {
                        [void]$problems.Add("${name}: $id has a status row but is not in the runbook")
                    }
                }
                $stepIds = Get-StepsSectionIds $runbookLines
                foreach ($id in $stepIds.Keys) {
                    if (-not $glanceRows.ContainsKey($id)) {
                        [void]$problems.Add("${runbookName}: $id is in the Steps section but not in At a Glance")
                    }
                }
                foreach ($id in $glanceRows.Keys) {
                    if (-not $stepIds.ContainsKey($id)) {
                        [void]$problems.Add("${runbookName}: $id is in At a Glance but not in the Steps section")
                    }
                }
            }
        }
    }
}

$filtered = @($steps | Where-Object {
    (-not $Where -or $_.Where -like "*$Where*") -and (-not $Kind -or $_.Kind -eq $Kind)
})
$isFiltered = [bool]($Where -or $Kind)

Write-Output "# Open runbook steps: $Scope"
Write-Output ''
if ($filtered.Count -eq 0) {
    Write-Output 'No open steps match.'
    Write-Output ''
}
else {
    Write-Output "Open steps: $($filtered.Count). Tasks: $(@($filtered | Select-Object -ExpandProperty Task -Unique).Count). Oldest task first."
    Write-Output ''
    foreach ($group in ($filtered | Group-Object Where | Sort-Object Name)) {
        Write-Output "## $($group.Name) ($($group.Count))"
        Write-Output ''
        Write-Output '| Task | ID | Kind | What | State | Note |'
        Write-Output '|------|----|------|------|-------|------|'
        foreach ($step in ($group.Group | Sort-Object Task, Order)) {
            $href = ConvertTo-Href $step.Link.FullName
            Write-Output "| [$($step.Task)]($href) | $($step.Id) | $($step.Kind) | $(ConvertTo-Cell $step.What) | $($step.State) | $(ConvertTo-Cell $step.Note) |"
        }
        Write-Output ''
    }
}
if ($isFiltered) {
    $others = @($steps | Where-Object { $filtered -notcontains $_ })
    if ($others.Count -gt 0) {
        $otherWhere = (@($others | Select-Object -ExpandProperty Where -Unique | Sort-Object) -join ', ')
        $otherKind = (@($others | Select-Object -ExpandProperty Kind -Unique | Sort-Object) -join ', ')
        Write-Output "Not shown by this filter: $($others.Count) open steps. Where: $otherWhere. Kind: $otherKind."
        Write-Output ''
    }
    if ($planned.Count -gt 0) {
        Write-Output "Not shown by this filter: $($planned.Count) planned runbooks, whose steps have no status yet."
        Write-Output ''
    }
}
elseif ($planned.Count -gt 0) {
    Write-Output '## Planned, no status yet'
    Write-Output ''
    foreach ($item in ($planned | Sort-Object Task)) {
        Write-Output "- [$($item.Task)]($(ConvertTo-Href $item.Runbook.FullName))"
    }
    Write-Output ''
}
foreach ($problem in $problems) {
    Write-Output "ERROR: $problem"
}
if ($problems.Count -gt 0) { exit 1 }
exit 0
