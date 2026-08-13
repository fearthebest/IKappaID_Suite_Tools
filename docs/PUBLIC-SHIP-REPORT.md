# Public ship report — IKappaID Suite Tools + IKappaID_UI

**For:** main-machine fix session (MCP + PZ-AI-Dev-Guidance)  
**From:** laptop audit 2026-08-13 (game **42.20.2**)  
**Do not bump** `modversion` unless asked.

## 1.0 gate (2026-08-13)

**Code and accepted limits are done.** The only remaining work for **1.0.0.0** is a green test pass on pack **0.3.2.0 BETA** (`42.20/`).

If SP smoke + dedicated play + `docs/REDTEAM-TIER-C.md` are all green, call it 1.0.0.0. After that, a modified client keeping IKST-protected state is an IKST bug; admin sandbox mistakes, a hacked dedicated host, and vanilla movement/combat cheats are not (`docs/SECURITY.md` fault line).

Icons / posters stay optional art. After IKappaID_UI is public: Steam **Required items** on Suite Tools (`3750835193`). After tests: git commit of this 42.20 pack (not restored `master`).

Icons / posters are **out of scope** here (you already know). Everything below is historical ship context from the laptop audit.

---

## Paste this into a new Agent chat on the main machine

```
PZ B42 public-ship session. Live game 42.20.2. Folder 42.20/.

Read in order:
- C:\Users\mpass\Projects\PZ-AI-Dev-Guidance\AI-DEV-GUIDANCE\OMNI.md
- C:\Users\mpass\Projects\PZ-AI-Dev-Guidance\AI-DEV-GUIDANCE\MOD-QUALITY-CHECK.md
- C:\Users\mpass\Projects\PZ-AI-Dev-Guidance\AI-DEV-GUIDANCE\PZ-GUI-PLAYBOOK.md
- C:\Users\mpass\Projects\PZ-AI-Dev-Guidance\AI-DEV-GUIDANCE\IKAPPAID-UI-FRAMEWORK.md
- C:\Users\mpass\Projects\PZ-AI-Dev-Guidance\AI-DEV-GUIDANCE\GITHUB-PUBLISH-POLICY.md
- This report: <mod-repo>/docs/PUBLIC-SHIP-REPORT.md

Follow OMNI: wiki-first, simple code, zero pcall/xpcall/tryCall/safeCall, type(x)=="function", pairs not next, no new monkey patches unless I accept them, server authority, UTF-8 no BOM, no version bump.

Workspace = git repo root (Projects\IKappaID_Suite_Tools and/or Projects\IKappaID_UI), then sync to %USERPROFILE%\Zomboid\Workshop\. Do not edit Workshop-only.

Goal: make Suite Tools + IKappaID_UI public-ship ready except icons (skip poster/icon/PNG art). Execute the Must-do list in this report. Ask before git commit/push.
```

Open **two** git roots if needed (multi-root is OK): `IKappaID_UI` then `IKappaID_Suite_Tools`. Steam packing is a **separate** chat from Lua edits.

---

## Public Beta code base (`laptop-playtest-2026-08-13`)

Done in git (do not bump version). Sync Workshop before playtest. Do not upload restored `master`.

| Item | Status |
|------|--------|
| Recursive requires (claim + economy) | Table created **before** peer `require` |
| Claim radial | Inside wrap always; outside wrap only if inside did not already add slices |
| HyperOS in Suite Tools `42.20` Lua | Stripped |
| CommandQueue disconnect prune | `EveryOneMinute` drop of offline player queues |
| `SafeHouse.allowSafeHouse` | `type(...) == "function"`; skip if missing (not fail-closed) |
| Loot extra-container trim | Clear contents; stop if no real remove API |
| Tile destroy server cancel | Not added — documented in `docs/SECURITY.md` |

Still **not** a full public Steam ship: IKappaID_UI is not a Workshop item; dedicated MP (`docs/REDTEAM-TIER-C.md`) is unchecked; SP + Faded MP still pending.

## Verdict

Not public-ship ready. SP on the laptop loaded and the hub mostly worked after two crash fixes. Public Steam still fails because **players cannot load Suite Tools without IKappaID_UI on Workshop**, and **git is still 42.18 while the tested pack is 42.20**.

| Layer | Public ship? |
|-------|----------------|
| Steam dependency graph | **No** — `IKappaID_UI` not a Workshop item |
| Upload tree vs tested tree | **No** — GitHub `42.18/` vs playtest `42.20/` |
| SP crash class (dashboard / Move here) | Fixed on **laptop Workshop only** — port to main git |
| Dedicated MP sign-off | **Not done** this session |
| Icons / posters | Skip (your call) |

---

## Must-do (public Steam)

### 1. Publish IKappaID_UI as its own Workshop item

Suite Tools `mod.info` has `require=\IKappaID_UI`. Subscribers who only enable Suite Tools will not load.

Laptop state:

- Clone: `C:\Users\mpass\Projects\IKappaID_UI` (git) and `C:\Users\mpass\Zomboid\Workshop\IKappaID_UI` (playtest)
- `workshop.txt` has **no Steam `id=`**, `visibility=unlisted`
- GitHub: https://github.com/fearthebest/IKappaID_UI (still `42.18/` in git; laptop added a local `42.20/` copy)

Do:

1. Keep a **minimal** Steam pack: `workshop.txt` + `Contents/` only. Do **not** upload `.git`, `docs/`, `README.md`.
2. Ship **`42.20/`** (match live game). Include laptop API adds (below) or dashboard will crash again.
3. Upload, get a Workshop file id.
4. Set visibility public (or unlisted until Suite Tools is updated — but Suite Tools **cannot** require it until the id exists).

Guidance: `IKAPPAID-UI-FRAMEWORK.md`, `zomboid-dev-layout.mdc`.

### 2. Wire Suite Tools Steam page to require that item

File: `%USERPROFILE%\Zomboid\Workshop\IKappaID Suite Tools\workshop.txt`  
Steam id today: `3750835193`.

Current description lists Phone Shop and addons. It does **not** mention IKappaID UI Framework.

Do:

- Steam UI: **Required items** → IKappaID UI Framework (the new id).
- `workshop.txt` description: required mod, Mod ID `IKappaID_UI`, subscribe + enable **both**.
- Server hosts: both in `Mods=` / workshop collection.

Also document: Vehicles addon `require=IKappaIDSuiteTools,IKappaIDSuiteToolsTiles` (World Edit must be on). Economy cash still needs Phone Shop at runtime (already in the blurb).

### 3. Make git the 42.20 source of truth, then sync Workshop

Laptop playtest (what actually ran):

```
%USERPROFILE%\Zomboid\Workshop\IKappaID Suite Tools\Contents\mods\
  IKappaIDSuiteTools\42.20\          114 lua
  IKappaIDSuiteToolsAdmin\42.20\       3 lua
  IKappaIDSuiteToolsEconomy\42.20\    16 lua
  IKappaIDSuiteToolsLoot\42.20\        7 lua
  IKappaIDSuiteToolsTiles\42.20\      28 lua
  IKappaIDSuiteToolsVehicles\42.20\    7 lua
```

GitHub clone on the laptop (`Projects\IKappaID_Suite_Tools`):

- Almost only **`42.18/`**
- Core **86** lua vs Workshop **114**
- **Admin addon missing entirely**
- One stray `42.20` file: `IKappaIDSuiteToolsVehicles\...\IKST_VehicleSnapshot.lua` (Move-here fix)

Do **not** upload from git `42.18/`. Copy Workshop `42.20/` (and Admin) into git, or treat main-machine Workshop as master and commit that. Backup tag first per `GITHUB-PUBLISH-POLICY.md`.

After Lua: robocopy/sync **git → Workshop**, then Steam upload from Workshop.

### 4. Port laptop crash fixes onto the main machine

These are **not** on GitHub origin. If the main Workshop pack is older, Move here and dashboard will crash again.

**A. IKappaID_UI** — `IKUI_Config.lua` / `IKUI_Chrome.lua`  
Dashboard called APIs the framework did not ship.

| Add | Why |
|-----|-----|
| `IKUI_Config.s(px)` | icon/gap scale |
| `IKUI_Config.textSize(text, font)` | `MeasureStringX/Y` |
| `IKUI_Config.buttonWidth(label, font, minW)` | Refresh button; nil → `buildHeader` crash |
| `IKUI_Chrome.colors.bgSurface` | `drawRegionBg`; nil `.a` crash |

Laptop copies: `Projects\IKappaID_UI\Contents\mods\IKappaID_UI\42.18\` and Workshop `...\42.20\`.

**B. Vehicles relocate** — `IKST_VehicleSnapshot.lua`  
`captureItem` called local `copyPrimitiveModData` **before** it was defined (Lua does not hoist locals). Same for `captureItem` ↔ `captureItemsList` and `applyItemRecord` ↔ `restoreContainerItems`.

Fix: forward-declare, then assign functions. Laptop file:

`Workshop\IKappaID Suite Tools\Contents\mods\IKappaIDSuiteToolsVehicles\42.20\media\lua\shared\IKST_VehicleSnapshot.lua`

Symptom: `Object tried to call nil in captureItem` on **Move here**.

### 5. Dedicated MP sign-off

This laptop session was **single player** only. Public MP needs a dedicated host you control (`MOD-QUALITY-CHECK.md` §8).

Minimum:

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

**Done on this branch:** create the table first, then require.

Files:

- `IKappaIDSuiteTools\42.20\media\lua\shared\IKST_SafehouseClaim.lua`
- `...\IKST_SafehouseClaimMirror.lua`
- `IKappaIDSuiteToolsEconomy\42.20\media\lua\shared\IKST_Economy.lua`
- `...\IKST_EconomyIdentity.lua`

### 7. Claim radial — do not wrap both vanilla functions

`IKST_ClaimRadial.lua` `hookVehicleMenu` wraps:

- `ISVehicleMenu.showRadialMenu`
- `ISVehicleMenu.showRadialMenuOutside`
- `ISVehicleMenu.onKeyPressed`

Wrapping **inside + outside** previously **doubled** Claim. **Done on this branch:** inside wrap always; outside wrap skips if `_ikstSliceKeys` already set. Keep `addSliceOnce`. Do **not** add more vanilla wraps.

### 8. Strip “HyperOS” from shipped Lua

Ship rule: no third-party OS/UI brand names in code or player-facing strings. Comments in Lua **are** uploaded.

**Done on this branch** (Suite Tools `42.20` Lua). IKappaID_UI `workshop.txt` + `IKUI_Chrome.lua` comment also renamed. No gameplay change.

---

## Should-do (not Steam-hard, still user-visible)

| Item | Detail |
|------|--------|
| Dual UI kits | Dashboard uses `IKappaID_UI`; jobs still `IKST_Chrome`. Freeze chrome in the suite **or** finish migration (`IKAPPAID-UI-FRAMEWORK.md`). Do not call IKUI helpers that do not exist. |
| Client vehicle watchdog | `IKST_VehicleClaimHooks.lua` `shutOff` / `exit` on local player. Confirm dedicated MP does not desync; prefer server enforcement if it does. |
| IKappaID_UI Steam pack hygiene | Laptop Workshop UI folder is a git clone. Upload `workshop.txt` + `Contents/` only. |
| Vehicles + Tiles | `mod.info` require is correct; say so on the Vehicles blurb so hosts do not enable Vehicles alone. |
| English-only | OK if you do not advertise other locales. |
| `console.txt` | Full **quit** after Lua (ErrorMagnifier caches). No SEVERE from these mods. |

---

## Already OK (do not “fix”)

- Zero `pcall` / `xpcall` / `tryCall` / `safeCall` (comment only in Chrome)
- No Lua `next()` (Java `it:next()` is fine)
- Client JVM skip is `isServer() and not isClient()`, not bare `isClient() return`
- `sandbox-options.txt` `VERSION = 1`; `Sandbox.json` lives in `42.20/` for mods that have sandbox
- Items: `ItemType = base:*` (not `Type = Normal`)
- `OnClientCommand` uses event `playerObj`; no `args.admin`
- `IKST_RateLimit` + `IKST_ServerGate` allowlist
- Core `require=\IKappaID_UI`; no Neat / 42UIAPI
- Relocate: snapshot → delete → spawn, backup restore on failure
- `IKST_JobsPanel.instance` singleton
- Timed-action wraps in `IKST_Enforcement.lua` are the existing claim/loot gate — leave unless MP proves a bug

---

## Laptop-only paths (copy if main machine differs)

| What | Path |
|------|------|
| Guidance | `C:\Users\mpass\Projects\PZ-AI-Dev-Guidance\` |
| UI git | `C:\Users\mpass\Projects\IKappaID_UI\` |
| Suite git | `C:\Users\mpass\Projects\IKappaID_Suite_Tools\` |
| Suite playtest | `C:\Users\mpass\Zomboid\Workshop\IKappaID Suite Tools\` |
| UI playtest | `C:\Users\mpass\Zomboid\Workshop\IKappaID_UI\` |
| Logs | `C:\Users\mpass\Zomboid\console.txt` |

Prefer **Projects** git over Desktop mirrors.

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
- New vanilla monkey patches
- Upload git `42.18/` as if it were the playtest pack
- Upload UI repo extras (`.git`, `docs/`) into Steam Contents
- Require third-party UI mods
- Commit/push mods unless I ask (backup tag first — `GITHUB-PUBLISH-POLICY.md`)

---

## Suggested order on the main machine

1. Read OMNI + this file + quality check.  
2. Port UI API adds + snapshot forward-declares; SP retest.  
3. Break recursive requires; strip HyperOS; radial wrap.  
4. Promote Workshop `42.20/` (+ Admin) into git.  
5. Publish IKappaID_UI; add required item on Suite Tools.  
6. Dedicated MP.  
7. Steam update from **synced Workshop** trees.

Icons/posters whenever you want; they are not in this list.
