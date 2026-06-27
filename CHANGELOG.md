# IKappaID Suite Tools — Changelog

## 0.2.5 (2026-06-27)

### Security & Stability release (Tier C hardening)

- **Dedicated Server:** Fixed startup error by moving `IKST_TransferGuard` to `client/` (no TimedActions on headless JVM).
- **Locks:** Passwords server-only; clients sync `IKST_LocksPublic` locked flags only (no plaintext passwords in ModData).
- **Economy:** ATM/bank ops require player proximity; full economy store no longer transmitted to MP clients (per-player snapshot cache).
- **Claims:** Vehicle and safehouse claim require proximity for non-admin players.
- **Utilities:** `setUtilityOn` no-op on MP remote client; server `quickWater`/`quickPower` only.
- **ServerGate:** Extended `IKST_Args` validation for locks, economy, claims, vehicle IDs.
- **Tiles:** Lock player commands require `playerClaimsEnabled`.
- **Dev:** Server JVM guards on all `server/*.lua` files; removed dead `playerMayRunCommand` and economy throttle.

## 0.2.3 (2026-06-25)

### Economy tiles (World Edit addon)
- Custom **ikst_economy_01** tileset: Blender-rendered **ATM** (payment kiosk) and **shop** (vending machine) sprites with four facings.
- Economy addon recognizes `ikst_economy_01_0`–`_3` as ATMs and `_4`–`_7` as player shops when placed on the map (vanilla bank/vending sprites still supported).
- Import pipeline: inverted Blender export names (`shop_*` → ATM, `atm_*` → shop), JPEG backdrop stripping, facing anchor alignment.

### Economy + PhoneShop (soft coupling)
- `IKST_Economy.isEconomyActive()` — sandbox + PhoneShop cash provider; no `mod.info` require on PhoneShop.
- `IKST_EconomyBridge` uses PhoneShop `getCashOnly` / `payCashOnly` / `giveCashOnly` (no API recursion).
- PhoneShop (1.0.4+) delegates buy/afford/pay to Economy when both are active; payouts stay physical cash.

### Loot addon (IKappaIDSuiteToolsLoot)
- New optional addon: repopulate world containers with vanilla `ItemPicker.fillContainer` distributions.
- IKST hub **Loot** job: scopes (single tile, radius, room, building), **At my feet**, click-ground arm mode.
- World context menu: per-container repopulate + all containers on square.
- Server-authoritative in MP; skips player inv and floor; multi-container objects supported.
- Clears room procedural spawn tracker once per batch before refill.
- Sandbox: `LootMaxContainers` (default 80, max 500), `LootClearBeforeFill` (default true).
- Admin/host tools access only (`canUseLoot`).

### Sandbox expansion
- Claims: whitelist-only mode, named players, max whitelist, owners grant extra slots, group editing, vehicle/safehouse guest/mate permissions.
- Economy, Tiles, Vehicles: additional sandbox options.

### Fixes & hardening
- Economy: `exchangeAll` stack counts; unclaimed shop terminal loot block; `persistStore()` after tax/wire fees; ATM tile list includes `ikst_economy_01_0`.
- Claims: expired safehouse denies access; purge clears ModData + meta; `ISEnterVehicle` → `"enter"` permission.
- Transfers: `IKST_TransferRules` + client `IKST_TransferGuard` (SP/listen-host); vehicle checks in `IKST_ContainerRules`.
- Tiles: protect on batch cleanup + paint; claim protect on paint/batch.
- Case-insensitive owner/whitelist; claim UI whitelist hints.

### Notes
- Tile facing alignment is approximate; a future update may refine iso angles or art.
- After updating tiles locally, rebuild `ikst_suite.pack` in TileZed from `pack-src\` before uploading.
- Steam paste: `STEAM-CHANGELOG-0.2.3.txt`

## 0.2.2 (2026-06-24)

### Safehouses
- **Release fix:** use vanilla `SafeHouse:removeSafeHouse(player[, force])` instead of invalid static `SafeHouse.removeSafeHouse(sh)` (fixes MP `SafehouseRelease` / `safehouse not found` errors).
- **Legacy claims:** backfill `IKST_SafehouseClaim` ModData for safehouses created before IKST permissions; improved lookup by `getId()`, player position, and owner.
- **PhunZones 2:** respect zone `nosafehouse` when claiming (same rule as PhunZones vanilla hook).
- **API hardening:** new `IKST_SafeHouse.lua` wrapper; MP rect claims use `addSafeHouse(..., remote=true)`; server blocks weather commands that cannot sync in MP.

### Other (0.2.2)
- Vehicle lookup tries `getVehicleById` and `getVehicleByID`.

## 0.2.1 (2026-06-21)

### Multiplayer
- **Water / power:** Client-only toggle via `SandboxOptions:sendToServer()` (WPControl pattern); updates `SandboxVars` for UI.
- **Listen host:** `dispatchCommand` routes world edits to the server JVM instead of running on the client JVM.
- **Results / inspect / lists:** Server replies use `deliverClientCommand` so listen-host and co-op clients receive notifications.
- **ModData:** Re-transmit all synced keys on game start and player connect; waypoints included in sync layer.
- **Economy bank:** Mutations server-authoritative in MP; `ModData.transmit` after balance changes; clients receive `IKST_Economy` global data.
- **Tile locks:** `setPassword` blocked on MP client JVM.

### Single player (42.19)
- Fixed load-order crash: `IKST_ClimatePresets.FLOAT` nil during `IKST_StaffOps` require.
- Fixed Give item when `IKST_StaffOps.handle` was not yet loaded on server.
- Weather presets use client `transmitClientChangeAdminVars` / `transmitStopWeather` (vanilla admin panel APIs).

### Other
- Vehicle enter hook: correct B42 path `Vehicles/TimedActions/ISEnterVehicle`.
- Admin chat: deferred `ISChat` init for B42.
- Caught-player enforcement: `OnTick` every 30 ticks (not only `EveryOneMinute`).
- Workshop description: removed WIP tag; version **0.2.1**.

### Known limits
- **Set time in MP** may not visually sync for all clients (no vanilla `transmitSetTime`).
- **Co-op host** still uses in-process `runServerCommand` (by design).
