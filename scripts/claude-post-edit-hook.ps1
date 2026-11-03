# Claude Code PostToolUse hook (Edit|Write), wired in .claude/settings.json:
#   - addon Lua (CombatMode/**.lua): format with StyLua (replaces format-on-save)
#   - CombatMode/CHANGELOG.md: regenerate UI/Changelog/ChangelogData.lua (scripts/sync-changelog-to-lua.ps1)
# Reads the hook JSON from stdin; silently does nothing for other files or when a tool is missing.
param()

$ErrorActionPreference = "SilentlyContinue"

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }

try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }
$path = $payload.tool_input.file_path
if (-not $path -or -not (Test-Path -LiteralPath $path)) { exit 0 }

$normalized = $path -replace '\\', '/'
$repoRoot = Split-Path -Parent $PSScriptRoot

if ($normalized -match '/CombatMode/CHANGELOG\.md$') {
    & (Join-Path $PSScriptRoot "sync-changelog-to-lua.ps1") *> $null
    exit 0
}

if ($normalized -match '/CombatMode/.+\.lua$' -and $normalized -notmatch '/UI/Changelog/ChangelogData\.lua$') {
    if (Get-Command stylua -ErrorAction SilentlyContinue) {
        stylua --config-path (Join-Path $repoRoot "stylua.toml") -- $path 2>$null
    }
}
exit 0
