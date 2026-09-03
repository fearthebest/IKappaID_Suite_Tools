# IKappaID Suite Tools — Changelog

## 0.3.2.4 — BETA (2026-09-03)

Build **42.20** — hub-only manage surfaces + IKappaID_UI economy detach.

### Changed
- **One hub** — Claim Permissions, Briefing Rules, Economy shop/ATM, and Help tickets stay in the soft panel.
- **World / radial Permissions** — open Claim in the hub instead of a second window.
- **Action log** — no longer a hub satellite.
- **Help Tickets** — notify staff to use F1 Admin (vanilla tickets).
- **Economy Detach** — optional compact wallet uses IKappaID_UI chrome (same dark + orange as the hub).

### Fixed
- Hover tooltips on truncated hub buttons (requires **IKappaID_UI v0.1.0.3**).

Requires **IKappaID_UI v0.1.0.3+**.

Steam paste: `docs/STEAM-CHANGELOG-0.3.2.4.txt`

## 0.3.2.3 — BETA (2026-09-01)

Build **42.20** — SP claim sandbox + World Edit pack page nav.

### Fixed
- **SP claim sandbox** — self-claim vs request follow per-save sandbox toggles; SP host no longer auto bypasses player claim modes.
- **SP house requests** — walk-draw submit and staff review queue work in single player for request-only playtests.
- **World Edit paint** — pack page row (`< | N/M | >`); right scroll control no longer clipped on narrow panels.

### Changed
- **Paint tiles pack UI** — List/Load on their own row; separate pack and tile page nav rows.

Requires **IKappaID_UI v0.1.0.2+**.

Steam paste: `docs/STEAM-CHANGELOG-0.3.2.3.txt`

## 0.3.2.2 — BETA (2026-09-01)

Build **42.20** — soft hub claim UX + dual-window cleanup.

### Changed
- **Soft hub only** — one Jobs shell; primary path no longer opens the old dock dual-window job panels.
- **Claim UX** — bounds-first `safehouseId`; no auto-select; single list via Guard → ClaimClient; Permissions place soft in-hub.
- **Safehouses** — one Size band (no competing resize paths).
- **Overview vehicles** — soft master/detail inside the hub.
- **Economy Valuables** — Deposit / Withdraw / Transfer soft in-hub; Open window remains optional.
- **Staff** — `getSelectedTarget` requires explicit select; StaffRemoteAdmin danger tooltip (default false).
- **Help** — Rules open soft Help (Briefing not the primary floating path).

### Added
- **Safehouse invites** — Accept/Decline membership invite flow (`IKST_SafehouseInvite` / client + server commands).

### Fixed
- Claim / permissions / staff selection fail-closed paths that could act on the wrong house or player.
- Soft layout (`placePillGroup`, `contains`) so hub pages stop overlapping or fighting for space.

Steam paste: `docs/STEAM-CHANGELOG-0.3.2.2.txt`

## 0.3.2.1 — BETA (2026-08-24)

Build **42.20** — claim system fixes and request-queue hardening.

### Fixed
- **Vehicle self-claim UI** — Admins and self-service players see **Claim vehicle** instead of only **Request** when the nearby list was stale or admin bypass did not match server rules.
- **Staff claim-request list** — House and vehicle request rows are selectable; Approve/Deny work from the shared list pattern.
- **Request submit validation** — Rejects at max claims, overlapping safehouses, PhunZones blocks, and residential-only failures before enqueueing.
- **Vehicle request rules** — Submit and staff approve enforce seat, engine, and key requirements like direct self-claim when the requester is online.
- **Safehouse stale UI** — Release/edit buttons derive from policy and mirror data when the MP safehouse list has not loaded yet.

### Changed
- **Four claim sandbox modes** — Independent toggles: house self-claim, house request, vehicle self-claim, vehicle request.
- **Request UX** — Request-only players get **Request house** on ground context menu and radial; staff who can direct-claim no longer see redundant request buttons.
- **House request flow** — Walk-draw can start from context menu / radial (`startHouseClaimRequest`).

### Added
- **Vehicle claim requests** — Players submit vehicle claims to the staff queue; staff list shows `[House]` / `[Vehicle]` labels.

Steam paste: `docs/STEAM-CHANGELOG-0.3.2.1.txt`

## 0.3.2.0 — BETA (2026-08-13)

Build **42.20** public Beta pack.

- Boot: break recursive `require` between claim/economy peer modules (table first, then require).
- Vehicles: forward-declare snapshot `captureItem` so **Move here** with glovebox/trunk loot does not nil.
- **Requires IKappaID_UI** (Mod ID `IKappaID_UI`): `mod.info` `require=\IKappaID_UI`; hub/Jobs refuse to open if the UI framework is not loaded. Dedicated `Mods=` must include it.
- **Vehicle claims:** stop using session `getId()` as the saved claim key (those ids recycle on restart). Stamp a durable key on the vehicle; bind on spawn / loaded cell. World Edit vehicle protect uses the same stamp.
- **Safehouse commands:** resolve by rectangle (`x,y,w,h`), not session `getOnlineID()` / `getSafeHouse(int)` (those recycle after dedicated restart the same way vehicle ids do).
- **Commands:** sanitize client payloads (depth 6, 200 keys, 4096 chars, finite numbers) before authorize; deny oversized tables with `[IKST-AUDIT]`.
- **Join:** 15s hold on mutating command groups (`claim_write`, `economy_write`, `vehicle_mutate`, `staff_give`, `lock_auth`); deny with `retryAfterMs`. List/debug/briefing/identity stay allowed. Not the 30s arrival zombie window.
- **Relocate:** backup stash keyed by durable `IKST_vkey`; session id is in-flight only. Origin restore matches stamp, then coords.
- **Journal / shop:** flatten recovery snapshot and vend price catalog to primitive strings on item/object `modData` (nested tables can drop on save).
- **sqlId bind:** if two claim rows share the same sqlId, skip bind (fail closed).
- **Jobs UI:** scale mixes screen height with `UIFont.Small` metrics; Jobs x/y/w/h persist to a client file with a known-key whitelist (clamped to screen). Claim lists are paged (`offset`/`limit`); Guard tab shows “waiting for server” until the first page arrives.
- Claim radial: inside wrap always; outside wrap only if slices were not already added (no double Claim).
- Server: prune disconnected players from `IKST_CommandQueue`.
- Safehouse: `allowSafeHouse` uses `type(...) == "function"`; skip if missing (not fail-closed).
- Loot: extra-container trim clears contents and stops if the engine has no remove API.
- Comments: strip third-party UI brand names from shipped Lua.

## 0.3.0.0 — BETA (2026-07-01)

Official **BETA** release for Build 42 multiplayer playtesting.

- Steam paste: `STEAM-CHANGELOG-0.3.0.0.txt`
- Steam description: `STEAM-DESCRIPTION-0.3.0.0.txt`

### Loot (addon)
- **Dedicated MP:** Repopulate works on outdoor and no-room containers (neighbor room + distribution fallbacks; server `fillContainer` last resort with trim).
- **MP sync:** Server pushes container contents via `sendContentsToRemoteContainer`; client pulls with `requestServerItemsForContainer` (loot visible without relog).
- **Ghost crate fix:** No duplicate clipped crates after repop; contents-only sync (no `transmitCompleteItemToClients` on MP).
- **UX:** Clear failure reasons in server log; halo feedback when Jobs panel is closed.

### Core / claims
- **Vehicle claim sync:** Server-authoritative claim rows + client mirror (fixes false “claimed by another player” after relog).
- **MP authority:** Server-only world mutations on tile protect, waypoints, safehouse/claim UIs.

### Vehicles (addon)
- Relocate snapshot path, backup/restore, claim id remap (from 0.2.7.x line).

## 0.2.7.1 (2026-07-02)

### Loot (addon)
- **Dedicated MP:** Loot repop no longer indexes `ItemPickerJava` THashMaps from Lua (`rooms` / `containers` / `pairs`); use `ItemPicker.getItemContainer()` + `rollItem` only (fixes server crash on container/zone repop).

### Vehicles (addon)
- **Headless server:** Skip `setTireInflation` in vehicle snapshot (avoids `UnsatisfiedLinkError` on relocate).
- **Relocate:** Footprint validation, spawn-order hardening, relocate backup list/restore UI (origin / target / here), pose pin on enter to reduce flip snap.

## 0.2.7.0 (2026-07-01)

### Loot (addon)
- **Dedicated MP:** Fix `ItemPickerJava` map access — use Lua-table vs Java `THashMap` `:get()` (no `map.get` probe; fixes server crash on repop).
- **UX:** Halo toasts for loot results; client preview of affected containers in job panel; world highlights when Tiles is loaded; block empty ground clicks before server round-trip.

### Vehicles (addon)
- **Admin move:** Relocate via snapshot → delete → respawn (no overlapping vehicles / dupe risk).
- **Safety:** Server ModData backup + restore at origin on spawn failure or server restart mid-move.
- **Claims:** Remap vehicle claim row when engine assigns a new vehicle id after relocate.

### Tiles (addon)
- **Safehouse mirror:** Replace broken `triggerEvent(Events.OnSafehousesChanged)` with `forceSafehouseRefresh()` (B42 client API).

## 0.2.6.1 (2026-06-28)

### Dedicated MP fixes

- **Arrival Stabilization:** Server detects players via `getOnlinePlayers()` on dedicated hosts (client-only `OnCreatePlayer` / `OnConnected` no longer required); grace start logged to server console; client toast + HUD on sync.
- **Identity on connect:** Same dedicated-server player scan for ID card / economy migration on join; death uses `OnCharacterDeath` on server.
- **Vehicle claims UI:** Shared `IKST_VehicleKeys.lua` fixes client `require("IKST_VehicleUtil") failed` on context menu.
- **Staff / world tools (from 0.2.6 session):** MP weather on admin client, waypoint teleport sync, lifecycle world-ready on dedicated server, tile/loot rate-limit buckets, vegetation single-pick mode.

## 0.2.6 (2026-06-28)

### Claims enforcement (plain client integration)

- **Arrival Stabilization:** Zombie-immunity grace period after joining or respawning to prevent unfair deaths during sync (configurable in sandbox).
- **Server Briefing:** Custom server information and rules panel accessible from the ESC menu and Everyone workspace.
- **Claims enforcement:** Unauthorized players cannot enter claimed vehicles, loot trunks/seats, or destroy protected tiles; permission checks use shared rule modules.
- **Transfer guard:** Inventory transfer and ground pickup blocked when rules deny access (vehicles, dropboxes, locks, readonly tiles, safehouse claims).
- **Architecture:** Centralized `IKST_Enforcement` (core) and `IKST_EnforcementTiles` (Tiles addon); chains vanilla methods for better compatibility.
- **Stability:** Briefing loader uses `fileExists` before read (no crash when briefing folder is missing). Removed incomplete `42.19/` stub folders that prevented Lua from loading on B42.19.

## 0.2.5 (2026-06-27)

### Security & Stability release (Tier C hardening)

- **Sandbox UI:** Plain-English sandbox labels via categorized tabs and `Sandbox.json` per addon; translations co-located in `42.19/media/lua/shared/Translate/EN/` (required for B42.19; `common/` alone is not loaded).
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
