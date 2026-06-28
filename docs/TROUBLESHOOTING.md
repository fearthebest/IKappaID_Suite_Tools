# IKST Troubleshooting — Load errors and mod state

## `IKST_RecipeGate.lua:38` — attempted index of non-table

**This file is not part of official IKST.** It does not appear in git history, the Tier C testing zip, or any shipped addon (115 Lua files as of 2026-06-27).

The crash is caused by a **stale or experimental Lua file** left in your local mod folder. PZ auto-loads every `media/lua/**/*.lua` at startup (`LoadDirBase`), so a broken orphan file prevents the game from loading.

### Fix

1. Search your Zomboid mods tree for `IKST_RecipeGate.lua`:
   - Windows: `%UserProfile%\Zomboid\mods\` and `%UserProfile%\Zomboid\Workshop\`
   - Linux: `~/.local/share/Steam/steamapps/common/ProjectZomboid/mods/` and `~/Zomboid/Workshop/`
2. **Delete** `IKST_RecipeGate.lua` (all copies).
3. Reinstall from this repo:
   - Copy `Workshop/IKappaID Suite Tools/` to your Workshop folder, **or**
   - Extract `releases/IKappaID-Suite-Tools-TierC-Testing.zip`
4. Confirm your base mod `shared/` folder contains **`IKST_ServerGate.lua`** (server command auth) and **not** `IKST_RecipeGate.lua`.

### Why there is no RecipeGate in shipped IKST

Admin-only items are gated without Lua recipe hooks:

| Item | Gate mechanism |
|------|----------------|
| ATM terminal kit | No `craftRecipe` in scripts; admin place UI + server command |
| Shop terminal kit | Public craft recipe; placement is player-facing |
| Keypad kit | Public craft; install is player command |
| Recovery journal | Public craft; record/restore gated by sandbox at command time |

If you need a new admin-only craft item, omit `craftRecipe` from the item script (ATM pattern) instead of adding a RecipeGate file.

---

## Sandbox options show raw keys (e.g. `Sandbox_IKappaIDSuiteTools_EnableMod`)

**Symptom:** Sandbox sidebar or option labels show untranslated keys instead of plain English.

**Common causes:**

1. **Stale mod copy** — The flat single-tab layout with `VehicleListRadius` near the top is the **pre-0.2.5** sandbox file. Current builds use categorized pages (`IKST: General`, `IKST: Claims`, etc.) with `EnableMod` first.
2. **Wrong install path** — Copy the full `Workshop/IKappaID Suite Tools/` folder from this repo into `%UserProfile%\Zomboid\Workshop\`. Disable or remove any older Steam Workshop subscription copy of IKST so it does not override your local files.
3. **Translation file location** — B42 loads sandbox labels from `common/media/lua/shared/Translate/EN/Sandbox.json` (not under `42.18/`). Each addon has its own `common/.../Sandbox.json`.

**Fix:**

1. Use the mod from **`Workshop/IKappaID Suite Tools/`** in this repo (not GitHub branches, not Steam subscription).
2. Copy the entire folder to `%UserProfile%\Zomboid\Workshop\IKappaID Suite Tools\` and replace all files.
3. **Disable/unsubscribe** the Steam Workshop copy of IKST (Workshop ID `3750835193`) so it cannot override your local files.
4. Confirm this file exists in your game copy:

   `Contents/mods/IKappaIDSuiteTools/SANDBOX_BUILD.txt`

   If that file is missing, the game is **not** loading this build.

5. In Sandbox Options, pick a **new preset** (saved presets like "TestingMods" cache the old layout).
6. Fully quit and restart Project Zomboid.

**Correct B42 layout (matches Skill Recovery Journal `2503622437`):**

```text
IKappaIDSuiteTools/
  mod.info
  common/mod.info
  common/media/lua/shared/Translate/EN/Sandbox.json
  common/media/lua/shared/Translate/EN/Sandbox_EN.txt
  42.19/media/sandbox-options.txt
  42.18/media/... (lua scripts)
```

**In-game you should see:** sidebar tabs **IKST: General**, **IKST: Claims**, first option **Enable IKST**.

---

## Current mod shape (repo state)

| Layer | Details |
|-------|---------|
| **Version** | `modversion=0.2.3`, `versionMin=42.18` (runs on B42.19) |
| **Branch** | `cursor/tier-c-testing-05ab` adds Tier C security (ServerGate, RateLimit, AuditLog, Args) |
| **Addons** | Base → Economy, Tiles, Loot (optional); Vehicles requires Tiles |

### Load model

PZ loads Lua alphabetically per folder (`shared` → `client` → `server`), with addon order from `mod.info` `require=` chain.

| Entry point | File | Role |
|-------------|------|------|
| Client bootstrap | `client/IKST_Z_Bootstrap.lua` | Hotkey, `OnServerCommand`, UI wiring (`Z_` = loads last) |
| Server bootstrap | `server/IKST_Server.lua` | `OnClientCommand` router, Tier C `IKST_ServerGate.authorize` |
| Plugin registration | `shared/IKST_*Register.lua` | Economy, Tiles, Loot, Vehicles register into `IKST.Plugins` |

Every shared module that uses `IKST.CMD` or `IKST.VIEW` starts with `require "IKST_Shared"`. Do not add new shared files that index `IKST.*` tables at top level without that require.

### Expected startup messages

- Client: `[IKST] IKappaID Suite Tools v0.2.3 loaded (client)`
- Server (Tier C build): gate/audit modules load when the server JVM handles commands

---

## Known load-order crash pattern (fixed in 0.2.1)

**Symptom:** `attempted index of non-table` during `LoadDirBase`  
**Cause:** Aliasing or indexing a global table before its module has run (e.g. `IKST_ClimatePresets.FLOAT` at require time).  
**Fix in tree:** `IKST_StaffOps.lua` uses local `CLIMATE` constants and lazy `ensureClimatePresets()`.

New shared/server files must follow the same pattern: `require "IKST_Shared"` first, defer recipe/script-manager work to `Events.OnGameBoot`, nil-guard optional globals.

---

## Clean install checklist

- [ ] Five mod IDs only: `IKappaIDSuiteTools`, `IKappaIDSuiteToolsEconomy`, `IKappaIDSuiteToolsTiles`, `IKappaIDSuiteToolsVehicles`, `IKappaIDSuiteToolsLoot`
- [ ] No extra `IKST_*.lua` files under `media/lua/` that are not in the official file list
- [ ] Base shared folder has `IKST_ServerGate.lua`, not `IKST_RecipeGate.lua`
- [ ] Workshop folder matches `Workshop/IKappaID Suite Tools/` from this repo or the Tier C zip

See also: [LOCAL-INSTALL.md](./LOCAL-INSTALL.md), [AUDIT-0.2.5.md](./AUDIT-0.2.5.md), [SECURITY.md](./SECURITY.md).
