# Runs the pre-commit gate (StyLua, Selene, check-repo) on changed + new addon Lua files.
# Run it twice after edits: the first pass reformats.
param()

$ErrorActionPreference = "Stop"

function Get-ChangedFiles {
    $staged = git diff --name-only --cached 2>$null
    $unstaged = git diff --name-only 2>$null
    $untracked = git ls-files --others --exclude-standard 2>$null

    $all = @()
    if ($staged) { $all += $staged }
    if ($unstaged) { $all += $unstaged }
    if ($untracked) { $all += $untracked }

    return $all | Sort-Object -Unique
}

Write-Host "== CombatMode lint-changed =="

$changed = Get-ChangedFiles

if (-not $changed -or $changed.Count -eq 0) {
    Write-Host "[PASS] No changed files detected."
    exit 0
}

$luaTargets = $changed | Where-Object {
    $_ -match '^CombatMode/.+\.lua$'
}

if (-not $luaTargets -or $luaTargets.Count -eq 0) {
    Write-Host "[PASS] No changed addon Lua files to lint."
    exit 0
}

Write-Host "[INFO] Running pre-commit on changed Lua files:"
$luaTargets | ForEach-Object { Write-Host "  - $_" }

pre-commit run --files @luaTargets
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Error "pre-commit failed for changed files."
    exit $exitCode
}

Write-Host "[PASS] pre-commit passed for changed Lua files."
exit 0
