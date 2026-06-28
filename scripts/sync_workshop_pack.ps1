# Sync IKST_Workshop -> Workshop/IKappaID Suite Tools for Steam upload / Zomboid\Workshop copy.
# 0.2.6: no 42.19/ stubs — only 42.18/ + root/common mod.info per addon.
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path $PSScriptRoot -Parent
$Src = Join-Path $RepoRoot "IKST_Workshop"
$Dst = Join-Path $RepoRoot "Workshop\IKappaID Suite Tools"

if (-not (Test-Path $Src)) {
    Write-Error "Missing IKST_Workshop"
}

if (Test-Path $Dst) {
    Remove-Item $Dst -Recurse -Force
}

New-Item -ItemType Directory -Path $Dst -Force | Out-Null
Write-Host "Mirror IKST_Workshop -> Workshop pack"
& robocopy $Src $Dst /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
if ($LASTEXITCODE -ge 8) {
    Write-Error "robocopy failed (exit $LASTEXITCODE)"
}

# Ensure no 42.19 stubs in pack
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

Write-Host "Done: $Dst"
