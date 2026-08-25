$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot

Write-Host "=================================================="
Write-Host " Syncing SharedAgentSkills"
Write-Host "=================================================="

# 1. Fast-forward pull
Write-Host "Pulling latest changes (fast-forward only)..."
git -C $repoRoot pull --ff-only
if ($LASTEXITCODE -ne 0) {
    Write-Error "git pull failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

# 2. Run setup to re-verify junctions and refresh inlined rules
Write-Host "`nRunning setup.ps1 to refresh configuration and junctions..."
& (Join-Path $repoRoot 'setup.ps1')
