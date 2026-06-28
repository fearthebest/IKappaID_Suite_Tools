# Package IKST Workshop tree for dedicated server upload (Indifferent Broccoli / self-host).
# Run from repo: scripts\package_ikst_server.ps1
# Output: Desktop\IKST_ServerUpload.zip (all Contents/mods + workshop.txt)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path $PSScriptRoot -Parent
$Src = Join-Path $RepoRoot "IKST_Workshop"
$OutZip = Join-Path $env:USERPROFILE "Desktop\IKST_ServerUpload.zip"

if (-not (Test-Path $Src)) {
    Write-Error "Missing IKST_Workshop at $Src"
}

$mods = Join-Path $Src "Contents\mods"
if (-not (Test-Path $mods)) {
    Write-Error "Missing Contents\mods"
}

if (Test-Path $OutZip) {
    Remove-Item $OutZip -Force
}

$staging = Join-Path $env:TEMP "IKST_ServerUpload"
if (Test-Path $staging) {
    Remove-Item $staging -Recurse -Force
}
New-Item -ItemType Directory -Path $staging -Force | Out-Null

Copy-Item (Join-Path $Src "workshop.txt") $staging -ErrorAction SilentlyContinue
Copy-Item $mods (Join-Path $staging "mods") -Recurse

Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $OutZip -Force
Remove-Item $staging -Recurse -Force

Write-Host "Created: $OutZip"
Write-Host ""
Write-Host "Dedicated server steps:"
Write-Host "  1. Upload/extract to host mods folder (same layout as Workshop Contents\mods)."
Write-Host "  2. Enable ALL IKST addons in server Mods list (base + Tiles + Vehicles + Loot + Economy if used)."
Write-Host "  3. Match load order to your client ModLoadOrder.txt."
Write-Host "  4. Restart server (full process restart, not just reload)."
Write-Host "  5. In-game: /setaccesslevel YourName admin  (staff tools require server-side admin)."
Write-Host "  6. Join and check server log for: [IKST] ... loaded (server) and Arrival grace started"
