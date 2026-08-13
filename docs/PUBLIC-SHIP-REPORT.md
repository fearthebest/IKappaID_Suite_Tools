# Public ship report — IKappaID Suite Tools + IKappaID_UI

**Do not bump** `modversion` unless asked.

## 1.0 gate

**Code and accepted limits are done.** The remaining work for **1.0.0.0** is a green test pass on pack **0.3.2.0 BETA** (`42.20/`).

If SP smoke + dedicated play + `docs/REDTEAM-TIER-C.md` are all green, call it 1.0.0.0. After that, a modified client keeping IKST-protected state is an IKST bug; admin sandbox mistakes, a compromised dedicated host, and vanilla movement/combat cheats are not (`docs/SECURITY.md` fault line).

Icons / posters stay optional art. After IKappaID_UI is a Steam item: set it as **Required items** on Suite Tools (`3750835193`). Ship from the `42.20/` pack, not a restored older branch.

## Current pack status

Done in git (do not bump version). Sync Workshop before playtest.

| Item | Status |
|------|--------|
| Recursive requires (claim + economy) | Table created **before** peer `require` |
| Claim radial | Inside wrap always; outside wrap only if inside did not already add slices |
| Third-party OS/UI brand names in Suite Tools `42.20` Lua | Stripped |
| CommandQueue disconnect prune | `EveryOneMinute` drop of offline player queues |
| `SafeHouse.allowSafeHouse` | `type(...) == "function"`; skip if missing (not fail-closed) |
| Loot extra-container trim | Clear contents; stop if no real remove API |
| Tile destroy server cancel | Not added — documented in `docs/SECURITY.md` |
| IKappaID_UI hard require | `mod.info` `require=\IKappaID_UI`; hub/Jobs refuse if the framework is missing |

Still **not** a full public Steam ship: IKappaID_UI is not a Workshop item; dedicated MP (`docs/REDTEAM-TIER-C.md`) is unchecked.

## Verdict

Not public-ship ready until IKappaID_UI is on Steam (subscribers cannot load Suite Tools without it) and dedicated red-team rows pass.

| Layer | Public ship? |
|-------|----------------|
| Steam dependency graph | **No** — `IKappaID_UI` not a Workshop item |
| Upload tree | Use **`42.20/`** (match live game) |
| SP crash class (dashboard / Move here) | Fixed in the 42.20 pack |
| Dedicated MP sign-off | **Not done** |
| Icons / posters | Skip unless asked |

---

## Must-do (public Steam)

### 1. Publish IKappaID_UI as its own Workshop item

Suite Tools `mod.info` has `require=\IKappaID_UI`. Subscribers who only enable Suite Tools will not load.

Do:

1. Keep a **minimal** Steam pack: `workshop.txt` + `Contents/` only. Do **not** upload `.git`, `docs/`, `README.md`.
2. Ship **`42.20/`** (match live game). Include the UI APIs listed below or the dashboard will crash.
3. Upload, get a Workshop file id.
4. Set visibility public (or unlisted until Suite Tools is updated — Suite Tools **cannot** Steam-require it until the id exists).

### 2. Wire Suite Tools Steam page to require that item

Steam id today: `3750835193`.

Do:

- Steam UI: **Required items** → IKappaID UI Framework (the new id).
- `workshop.txt` description: required mod, Mod ID `IKappaID_UI`, subscribe + enable **both**.
- Server hosts: both in `Mods=` / workshop collection.

Also document: Vehicles addon `require=IKappaIDSuiteTools,IKappaIDSuiteToolsTiles` (World Edit must be on). Economy cash still needs Phone Shop at runtime.

### 3. Git is the 42.20 source of truth, then sync Workshop

Expected under `Contents/mods/`:

```
IKappaIDSuiteTools\42.20\
IKappaIDSuiteToolsAdmin\42.20\
IKappaIDSuiteToolsEconomy\42.20\
IKappaIDSuiteToolsLoot\42.20\
IKappaIDSuiteToolsTiles\42.20\
IKappaIDSuiteToolsVehicles\42.20\
```

Do **not** upload `42.18/` as if it were the playtest pack. After Lua edits: sync **git → Workshop**, then Steam upload from the Workshop folder.

### 4. UI APIs the dashboard needs

Dashboard calls these on IKappaID_UI. If they are missing, the hub crashes.

| API | Why |
|-----|-----|
| `IKUI_Config.s(px)` | icon/gap scale |
| `IKUI_Config.textSize(text, font)` | `MeasureStringX/Y` |
| `IKUI_Config.buttonWidth(label, font, minW)` | Refresh button; nil → `buildHeader` crash |
| `IKUI_Chrome.colors.bgSurface` | `drawRegionBg`; nil `.a` crash |

**Vehicles relocate** — `IKST_VehicleSnapshot.lua`: `captureItem` must be forward-declared before use (Lua does not hoist locals). Same for `captureItem` ↔ `captureItemsList` and `applyItemRecord` ↔ `restoreContainerItems`. Symptom if missing: `Object tried to call nil in captureItem` on **Move here**.

### 5. Dedicated MP sign-off

Public MP needs a dedicated host you control. Minimum:

- Two clients: claims (safehouse + vehicle), permissions
- Staff **Move here** with trunk items (snapshot/restore)
- Economy deposit/wire **with** Phone Shop loaded
- Remote client cannot spawn money/items via forged commands
- Relog: claim mirror still correct

Until that passes, keep Steam **BETA** language or unlisted.

### 6. Clean load: recursive require

Every boot (`console.txt`):

```
IKST_SafehouseClaimMirror.lua → recursive require IKST_SafehouseClaim.lua
IKST_EconomyIdentity.lua → recursive require IKST_Economy.lua
```

Cause: `require` of the other file **before** `IKST_* = IKST_* or {}`.

**Done:** create the table first, then require.

### 7. Claim radial — do not wrap both vanilla functions

`IKST_ClaimRadial.lua` `hookVehicleMenu` wraps:

- `ISVehicleMenu.showRadialMenu`
- `ISVehicleMenu.showRadialMenuOutside`
- `ISVehicleMenu.onKeyPressed`

Wrapping **inside + outside** previously **doubled** Claim. **Done:** inside wrap always; outside wrap skips if `_ikstSliceKeys` already set. Keep `addSliceOnce`. Do **not** add more vanilla wraps.

### 8. No third-party OS/UI brand names in shipped Lua

Ship rule: no third-party OS/UI brand names in code or player-facing strings. Comments in Lua **are** uploaded.

**Done** on Suite Tools `42.20` Lua.

---

## Should-do (not Steam-hard, still user-visible)

| Item | Detail |
|------|--------|
| Dual UI kits | Dashboard uses `IKappaID_UI`; jobs still `IKST_Chrome`. Freeze chrome in the suite **or** finish migrating jobs. Do not call IKUI helpers that do not exist. |
| Client vehicle watchdog | `IKST_VehicleClaimHooks.lua` `shutOff` / `exit` on local player. Confirm dedicated MP does not desync; prefer server enforcement if it does. |
| IKappaID_UI Steam pack hygiene | Upload `workshop.txt` + `Contents/` only. |
| Vehicles + Tiles | `mod.info` require is correct; say so on the Vehicles blurb so hosts do not enable Vehicles alone. |
| English-only | OK if you do not advertise other locales. |
| `console.txt` | Full **quit** after Lua (ErrorMagnifier caches). No SEVERE from these mods. |

---

## Already OK (do not “fix”)

- Zero `pcall` / `xpcall` / `tryCall` / `safeCall`
- No Lua `next()` (Java `it:next()` is fine)
- Client JVM skip is `isServer() and not isClient()`, not bare `isClient() return`
- `sandbox-options.txt` `VERSION = 1`; `Sandbox.json` lives in `42.20/` for mods that have sandbox
- Items: `ItemType = base:*` (not `Type = Normal`)
- `OnClientCommand` uses event `playerObj`; no `args.admin`
- `IKST_RateLimit` + `IKST_ServerGate` allowlist
- Core `require=\IKappaID_UI`; no third-party UI libraries
- Relocate: snapshot → delete → spawn, backup restore on failure
- `IKST_JobsPanel.instance` singleton
- Timed-action wraps in `IKST_Enforcement.lua` are the existing claim/loot gate — leave unless MP proves a bug

---

## Paths (no personal directories)

| What | Where |
|------|--------|
| Suite git | This repository |
| UI git | Sibling `IKappaID_UI` repo |
| Suite playtest | `%USERPROFILE%\Zomboid\Workshop\IKappaID Suite Tools\` |
| UI playtest | `%USERPROFILE%\Zomboid\Workshop\IKappaID_UI\` |
| Logs | `%USERPROFILE%\Zomboid\console.txt` |

---

## Test plan after fixes

1. Full game quit.
2. Enable **IKappaID UI Framework** + **Suite Tools** (+ addons you ship).
3. New SP: hub `Ctrl+Shift+W`, dashboard, no ErrorMagnifier.
4. Vehicles: **Move here** with glovebox/trunk loot.
5. Claim radial: on foot near a car **once**, in seat **once** (no double Claim).
6. `console.txt`: no recursive-require WARN from IKST; no SEVERE.
7. Dedicated host: list in §5.

---

## Do not

- Bump `modversion` / `workshop.txt` version labels unless asked
- Add `pcall` / `xpcall` / `tryCall` / `safeCall`
- Add new vanilla monkey patches
- Upload git `42.18/` as if it were the playtest pack
- Upload UI repo extras (`.git`, `docs/`) into Steam Contents
- Require third-party UI mods
- Commit/push unless asked

---

## Suggested order

1. Confirm UI APIs + snapshot forward-declares; SP retest.
2. Keep recursive-require and radial wrap as already shipped.
3. Publish IKappaID_UI; add required item on Suite Tools.
4. Dedicated MP (`docs/REDTEAM-TIER-C.md`).
5. Steam update from **synced Workshop** trees.

Icons/posters whenever you want; they are not in this list.
