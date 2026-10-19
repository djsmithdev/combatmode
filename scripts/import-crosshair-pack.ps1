<#
.SYNOPSIS
  One-off importer: crosshair pack (PNG) -> addon TGAs.

.DESCRIPTION
  Reads crosshair-NNN.png from the pack's "Glow (2x)" folder (148x148 white glyphs with alpha),
  resamples each to 128x128 (the canvas size the reticle textures use) and writes an
  uncompressed 32-bit top-left TGA (same format as the other shipped TGAs) to
  CombatMode/Assets/crosshair/pack/crosshair-NNN.tga. Repo tooling only; never ships.

.PARAMETER Source
  Folder holding crosshair-NNN.png (e.g. ...\crosshair-pack\PNG\Glow (2x)).

.PARAMETER Size
  Output edge in pixels. Must be a power of two for WoW. Default 128.
#>
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [int]$Size = 128
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $repoRoot "CombatMode/Assets/crosshair/pack"
New-Item -ItemType Directory -Force $outDir | Out-Null

Add-Type -AssemblyName System.Drawing

function Convert-ToTga([string]$pngPath, [string]$tgaPath, [int]$size) {
  $src = New-Object System.Drawing.Bitmap($pngPath)
  $dst = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $g = [System.Drawing.Graphics]::FromImage($dst)
    try {
      $g.Clear([System.Drawing.Color]::Transparent)
      $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
      $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $attrs = New-Object System.Drawing.Imaging.ImageAttributes
      # Flip-wrap so the bicubic kernel does not pull in transparent edge pixels.
      $attrs.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
      $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
      $g.DrawImage($src, $rect, 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel, $attrs)
      $attrs.Dispose()
    } finally {
      $g.Dispose()
    }

    $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $data = $dst.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $pixels = New-Object byte[] ($size * $size * 4)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $pixels, 0, $pixels.Length)
    $dst.UnlockBits($data)

    $header = New-Object byte[] 18
    $header[2] = 2                  # uncompressed true-color
    $header[12] = $size -band 0xFF
    $header[13] = $size -shr 8
    $header[14] = $size -band 0xFF
    $header[15] = $size -shr 8
    $header[16] = 32                # bits per pixel
    $header[17] = 0x28              # 8 alpha bits, top-left origin

    $all = New-Object byte[] ($header.Length + $pixels.Length)
    [Array]::Copy($header, 0, $all, 0, $header.Length)
    [Array]::Copy($pixels, 0, $all, $header.Length, $pixels.Length) # GDI+ BGRA == TGA BGRA
    [System.IO.File]::WriteAllBytes($tgaPath, $all)
  } finally {
    $src.Dispose()
    $dst.Dispose()
  }
}

$files = Get-ChildItem -LiteralPath $Source -Filter "crosshair-*.png" | Sort-Object Name
if ($files.Count -eq 0) {
  throw "No crosshair-*.png found in $Source"
}
foreach ($f in $files) {
  Convert-ToTga $f.FullName (Join-Path $outDir ($f.BaseName + ".tga")) $Size
}
Write-Host "Wrote $($files.Count) TGAs ($Size x $Size) to $outDir"
