param()

$ErrorActionPreference = "Stop"

function Test-Tool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,
        [string]$VersionArgs = "--version"
    )

    try {
        $cmd = Get-Command $CommandName -ErrorAction Stop
        $version = & $cmd.Source $VersionArgs 2>$null | Select-Object -First 1
        if (-not $version) { $version = "(version output unavailable)" }
        Write-Host "[PASS] $CommandName found: $version"
        return $true
    }
    catch {
        Write-Host "[FAIL] $CommandName not found on PATH"
        return $false
    }
}

function Test-FileExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path $Path) {
        Write-Host "[PASS] Found: $Path"
    }
    else {
        Write-Host "[FAIL] Missing: $Path"
    }
}

Write-Host "== CombatMode dev environment check =="

$allToolsOk = $true
$allToolsOk = (Test-Tool -CommandName "stylua") -and $allToolsOk
$allToolsOk = (Test-Tool -CommandName "selene") -and $allToolsOk
$allToolsOk = (Test-Tool -CommandName "pre-commit") -and $allToolsOk

Write-Host ""
Write-Host "== Required config files =="
Test-FileExists -Path "selene.toml"
Test-FileExists -Path "stylua.toml"
Test-FileExists -Path ".pre-commit-config.yaml"

Write-Host ""
Write-Host "== Optional MCP check =="
if (Test-Path ".cursor/mcp.json") {
    Write-Host "[PASS] Found .cursor/mcp.json"
}
else {
    Write-Host "[WARN] .cursor/mcp.json not found (MCP optional for local lint/format)"
}

if (-not $allToolsOk) {
    Write-Error "One or more required tools are missing from PATH."
    exit 1
}

Write-Host ""
Write-Host "[PASS] Required local tools are available."
exit 0
