param(
    [string]$ProjectRoot = ".",
    [string]$AddonFolder = "CombatMode",
    [string]$TocFile = "CombatMode.toc",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"

$addonPath = Join-Path $ProjectRoot $AddonFolder
$tocPath = Join-Path $addonPath $TocFile

if (-not (Test-Path $tocPath)) {
    throw "TOC not found: $tocPath"
}

# Expected line format: ## Version: x.y.z
$versionLine = Get-Content $tocPath | Where-Object {
    $_ -match '^\s*##\s*Version\s*:\s*(.+?)\s*$'
} | Select-Object -First 1

if (-not $versionLine) {
    throw "Could not find '## Version:' in $tocPath"
}

$version = ([regex]::Match($versionLine, '^\s*##\s*Version\s*:\s*(.+?)\s*$')).Groups[1].Value.Trim()

if (-not $version) {
    throw "Parsed empty version from TOC."
}

$outPathDir = Join-Path $ProjectRoot $OutputDir
New-Item -ItemType Directory -Path $outPathDir -Force | Out-Null

$zipName = "${AddonFolder}_v${version}.zip"
$zipPath = Join-Path $outPathDir $zipName

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Include top-level addon folder in archive output.
Compress-Archive -Path $addonPath -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "Created: $zipPath"
