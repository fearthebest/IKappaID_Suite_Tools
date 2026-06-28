# Mirror repo root -> %UserProfile%\Zomboid\Workshop\IKappaID Suite Tools
# Use this folder in the Steam Workshop uploader (Project Zomboid).
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path $PSScriptRoot -Parent
$Src = $RepoRoot
$Dst = Join-Path $env:USERPROFILE "Zomboid\Workshop\IKappaID Suite Tools"

if (-not (Test-Path (Join-Path $Src "Contents"))) {
    Write-Error "Missing Contents folder in repo root"
}

$workshopParent = Split-Path $Dst -Parent
if (-not (Test-Path $workshopParent)) {
    New-Item -ItemType Directory -Path $workshopParent -Force | Out-Null
}

if (Test-Path $Dst) {
    Remove-Item $Dst -Recurse -Force
}

New-Item -ItemType Directory -Path $Dst -Force | Out-Null
Write-Host "Mirror repo root -> $Dst"

# Copy Workshop files only (exclude repo artifacts)
& robocopy $Src $Dst "workshop.txt" "preview.png" /NFL /NDL /NJH /NJS /NC /NS | Out-Null
& robocopy (Join-Path $Src "Contents") (Join-Path $Dst "Contents") /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
if ($LASTEXITCODE -ge 8) {
    Write-Error "robocopy failed (exit $LASTEXITCODE)"
}

Get-ChildItem (Join-Path $Dst "Contents\mods") -Directory | ForEach-Object {
    $stub = Join-Path $_.FullName "42.19"
    if (Test-Path $stub) {
        Write-Host "Remove 42.19 stub: $($_.Name)"
        Remove-Item $stub -Recurse -Force
    }
    $buildTxt = Join-Path $_.FullName "SANDBOX_BUILD.txt"
    if (Test-Path $buildTxt) {
        Write-Host "Remove dev artifact: $($_.Name)/SANDBOX_BUILD.txt"
        Remove-Item $buildTxt -Force
    }
}

$enforceMd = Join-Path $Dst "ENFORCEMENT.md"
if (Test-Path $enforceMd) {
    Write-Host "Remove dev doc: ENFORCEMENT.md"
    Remove-Item $enforceMd -Force
}

Write-Host "Done. Open Steam Workshop uploader and point at:"
Write-Host "  $Dst"
