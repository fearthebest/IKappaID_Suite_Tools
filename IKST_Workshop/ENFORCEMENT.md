# IKST client enforcement

IKST blocks unauthorized looting, vehicle use, and sledge destruction by **chaining vanilla functions**, not by replacing vanilla files.

Rules (who may do what) live in **shared** modules on the server path. Client enforcement only asks those rules before vanilla code runs.

## Files

| File | Pack | Role |
|------|------|------|
| `IKST_Enforcement.lua` | Core | Transfer, grab, vehicle timed actions, safehouse build/doors |
| `IKST_EnforcementTiles.lua` | Tiles addon | Sledge destroy cursor, movable pickup |
| `IKST_VehicleClaimWatch.lua` | Core | Backup: eject unauthorized driver / cut engine if they slip through |

## Shared rule modules (source of truth)

- `IKST_TransferRules` → vehicle trunk/seat loot, dropboxes, locks, readonly tiles
- `IKST_VehicleClaim.canUseVehicle` → enter, engine, doors, mechanics, etc.
- `IKST_VehiclePermissions.TIMED_ACTION` → maps vanilla timed-action class → permission key
- `IKST_TileCheck.isProtected` → staff tile protection / world rules
- `IKST_SafehouseClaim.canAtSquare` → player safe-area claims

Server claim data and staff commands are unchanged. Enforcement runs on the **client JVM** (including dedicated-server players).

## Vanilla integration points

Registered on `Events.OnGameBoot` and `Events.OnGameStart` (in case classes load late).

### Core (`IKST_Enforcement.lua`)

| Vanilla | Method | Check |
|---------|--------|-------|
| `ISInventoryTransferAction` | `isValid`, `perform` | `IKST_TransferRules.transferAllowed` |
| `ISGrabItemAction` | `isValid` | `IKST_TransferRules.transferAllowed` |
| `ISEnterVehicle` + entries in `TIMED_ACTION` | `isValid` | `IKST_VehicleClaim.canUseVehicle` |
| Build / door timed actions | `isValid` | `IKST_SafehouseClaim.canAtSquare` |

Each wrap saves the previous function in a local and **calls it when the action is allowed** (standard PZ modding compatibility pattern).

### Tiles (`IKST_EnforcementTiles.lua`)

| Vanilla | Method | Check |
|---------|--------|-------|
| `ISDestroyCursor` | `canDestroy` | `IKST_TileCheck.isProtected`, safehouse destroy |
| `ISMoveableSpriteTool` | `walkTo` | tile pickup protection, safehouse |

## What this does not do

- No global `sendClientCommand` override
- No chat / UI class hijacks for enforcement
- No fake timed-action constructors
- No `pcall` around file or vanilla calls
- Not a copy of any third-party hook registry; one IKST file per pack, calling IKST shared rules only

## Mod compatibility

1. **Chain order** — If another mod wraps the same method without calling the previous function, only one mod wins. Prefer loading IKST after generic UI mods if conflicts appear.
2. **One vehicle-claim mod** — Do not run IKST vehicle claims alongside AVCS / another claim system.
3. **Tiles pack** — Sledge protection requires `IKappaIDSuiteToolsTiles` enabled.
4. **Staff bypass** — `IKST_Access.canUseTools` still bypasses checks where shared rules already allow it.

## Multiplayer note

Client blocks stop normal gameplay immediately. A modified client could still bypass Lua. Authoritative claim state remains on the server via existing IKST commands and ModData sync.

## Maintenance checklist (after a PZ build update)

1. Start a debug game with IKST + Tiles; confirm `[IKST]` load lines in `console.txt`.
2. Claim a vehicle as player A; as player B verify: cannot enter, cannot loot trunk, halo message shown.
3. Protect a tile / safehouse area; verify sledge cursor refuses destroy.
4. If a timed-action class was renamed in vanilla, update `IKST_VehiclePermissions.TIMED_ACTION` or the build-class lists in `IKST_Enforcement.lua`.
5. If transfers fail silently, check whether vanilla renamed `ISInventoryTransferAction` paths under `media/lua/shared/TimedActions/`.

## Adding a new protected action

1. Add or extend a permission in shared code (`canUseVehicle`, `canAtSquare`, `isProtected`, etc.).
2. If vanilla uses a **new** timed-action class, add it to `TIMED_ACTION` or the build-class list.
3. If vanilla uses an existing class already wrapped, only step 1 is needed.
