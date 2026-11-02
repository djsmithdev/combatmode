# Repo consistency checks, run by the pre-commit hook "check-repo" (so locally and in CI).
#   pwsh ./scripts/check-repo.ps1            everyday checks
#   pwsh ./scripts/check-repo.ps1 -Release   also the release gate (PRs into master, release.yml)
# Each check prints [PASS] / [WARN] / [FAIL]; any FAIL exits 1.
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Release
)

$ErrorActionPreference = "Stop"
$script:failed = $false
$addon = Join-Path $ProjectRoot "CombatMode"

function Pass([string]$msg) { Write-Host "[PASS] $msg" }
function Warn([string]$msg) { Write-Host "[WARN] $msg" }
function Fail([string]$msg) { Write-Host "[FAIL] $msg"; $script:failed = $true }
function Read-Text([string]$path) { [System.IO.File]::ReadAllText($path) -replace "`r`n", "`n" }

# --- Changelog viewer copy -------------------------------------------------------------
# ChangelogData.lua must be exactly what sync-changelog-to-lua.ps1 writes from CHANGELOG.md.
$mdPath = Join-Path $addon "CHANGELOG.md"
$luaPath = Join-Path $addon "UI\Changelog\ChangelogData.lua"
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("acm-changelog-" + [guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Path (Join-Path $tmp "CombatMode\UI\Changelog") -Force | Out-Null
    Copy-Item $mdPath (Join-Path $tmp "CombatMode\CHANGELOG.md")
    & (Join-Path $PSScriptRoot "sync-changelog-to-lua.ps1") -ProjectRoot $tmp *> $null
    $expected = Read-Text (Join-Path $tmp "CombatMode\UI\Changelog\ChangelogData.lua")
    if ((Test-Path $luaPath) -and $expected -eq (Read-Text $luaPath)) {
        Pass "ChangelogData.lua matches CHANGELOG.md"
    }
    else {
        Fail "ChangelogData.lua is out of sync. Run: pwsh ./scripts/sync-changelog-to-lua.ps1"
    }
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Version: TOC vs newest changelog section ------------------------------------------
$toc = Read-Text (Join-Path $addon "CombatMode.toc")
$md = Read-Text $mdPath
$tocVersion = [regex]::Match($toc, '(?m)^## Version:\s*(\S+)').Groups[1].Value
$section = [regex]::Match($md, '(?m)^## \[v?([^\]]+)\](?:\s*-\s*(\d{4}-\d{2}-\d{2}))?')
$mdVersion = $section.Groups[1].Value
if (-not $tocVersion) {
    Fail "No '## Version:' in CombatMode.toc"
}
elseif ($tocVersion -ne $mdVersion) {
    Fail "TOC version $tocVersion does not match the newest CHANGELOG.md section [$mdVersion]"
}
else {
    Pass "TOC version $tocVersion matches the newest CHANGELOG.md section"
}
$hasLink = $md -match ('(?m)^\[' + [regex]::Escape($tocVersion) + '\]:\s*https://')
if ($hasLink) { Pass "CHANGELOG.md has a compare link for [$tocVersion]" }
elseif ($Release) { Fail "CHANGELOG.md has no compare link '[$tocVersion]: https://...' at the bottom" }
else { Warn "CHANGELOG.md has no compare link for [$tocVersion] yet (required to release)" }

# --- Load order: Embeds.xml <-> files on disk ------------------------------------------
$referenced = New-Object System.Collections.Generic.HashSet[string]([StringComparer]::OrdinalIgnoreCase)
$missing = @()
foreach ($xmlName in @("Embeds.xml", "Bindings.xml")) {
    $xmlPath = Join-Path $addon $xmlName
    if (-not (Test-Path $xmlPath)) { continue }
    foreach ($m in [regex]::Matches((Read-Text $xmlPath), '<(?:Script|Include)\s+file="([^"]+)"')) {
        $rel = $m.Groups[1].Value -replace '\\', '/'
        [void]$referenced.Add($rel)
        if (-not (Test-Path -LiteralPath (Join-Path $addon $rel))) { $missing += "$xmlName -> $rel" }
    }
}
foreach ($line in ($toc -split "`n")) {
    $entry = $line.Trim()
    if ($entry -and -not $entry.StartsWith("#")) {
        $rel = $entry -replace '\\', '/'
        [void]$referenced.Add($rel)
        if (-not (Test-Path -LiteralPath (Join-Path $addon $rel))) { $missing += "CombatMode.toc -> $rel" }
    }
}
$unloaded = Get-ChildItem -Path $addon -Recurse -File -Filter *.lua | ForEach-Object {
    [System.IO.Path]::GetRelativePath($addon, $_.FullName) -replace '\\', '/'
} | Where-Object { -not $referenced.Contains($_) }
if ($missing) { $missing | ForEach-Object { Fail "Load order references a missing file: $_" } }
if ($unloaded) { $unloaded | ForEach-Object { Fail "Not loaded by Embeds.xml or the TOC: CombatMode/$_" } }
if (-not $missing -and -not $unloaded) { Pass "Embeds.xml / TOC load every addon Lua file, and every listed file exists" }

# --- LICENSE copies --------------------------------------------------------------------
# The root copy is what GitHub shows; CombatMode/LICENSE is the one the packager ships.
if ((Read-Text (Join-Path $ProjectRoot "LICENSE")) -eq (Read-Text (Join-Path $addon "LICENSE"))) {
    Pass "LICENSE and CombatMode/LICENSE are identical"
}
else {
    Fail "LICENSE and CombatMode/LICENSE differ; keep them identical"
}

# --- Shipped TGAs are RLE-compressed ---------------------------------------------------
$python = @("python3", "python") | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Select-Object -First 1
if ($python) {
    $out = & $python (Join-Path $PSScriptRoot "art\compress-tga.py") --check 2>&1
    if ($LASTEXITCODE -eq 0) { Pass "Shipped TGAs are compressed" }
    else {
        $out | Where-Object { $_ -match 'needs compressing|FAILED' } | ForEach-Object { Write-Host "       $_" }
        Fail "Some TGAs are not RLE-compressed. Run: python scripts/art/compress-tga.py"
    }
}
else {
    Warn "Python not found; skipped the TGA compression check"
}

# --- Release gate ----------------------------------------------------------------------
if ($Release) {
    if (-not $section.Groups[2].Value) {
        Fail "CHANGELOG.md section [$mdVersion] has no date ('## [x.y.z] - YYYY-MM-DD')"
    }
    $tags = @(git -C $ProjectRoot tag --list 2>$null | ForEach-Object {
            $v = $null
            if ([version]::TryParse(($_ -replace '^v', ''), [ref]$v)) { $v }
        } | Sort-Object -Descending)
    $current = $null
    if (-not [version]::TryParse($tocVersion, [ref]$current)) {
        Fail "TOC version '$tocVersion' is not x.y.z"
    }
    elseif ($tags.Count -eq 0) {
        Warn "No version tags found (shallow clone?); skipped the version bump check"
    }
    elseif ($current -le $tags[0]) {
        Fail "TOC version $tocVersion is not newer than the latest tag $($tags[0]); bump it before releasing"
    }
    else {
        Pass "TOC version $tocVersion is newer than the latest tag $($tags[0])"
    }
}

if ($script:failed) { exit 1 }
exit 0
