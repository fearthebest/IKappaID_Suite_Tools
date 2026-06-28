# Deploy IKST 0.2.6 from IKST_Workshop to local Steam Workshop install.
# Removes broken 42.19/ stub folders (sandbox-only) so B42.19 clients load 42.18/ Lua.
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path $PSScriptRoot -Parent
$SrcRoot = Join-Path $RepoRoot "IKST_Workshop\Contents\mods"

$SteamRoots = @(
    "B:\SteamLibrary\steamapps\workshop\content\108600\3750835193\mods",
    "C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3750835193\mods"
)

$DstRoot = $SteamRoots | Where-Object { Test-Path (Split-Path $_ -Parent) } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $DstRoot) {
    $parent = $SteamRoots[0] | Split-Path -Parent
    if (Test-Path (Split-Path $parent -Parent)) {
        Write-Error "Steam Workshop IKST mods folder not found. Subscribe to 3750835193 and wait for download."
    }
    Write-Error "Steam library not found at B: or C:."
}

$ModIds = @(
    "IKappaIDSuiteTools",
    "IKappaIDSuiteToolsEconomy",
    "IKappaIDSuiteToolsLoot",
    "IKappaIDSuiteToolsTiles",
    "IKappaIDSuiteToolsVehicles"
)

foreach ($modId in $ModIds) {
    $src418 = Join-Path $SrcRoot "$modId\42.18"
    $dstMod = Join-Path $DstRoot $modId
    $dst418 = Join-Path $dstMod "42.18"
    $dst419 = Join-Path $dstMod "42.19"
    $bootstrap = Join-Path $src418 "media\lua\client\IKST_Z_Bootstrap.lua"
    $hasLua = (Test-Path $bootstrap) -or (Test-Path (Join-Path $src418 "media\lua"))
    if (-not $hasLua) {
        Write-Error "Missing 42.18 media/lua for $modId"
    }

    if (Test-Path $dst419) {
        Write-Host "Remove broken 42.19 stub: $modId"
        Remove-Item $dst419 -Recurse -Force
    }

    if (Test-Path $dst418) {
        Remove-Item $dst418 -Recurse -Force
    }

    Write-Host "Deploy $modId 42.18 -> Steam"
    & robocopy $src418 $dst418 /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
    if ($LASTEXITCODE -ge 8) {
        Write-Error "robocopy failed for $modId (exit $LASTEXITCODE)"
    }

    # Root + common mod.info if present in source tree
    foreach ($leaf in @("", "common")) {
        $srcInfo = Join-Path $SrcRoot "$modId$([IO.Path]::DirectorySeparatorChar)$leaf\mod.info"
        if ($leaf -eq "") { $srcInfo = Join-Path $SrcRoot "$modId\mod.info" }
        if (Test-Path $srcInfo) {
            $dstInfo = if ($leaf -eq "common") { Join-Path $dstMod "common\mod.info" } else { Join-Path $dstMod "mod.info" }
            $dstDir = Split-Path $dstInfo -Parent
            if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
            Copy-Item $srcInfo $dstInfo -Force
        }
    }
}

Write-Host ""
Write-Host "IKST 0.2.6 deployed to: $DstRoot"
Write-Host "Restart PZ. console.txt should show:"
Write-Host '  [IKST] IKappaID Suite Tools v0.2.6 loaded (client)'
