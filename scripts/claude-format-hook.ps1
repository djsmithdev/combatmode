# Claude Code PostToolUse hook: run StyLua on an edited addon Lua file (replaces format-on-save).
# Reads the hook JSON from stdin; silently does nothing for non-Lua files, vendored Libs/, or when stylua is missing.
param()

$ErrorActionPreference = "SilentlyContinue"

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }

try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }
$path = $payload.tool_input.file_path
if (-not $path) { exit 0 }

$normalized = $path -replace '\\', '/'
if ($normalized -notmatch '/CombatMode/.+\.lua$' -or $normalized -match '/CombatMode/Libs/') { exit 0 }
if (-not (Test-Path -LiteralPath $path)) { exit 0 }
if (-not (Get-Command stylua -ErrorAction SilentlyContinue)) { exit 0 }

$repoRoot = Split-Path -Parent $PSScriptRoot
stylua --config-path (Join-Path $repoRoot "stylua.toml") -- $path 2>$null
exit 0
