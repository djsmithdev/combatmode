param()

$ErrorActionPreference = "Stop"

function Get-ChangedFiles {
    $staged = git diff --name-only --cached 2>$null
    $unstaged = git diff --name-only 2>$null

    $all = @()
    if ($staged) { $all += $staged }
    if ($unstaged) { $all += $unstaged }

    return $all | Sort-Object -Unique
}

Write-Host "== CombatMode lint-changed =="

$changed = Get-ChangedFiles

if (-not $changed -or $changed.Count -eq 0) {
    Write-Host "[PASS] No changed files detected."
    exit 0
}

$luaTargets = $changed | Where-Object {
    $_ -match '^CombatMode/.+\.lua$' -and $_ -notmatch '^CombatMode/Libs/'
}

if (-not $luaTargets -or $luaTargets.Count -eq 0) {
    Write-Host "[PASS] No changed addon-owned Lua files to lint."
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
