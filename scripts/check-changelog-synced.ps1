# Fails when CombatMode/UI/Changelog/ChangelogData.lua is out of date with CombatMode/CHANGELOG.md.
# Used by the pre-commit hook "changelog-synced"; fix with: pwsh ./scripts/sync-changelog-to-lua.ps1
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$mdPath = Join-Path $ProjectRoot "CombatMode\CHANGELOG.md"
$luaPath = Join-Path $ProjectRoot "CombatMode\UI\Changelog\ChangelogData.lua"
if (-not (Test-Path $mdPath) -or -not (Test-Path $luaPath)) {
    Write-Error "CHANGELOG.md or ChangelogData.lua not found."
    exit 1
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("acm-changelog-" + [guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Path (Join-Path $tmp "CombatMode\UI\Changelog") -Force | Out-Null
    Copy-Item $mdPath (Join-Path $tmp "CombatMode\CHANGELOG.md")
    & (Join-Path $PSScriptRoot "sync-changelog-to-lua.ps1") -ProjectRoot $tmp | Out-Null

    $expected = [System.IO.File]::ReadAllText((Join-Path $tmp "CombatMode\UI\Changelog\ChangelogData.lua")) -replace "`r`n", "`n"
    $actual = [System.IO.File]::ReadAllText($luaPath) -replace "`r`n", "`n"
    if ($expected -ne $actual) {
        Write-Host "[FAIL] ChangelogData.lua is out of sync with CHANGELOG.md. Run: pwsh ./scripts/sync-changelog-to-lua.ps1 and stage the result."
        exit 1
    }
    Write-Host "[PASS] ChangelogData.lua matches CHANGELOG.md."
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
