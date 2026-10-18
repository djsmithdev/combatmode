# Launches the wow-api MCP server (wow-api-mcp) against the Ketho "WoW API" VS Code extension annotations.
# Search order: WOW_API_EXT_PATH (already set) -> ~/.vscode/extensions -> ~/.cursor/extensions.
param()

$ErrorActionPreference = "Stop"

if (-not $env:WOW_API_EXT_PATH) {
    $ext = $null
    foreach ($dir in @(".vscode", ".cursor")) {
        $base = Join-Path $env:USERPROFILE "$dir\extensions"
        if (Test-Path -LiteralPath $base) {
            $ext = Get-ChildItem -Path $base -Directory -Filter "ketho.wow-api-*" |
                Sort-Object Name -Descending | Select-Object -First 1
            if ($ext) { break }
        }
    }
    if (-not $ext) {
        throw "ketho.wow-api extension not found. Install the 'WoW API' VS Code extension (ketho.wow-api) or set WOW_API_EXT_PATH to its folder."
    }
    $env:WOW_API_EXT_PATH = $ext.FullName
}

npx.cmd -y wow-api-mcp
