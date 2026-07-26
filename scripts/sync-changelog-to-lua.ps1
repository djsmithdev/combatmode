# scripts/sync-changelog-to-lua.ps1
# Overwrites CombatMode/UI/Changelog/ChangelogData.lua (CM.Config.ChangelogText) from CombatMode/CHANGELOG.md.
# WoW cannot read .md at runtime; the Lua string is what ChangelogPanel.lua displays.
# VS Code: task "Sync CHANGELOG.md to ChangelogData.lua".
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$mdPath = Join-Path $ProjectRoot "CombatMode\CHANGELOG.md"
$luaPath = Join-Path $ProjectRoot "CombatMode\UI\Changelog\ChangelogData.lua"

if (-not (Test-Path $mdPath)) {
    throw "CHANGELOG.md not found: $mdPath"
}

$md = [System.IO.File]::ReadAllText($mdPath, [System.Text.UTF8Encoding]::new($false))

function Get-LuaLongStringDelimiters([string]$content) {
    $n = 0
    while ($true) {
        $close = "]" + ("=" * $n) + "]"
        if (-not $content.Contains($close)) {
            break
        }
        $n++
    }
    $open = "[" + ("=" * $n) + "["
    return @{
        Open  = $open
        Close = $close
    }
}

$d = Get-LuaLongStringDelimiters $md
$body = $d.Open + "`n" + $md + $d.Close

$lua = @"
---------------------------------------------------------------------------------------
--  UI/Changelog/ChangelogData.lua - changelog body for in-game viewer
--  Regenerate from CHANGELOG.md:  scripts\sync-changelog-to-lua.ps1
---------------------------------------------------------------------------------------
local _G = _G
local CM = _G.CM

CM.Config = CM.Config or {}
CM.Config.ChangelogText = $body

"@

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($luaPath, $lua, $utf8NoBom)

Write-Host "Wrote $luaPath from $mdPath"
