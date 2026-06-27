# IKST Command Matrix — Tier C Phase 0 Inventory

**Mod:** IKappaID Suite Tools (IKST) · **Baseline:** 0.2.5 (repo `IKST.VERSION` may read 0.2.3) · **Build:** B42.18  
**Generated:** Phase 0 read-only inventory for Tier C security hardening.

This document maps every `IKST.CMD.*` value to its server handler, permission model, sandbox gates, validation, rate limits, logging, and known client-trust gaps.

---

## 1. Server entry points

### 1.1 Primary MP path (authoritative)

```
Remote client → sendClientCommand("IKST", cmd, args)
Dedicated / listen-server JVM → Events.OnClientCommand (IKST_Server.lua)
  → IKST_Server.handleCommand(module, command, player, args)
      1. IKST.Plugins.handleServerCommand (economy, tiles, loot, vehicles) — FIRST
      2. IKST_Server.playerMayRunCommand (admin OR player-claim subset)
      3. Base handlers: threat, utilities stub, weather stub, quick*, lists, guard, journal, staff
```

**File:** `IKST_Workshop/Contents/mods/IKappaIDSuiteTools/42.18/media/lua/server/IKST_Server.lua`

### 1.2 Plugin dispatch

**File:** `shared/IKST_Plugins.lua` → `IKST.Plugins.handleServerCommand`

For each registered plugin (`economy`, `tiles`, `loot`, `vehicles`):

1. Match `playerCommands` or `adminCommands`
2. `canUseAdmin(player)` or `canUsePlayer(player)` — **per-plugin, not centralized**
3. `spec.handleServer(command, player, args)`
4. Optional `afterServer` (result / snapshot sync)

### 1.3 Local server paths (no network packet)

| Path | When | Security note |
|------|------|---------------|
| `IKST.dispatchCommand` → `IKST.runServerCommand` | Integrated SP, co-op host local player | Host is trusted by threat model |
| `IKST.dispatchCommand` → `sendClientCommand` | MP listen host, remote client | Must match dedicated-server checks |
| `IKST.enqueueClientCommand` | Tiles addon queue (listen host) | Same command set as above |

**File:** `shared/IKST_Shared.lua` (`dispatchCommand`, `runServerCommand`, `deliverClientCommand`)

### 1.4 Client-only paths (NOT server commands — Tier C holes)

| Path | File | Risk |
|------|------|------|
| `IKST.toggleUtilityForPlayer` → `IKST.setUtilityOn` → `SandboxOptions:sendToServer()` | `shared/IKST_Utility.lua` | **Client-trusted** global water/power in MP |
| `IKST_QuickActions.run` → utility branch | `shared/IKST_QuickActions.lua` | Same as above |
| `IKST_ClientStaff.runWeather` / `runClearWeather` → `IKST_ClimatePresets` on `isClient()` | `client/IKST_ClientStaff.lua` | **Client-trusted** weather on admin client |
| `IKST_QuickActions.run("clearWeather")` → `ClimatePresets` | `shared/IKST_QuickActions.lua` | Same as above |
| Context menu utility toggles | `client/IKST_ContextMenu.lua` | Same as utility |

Server stubs **reject** `quickWater`, `quickPower`, `setWeather`, `clearWeather` with “use client …” messages — but clients never need to send them for utilities/weather today.

### 1.5 Server → client (results / sync — not client entry points)

Handled in `client/IKST_Z_Bootstrap.lua` `onServerCommand` and plugin `onServerCommand` hooks:

`result`, `batchProgress`, `inspectResult`, `threatResult`, `staffListResult`, `waypointListResult`, `protectListResult`, `vehicleListResult`, `dumpPlayersResult`, `safehouseListResult`, `vehicleClaimListResult`, `economySnapshotResult`, `economyVendListResult`, `lockUnlockSync`, `safehouseBordersSync`, `catchSync`

---

## 2. Permission model (baseline 0.2.5)

| Helper | Location | Rule |
|--------|----------|------|
| `IKST_Access.isAdmin` | `shared/IKST_Access.lua` | SP/co-op host → true; MP → `accesslevel == "admin"` only |
| `IKST_Access.canUseTools` | same | Alias of `isAdmin` |
| `IKST_Access.canToggleUtilities` | same | admin, moderator, gm, overseer (UI only today) |
| `IKST_Access.canUseEconomy` | same | Mod + economy addon + `IKST_Economy.isEnabled()` |
| `IKST_Access.canUseLoot` | same | Mod + loot addon + `canUseTools` |
| `IKST_Server.playerMayRunCommand` | `server/IKST_Server.lua` | `canUseTools` OR (`ClaimPlayerSelfService` AND `PLAYER_CLAIM_COMMANDS[cmd]`) |
| Plugin `canUseAdmin` | `*Register.lua` | Usually `canUseTools` (economy also requires economy enabled) |
| Plugin `canUsePlayer` | `*Register.lua` | Economy: `canUseEconomy`; Tiles locks: **`player ~= nil`** (any online player) |
| `IKST_GuardOps.actorIsAdmin` | `server/IKST_GuardOps.lua` | `canUseTools` — used inside guard ops for ownership bypass |

**Not present in baseline:** `canUseStaffTools`, `canUseThreatTools`, `canUseCatchJail`, `canUseRecoveryJournal`, `commandAllowedForPlayer`, `IKST_ServerGate`, `IKST_TilesPolicy`.

---

## 3. Command matrix

**Legend**

- **Role:** minimum access — `player` = any authenticated player with route access; `moderator` = utilities UI only (not server cmd); `admin` = `accesslevel=admin` or SP/co-op host
- **Rate group:** Tier C target group; **current** = what exists today
- **Logged:** server audit (Tier C target); **client log** = `IKST_ActionLog` / `pushLog` only
- **Client-trust:** whether MP can achieve effect without server authorize today

### 3.1 Core server (`IKST_Server.handleCommand`)

| Command | Handler | Role | Sandbox / gates | Server validates | Rate (current → Tier C) | Logged | Client-trust |
|---------|---------|------|-----------------|------------------|---------------------------|--------|--------------|
| `threatCull` | `IKST_WorldOps.threatCull` | admin | `EnableMod`; radius → `MaxCleanupRadius` (tiles/core) | coords, `clampRadius`, `maxPerTick` | none → `staff_power` / `threat_cull` 1/5s | no | no |
| `threatPopulation` | `IKST_WorldOps.threatPopulation` | admin | same | coords, radius clamp | none → `list/query` 1/s | no | no |
| `quickWater` | stub reject | — | — | — | — | no | **yes** (client `setUtilityOn`) |
| `quickPower` | stub reject | — | — | — | — | no | **yes** (client `setUtilityOn`) |
| `setWeather` | stub reject | — | — | — | — | no | **yes** (`ClientStaff` / climate client) |
| `clearWeather` | stub reject | — | — | — | — | no | **yes** (`QuickActions` / `ClientStaff`) |
| `quickSave` | `saveGame()` | admin | `EnableMod` | — | none → `staff_world` | no | no |
| `quickBroadcast` | `serverMsg` | admin | `EnableMod` | `args.message` present | none → `staff_world` | no | no |
| `staffListPlayers` | `IKST_StaffOps.listOnlinePlayers` | admin | `EnableMod` | — | none → `list/query` 1/s | no | no |
| `listWaypoints` | `IKST_Waypoints.list` | admin | `EnableMod` | — | none → `list/query` 1/s | no | no |

### 3.2 Guard / claims (`IKST_GuardOps.handle`)

Routed when `IKST.GUARD_COMMANDS[command]` and `playerMayRunCommand` passes.

| Command | Handler | Role | Sandbox / gates | Server validates | Rate (current → Tier C) | Logged | Client-trust |
|---------|---------|------|-----------------|------------------|---------------------------|--------|--------------|
| `catchTarget` | `setCaught(target)` | admin | none dedicated | target resolve | none → `staff_power` | no | no |
| `catchPlayer` | same | admin | none | target resolve | none → `staff_power` | no | no |
| `releaseTarget` | `setCaught(false)` | admin | none | target resolve | none → `staff_power` | no | no |
| `releasePlayer` | same | admin | none | target resolve | none → `staff_power` | no | no |
| `toggleCreative` | `toggleCreative` | admin | none | — | none → `staff_power` | no | no |
| `toggleUnlimitedAmmo` | `toggleUnlimitedAmmo` | admin | none | — | none → `staff_power` | no | no |
| `lightbulbsArea` | `lightbulbsInRadius` | admin | none | coords, `clampRadius` | none → `staff_world` | no | no |
| `dumpPlayers` | `dumpPlayers` | admin | none | — | none → `list/query` | no | no |
| `safehouseList` | `listSafehouses` + filter | player† / admin | `ClaimPlayerSelfService` | non-admin list filtered to owner | none → `list/query` 1/s; cap list size | no | no |
| `safehouseClaim` | `claimSafehouse` | player† / admin | `ClaimPlayerSelfService`, `MaxSafehouseClaims`, building checks | non-admin **forces** `args.owner = self`; bounds | none → `claim_write` | no | no |
| `safehouseRelease` | `releaseSafehouse` | player† / admin | claim enabled | owner match or admin | none → `claim_write` | no | no |
| `safehouseAddMember` | `addSafehouseMember` | player† / admin | `ClaimAllowNamedPlayers`, `ClaimMaxNamedPlayers`, … | owner/admin; permission scopes | none → `claim_write` | no | no |
| `safehouseRemoveMember` | `removeSafehouseMember` | player† / admin | same | owner/admin | none → `claim_write` | no | no |
| `safehouseClaimSetPerms` | `SafehouseClaim.setPermissions` | player† / admin | `ClaimOwnersEditGroups`, whitelist | owner edit or admin | none → `claim_write` | no | no |
| `safehouseTp` | `tpToSafehouse` | admin | — | coords | none → `staff_tp` | no | no |
| `backupSafehouses` | `backupSafehouses` | admin | — | — | none → `staff_world` | no | no |
| `restoreSafehouses` | `restoreSafehouses` | admin | — | — | none → `staff_world` | no | no |
| `toggleSafehouseBorders` | ModData toggle | admin | — | — | none → `staff_world` | no | no |
| `vehicleClaim` | `VehicleClaim.claim` | player† / admin | `MaxVehicleClaims`, `VehicleClaimRequireKeys` | non-admin owner=self; key check; vehicle id | none → `claim_write` | no | no |
| `vehicleReleaseClaim` | `VehicleClaim.release` | player† / admin | claim enabled | owner or admin | none → `claim_write` | no | no |
| `vehicleClaimTransfer` | `VehicleClaim.transfer` | admin (handler) | — | admin gate in handler | none → `claim_write` | no | no |
| `vehicleClaimSetLabel` | `setLabel` | player† / admin | — | `playerMayEdit` or admin | none → `claim_write` | no | no |
| `vehicleClaimSetPerms` | `setPermissions` | player† / admin | claim policy perms | owner edit or admin | none → `claim_write` | no | no |
| `vehicleClaimList` | `listForOwner` / `listAll` | player† / admin | `VehicleShowAllClaims` | filtered for non-admin | none → `list/query` 1/s | no | no |

† Requires `ClaimPlayerSelfService=true` and command ∈ `PLAYER_CLAIM_COMMANDS`.

### 3.3 Recovery journal (`IKST_RestoreServer.handle`)

| Command | Handler | Role | Sandbox | Server validates | Rate (current → Tier C) | Logged | Client-trust |
|---------|---------|------|---------|------------------|---------------------------|--------|--------------|
| `journalRecord` | `RestoreOps.capturePlayer` | player† | `RecoveryJournalEnabled` | journal item in inventory | none → `claim_write` + cooldown | no | no |
| `journalRestore` | `RestoreOps.applySnapshot` | player† | `RecoveryJournalEnabled` | item owner username match | none → cooldown per player | no | no |

### 3.4 Staff (`IKST_StaffOps.handle`)

All require `STAFF_COMMANDS` + `canUseTools` (admin). No `StaffToolsEnabled` sandbox in baseline.

| Command | Handler | Sandbox | Server validates | Rate (current → Tier C) | Logged | Client-trust |
|---------|---------|---------|------------------|---------------------------|--------|--------------|
| `healSelf` | `heal` | `EnableMod` | — | none → `staff_power` 1/s | no | no |
| `feedSelf` | `feed` | same | — | none → `staff_power` | no | no |
| `cureSelf` | `cure` | same | — | none → `staff_power` | no | no |
| `godSelf` | `toggleGod` | same | — | none → `staff_power` | no | no |
| `invisSelf` | `toggleInvisible` | same | — | none → `staff_power` | no | no |
| `ghostSelf` | `toggleGhost` | same | — | none → `staff_power` | no | no |
| `tpCoords` | `teleportPlayer` | same | x,y,z tonumber | none → `staff_tp` | no | no |
| `giveItem` | `giveItem` | same | count clamp 1–100; **no item type whitelist** | none → `staff_give` 1/s | no | no |
| `giveKit` | `giveKit` | same | kit name | none → `staff_give` | no | no |
| `setTime` | `setTime` | same | hour 0–23.99 | none → `staff_world` | no | no |
| `setWeather` | `setWeather` | same | preset name; **fails on dedicated server JVM** | none → `staff_world` | no | **yes** on admin client |
| `clearWeather` | `clearWeather` | same | **fails on dedicated server JVM** | none → `staff_world` | no | **yes** on admin client |
| `clearZombies` | `clearZombies` | same | radius | none → `staff_power` | no | no |
| `healTarget` | `heal(target)` | same | online id | none → `staff_power` | no | no |
| `bringTarget` | teleport to admin | same | online id | none → `staff_tp` | no | no |
| `tpToTarget` | teleport to target | same | online id | none → `staff_tp` | no | no |
| `giveTarget` | `giveItem(target)` | same | type, count cap | none → `staff_give` | no | no |
| `feedTarget` | `feed` | same | online id | none → `staff_power` | no | no |
| `cureTarget` | `cure` | same | online id | none → `staff_power` | no | no |
| `godTarget` | `toggleGod` | same | online id | none → `staff_power` | no | no |
| `healAll` | `healAll` | same | — | none → `staff_power` | no | no |
| `feedAll` | `feedAll` | same | — | none → `staff_power` | no | no |
| `cureAll` | `cureAll` | same | — | none → `staff_power` | no | no |
| `tpAllToMe` | `tpAllToMe` | same | — | none → `staff_tp` | no | no |
| `economyGive` | `EconomyBridge.giveMoney` | economy enabled | amount | economy 400ms‡ | no | no |
| `economyGiveTarget` | give to target | economy enabled | target, amount | economy 400ms‡ | no | no |
| `economyBalance` | snapshot / bridge | economy enabled | — | none | no | no |
| `economyReissueId` | `reissueBankId` | economy + admin recheck | — | none | no | no |
| `economyReissueIdTarget` | reissue for target | same | target online | none | no | no |
| `saveWaypoint` | `Waypoints.save` | `EnableMod` | name | none → `staff_world` | no | no |
| `delWaypoint` | `Waypoints.delete` | same | name | none → `staff_world` | no | no |
| `tpWaypoint` | teleport | same | waypoint exists | none → `staff_tp` | no | no |

‡ Routed via staff handler, not economy plugin throttle.

### 3.5 Economy plugin (`IKST_EconomyOps.handle`)

**Player commands** — `canUsePlayer` = `canUseEconomy`. **Admin commands** — `canUseAdmin` = `canUseTools` + economy (should be `canUseStaffTools` in Tier C).

| Command | Role | Sandbox / gates | Server validates | Rate (current → Tier C) | Logged | Client-trust |
|---------|------|-----------------|------------------|---------------------------|--------|--------------|
| `economySnapshot` | player | `EconomyEnabled`, PhoneShop | — | exempt from 400ms throttle | no | no |
| `economyDeposit` | player | ATM rules, ID card | amount, coords, `bankGate`, ATM config | **400ms** → `economy_write` | no | no |
| `economyWithdraw` | player | same | same + balance | **400ms** → `economy_write` | no | no |
| `economyWire` | player | `EconomyWireDistance`, min amount, fee | target online, distance, balance | **400ms** → `economy_write` | no | no |
| `economyExchange` | player | valuables list | item at coords, ATM | **400ms** → `economy_write` | no | no |
| `economyExchangeAll` | player | same | coords | **400ms** → `economy_write` | no | no |
| `economyIdCardReissue` | player | ID banking | coords, ATM | **400ms** → `economy_write` | no | no |
| `economyVendList` | player | shop distance | `playerNearCoord`, shopMaxDistance | exempt → `economy_read` 1/s | no | no |
| `economyVendBuy` | player | shop protect, prices | distance, ownership, item presence (re-read) | **400ms** → `economy_write` | no | no |
| `economyVendSetPrice` | player | owner stock rules | shop owner match, max price | **400ms** → `economy_write` | no | no |
| `economyVendClaim` | player | vending enabled | square ownership | **400ms** → `economy_write` | no | no |
| `economyShopPlace` | player | shop kit | kit in inv, square | **400ms** → `economy_write` | no | no |
| `economyVendDisable` | player / admin | — | owner or admin | **400ms** → `economy_write` | no | no |
| `economyVendEnable` | admin | — | owner key resolve | **400ms** → `staff_world` | no | no |
| `economyAtmConfigure` | admin | — | coords, config | **400ms** → `staff_world` | no | no |
| `economyAtmPlace` | admin | — | kit, coords | **400ms** → `staff_world` | no | no |

### 3.6 Tiles plugin (`IKST_TilesOps.handle` → sub-ops)

**Admin** — `canUseAdmin` = `canUseTools`. **Player locks** — `canUsePlayer` = any non-nil player.

| Command | Handler | Role | Sandbox | Server validates | Rate (current → Tier C) | Logged | Client-trust |
|---------|---------|------|---------|------------------|---------------------------|--------|--------------|
| `inspectSquare` | `TilesWorldOps.inspectSquare` | admin | `MaxCleanupRadius` (z) | coords | none → `list/query` | client log | no |
| `cleanupObject` | `runCleanup` | admin | radius caps | coords, protect rules | none → `staff_world` | client log | no |
| `cleanupTile` | same | admin | same | same | none → `staff_world` | client log | no |
| `cleanupSquare` | same | admin | same | same | none → `staff_world` | client log | no |
| `paintRemove` | cleanup as object | admin | same | same | none → `staff_world` | client log | no |
| `cleanupRadius` | batch | admin | `MaxCleanupRadius` | radius clamp | none → `staff_world` | client log | no |
| `cleanupCube` | batch | admin | cube half clamp | half extent | none → `staff_world` | client log | no |
| `cleanupRoom` | batch | admin | — | room from square | none → `staff_world` | client log | no |
| `cleanupBuilding` | batch | admin | — | building scope | none → `staff_world` | client log | no |
| `cleanupVegetation` | batch | admin | radius clamp | radius | none → `staff_world` | client log | no |
| `paintPlace` | `paintPlace` | admin | `MaxPaintRadius` | sprite, coords | none → `staff_world` | client log | no |
| `rewind` | `TilesWorldOps.rewind` | admin | — | undo stack | none → `staff_world` | client log | no |
| `protectList` | `ProtectOps.sendList` | admin | — | radius | none → `list/query` | no | no |
| `protectSquare` | `ProtectOps.handle` | admin | — | coords, ownership | none → `staff_world` | client log | no |
| `unprotectSquare` | same | admin | — | coords | none → `staff_world` | client log | no |
| `protectRadius` | same | admin | radius clamp | actor position not verified† | none → `staff_world` | client log | no |
| `unprotectRadius` | same | admin | same | same | none → `staff_world` | client log | no |
| `protectVehicle` | same | admin | — | vehicle id | none → `staff_world` | client log | no |
| `unprotectVehicle` | same | admin | — | vehicle id | none → `staff_world` | client log | no |
| `setDropbox` | same | admin | — | coords | none → `staff_world` | client log | no |
| `setReadonly` | same | admin | — | coords | none → `staff_world` | client log | no |
| `autoGardener` … `autoUnloadContainers` | `AutomationOps` | admin | automation toggles | coords/radius per job | none → `staff_world` | client log | no |
| `setWorldRule` | `TilesGuardOps` | admin | — | rule name | none → `staff_world` | no | no |
| `addSpriteBlacklist` | same | admin | — | sprite string | none → `staff_world` | no | no |
| `farmRevitalize` | same | admin | — | radius clamp | none → `staff_world` | no | no |
| `farmHarvestAll` | same | admin | — | radius clamp | none → `staff_world` | no | no |
| `blueprintCopy` | same | admin | — | coord box | none → `staff_world` | no | no |
| `blueprintPaste` | same | admin | — | coords | none → `staff_world` | no | no |
| `createSnapshot` | player snapshot ModData | admin | — | optional target id | none → `staff_world` | no | no |
| `restoreSnapshot` | restore ModData snap | admin | — | target | none → `staff_world` | no | no |
| `lockSetPassword` | `Locks.setPassword` | admin | — | password in args | none → `staff_world` | no | no |
| `lockClear` | clear password | admin | — | coords | none → `staff_world` | no | no |
| `lockTryUnlock` | `Locks.tryUnlock` | **player** | — | password; **no brute-force limit** | none → `lock_auth` 5/min + lockout | no | no |
| `lockInstallKeypad` | consume kit server-side | **player** | keypad recipe/item | kit type, password; **no distance check** | none → `lock_auth` | no | no |

† Tier C Phase 6: verify actor near radius actions or remote-admin sandbox.

### 3.7 Loot plugin (`IKST_LootOps.handle`)

| Command | Role | Sandbox | Server validates | Rate | Logged |
|---------|------|---------|------------------|------|--------|
| `lootRepopulateContainer` | admin (`canUseLoot`) | loot addon | coords, container index, world loot type | none → `staff_world` | no |
| `lootRepopulateZone` | admin | loot addon | scope, container cap (`maxContainers`) | none → `staff_world` | no |

### 3.8 Vehicles plugin (`IKST_VehicleOps.handle`)

All **admin** (`canUseTools`). Validates coords / vehicle ids per handler; list uses `VehicleListRadius`.

| Command | Notes | Rate (Tier C) |
|---------|-------|---------------|
| `vehicleList` | returns `vehicleListResult`; no `sendResult` | `list/query` |
| `vehicleSpawn` | script validation via catalog | `staff_world` |
| `vehicleMove` | vehicle id | `staff_world` |
| `vehicleDelete` | vehicle id | `staff_world` |
| `vehicleDeleteCell` | cell scope | `staff_world` |
| `vehicleFlip` | vehicle id | `staff_world` |
| `vehicleRepair` | vehicle id | `staff_world` |
| `vehicleKey` | vehicle id | `staff_world` |
| `vehiclePrune` | radius | `staff_world` |
| `vehicleRepairNear` | also in `STAFF_COMMANDS` — **base server staff path** if not caught by plugin first | `staff_power` |
| `vehicleKeyNear` | same dual registration | `staff_power` |
| `vehicleSkinNext` / `vehicleSkinPrev` | vehicle id | `staff_world` |
| `vehicleUnlockTrunk` / `vehicleUnlockDoors` | vehicle id | `staff_world` |

---

## 4. Routing quirks and side doors

1. **Plugins run before `playerMayRunCommand`.** Economy/tiles/loot/vehicles enforce their own `canUseAdmin` / `canUsePlayer` — not the claim-player path. A non-admin cannot invoke economy admin cmds, but **could** invoke tiles lock cmds with only `player ~= nil`.

2. **`vehicleRepairNear` / `vehicleKeyNear`** appear in both `IKST_VehiclesRegister` admin commands and `IKST.STAFF_COMMANDS`. Plugin wins when vehicles addon active.

3. **Weather/time split brain:** UI uses client climate on `isClient()`; server `setWeather`/`clearWeather` rejected at router; `setTime` works on server but staff UI may not dispatch on remote admin client consistently.

4. **Utilities:** `canToggleUtilities` includes moderator+ but server has no authoritative quickWater/quickPower — moderators can grief utilities via client sandbox send.

5. **No unknown-command audit:** Unregistered commands return `"unknown command"` / plugin miss falls through — no centralized deny log.

6. **Client action log only:** `IKST_ActionLog` is per-player client UI — not suitable for incident response on dedicated servers.

---

## 5. Gaps vs Tier C (roadmap)

Priority follows `ROADMAP-TIER-C-SECURITY.md`.

### P0 — Must fix before public Tier C launch

| Gap | Affected commands / paths | Target phase |
|-----|---------------------------|--------------|
| No `IKST_ServerGate.authorize` | All server commands | Phase 1 |
| Permission checks scattered in plugins + `GuardOps.actorIsAdmin` + `StaffOps` | All | Phase 1 |
| `canUseAdmin` uses `canUseTools` not staff sandbox | Economy/tiles/loot/vehicles admin cmds | Phase 1 |
| No `StaffToolsEnabled` (or equivalent) | All staff/guard admin cmds | Phase 1 |
| No server rate limits (except economy 400ms) | giveItem, lockTryUnlock, threatCull, lists, claims | Phase 2 |
| No server audit log | All denies + sensitive allows | Phase 3 |
| **Client-trusted utilities** | `quickWater`, `quickPower` via `SandboxOptions:sendToServer` | Phase 4a |
| **Client-trusted weather** | `setWeather`, `clearWeather` on admin client | Phase 4b |
| Dedicated server weather/time authority unclear | `setWeather`, `setTime` | Phase 4b |
| Lock brute-force | `lockTryUnlock` | Phase 2 + 5 |
| No `IKST_Args` validation helpers | coords, radius, item types, counts | Phase 6 |
| Red-team checklist not run | See roadmap Phase 7 table | Phase 7 |

### P1 — Abuse resistance

| Gap | Notes | Phase |
|-----|-------|-------|
| Claim list unbounded / unthrottled | `safehouseList`, `vehicleClaimList` | 5 |
| `lockInstallKeypad` no distance gate | Remote install if coords spoofed | 5 |
| `vendBuy` race / dupe hardening | Re-read container atomically (audit EconomyBridge) | 5 |
| `journalRestore` no cooldown / rate limit | Combat restore abuse | 5 |
| `giveItem` no item type allowlist | Arbitrary item types (count capped at 100) | 6 |
| PROTECT radius actions lack actor position check | Remote protect/unprotect at arbitrary coords | 6 |
| Ops docs missing | `SECURITY.md`, `ADMIN-RUNBOOK.md`, `SANDBOX-OPTIONS.md` updates | 8 |

### P2 — Tier C+

| Item | Phase |
|------|-------|
| HMAC/nonce on commands | 9 |
| IP ban on repeated denies | 9 |
| Overseer/mod command subsets | 9 |
| Economy transaction ledger | 9 |

---

## 6. Tier C rate-limit groups (target)

| Group | Commands | Default limit |
|-------|----------|---------------|
| `economy_write` | deposit, withdraw, wire, exchange*, vendBuy, vendSetPrice, vendClaim, shopPlace, vendDisable | 400ms (existing) |
| `economy_read` | economySnapshot, economyVendList | 1/s |
| `staff_give` | giveItem, giveKit, giveTarget | 1/s |
| `staff_tp` | tpCoords, bringTarget, tpToTarget, tpWaypoint, tpAllToMe, safehouseTp | 1/s |
| `staff_power` | heal*, feed*, cure*, god*, clearZombies, threatCull, catch* | 1/s; threatCull 1/5s |
| `staff_world` | quickSave, backup/restore safehouses, paint/cleanup*, loot repopulate, economy admin place | 1/s (tunable) |
| `claim_write` | claim/release/transfer/perms/members, journal* | 1/s + optional cooldown |
| `lock_auth` | lockTryUnlock | 5/min + 60s lockout after 20 fails |
| `list/query` | *List, dumpPlayers, staffListPlayers, threatPopulation | 1/s + cap |
| `utility` | quickWater, quickPower (once server-authoritative) | 1/s |

---

## 7. Sandbox keys reference (security-relevant)

### Core (`IKappaIDSuiteTools`)

`EnableMod`, `ClaimPlayerSelfService`, `MaxVehicleClaims`, `MaxSafehouseClaims`, `ClaimDurationDays`, `ClaimAdminBypass`, `ClaimWhitelistOnly`, `ClaimAllowNamedPlayers`, `ClaimMaxNamedPlayers`, `ClaimOwnersGrantExtra`, `ClaimOwnersEditGroups`, vehicle/safehouse guest & member permission booleans, `RecoveryJournalEnabled`, `VehicleListRadius`, `VehicleNearRadius`

### Tiles addon

`MaxCleanupRadius`, `MaxPaintRadius` (and automation-related options in tiles sandbox)

### Vehicles addon

`VehicleShowAllClaims`, `VehicleClaimRequireKeys`

### Economy addon

`EconomyEnabled`, `EconomyWireDistance`, `EconomyShopDistance`, `EconomyAtmRequired`, `EconomyIdCardBanking`, `EconomyMaxVendPrice`, `EconomyShopProtect`, `EconomyShopOwnerStockOnly`, wire min/fee options

### Planned for Tier C (not in baseline)

`StaffToolsEnabled`, `EnableThreatTools`, `EnableCatchJail`, `EnableUtilitiesToggle`, rate-limit toggles, audit retention — see roadmap Phase 1–3.

---

## 8. Definition of done — Phase 0

- [x] All `IKST.CMD` values enumerated and mapped
- [x] Server entry points and client-trust paths documented
- [x] Gaps vs Tier C listed with phase mapping
- [ ] Phase 1+ implementation (out of scope for Phase 0)

**Next step:** Phase 1 — implement `shared/IKST_ServerGate.lua` and wire `authorize()` before every `handleServer` / base handler path.
