# Faded dump — complete idea library (91 dump folders)

**Folder:** `%USERPROFILE%\Zomboid\mods`  
Faded is off Workshop. **Every pack in this folder is treated as Faded’s dump** (including consolidations of older community mods).  
**Out of this catalog:** IKappaID Suite Tools addons and FactionSystem (our trees).

91 Faded folders on disk (CSR Test is a twin of CSR). Java Loader is **not** a Workshop/mod folder — it lives in the game install (see below).

**Rules for IKappaID:** ideas and failure modes only. Do not copy Lua, meshes, jars, or ClearView purple. HyperOS stays dark grey + orange `#FF6B35`. **Zero `pcall`** even if many Faded files use it. Optional Java Loader always needs a Lua fallback; **IKappaID does not ship or require FJL**.

---

## Cross-cutting (every IKappaID repo)

1. Never persist session ids (`getId()`, `getOnlineID()`, player onlineID).
2. `sql:` is a candidate, not identity.
3. Flat primitives on object/item/vehicle modData; nested tables in global `ModData.getOrCreate`.
4. Authority = not `isClient()` (dedicated + SP + listen).
5. Join grace + payload caps (depth, keys, string length, finite numbers).
6. `Schema.ensure` on load.
7. Optional Java, required Lua.
8. Detect other mods; don’t hard-require them.
9. Shared theme **tokens**, not copied windows. IKappaID_UI / IKST_Chrome is our token source.
10. Many Faded files use `pcall` — we do not.

---

## Complete catalog (91)

| Pack | Ver | Lua | Idea for IKappaID |
|------|-----|-----|-------------------|
| A Bards Tale | 1.0.1 | 18 | Server-authoritative aura + trait registry. Resonance / Faction buffs, not instruments. |
| ArmorPK | 2.0.1 | 26 | Sandbox loot rarity + night-vision flag. Item packs / OmniPacking loot knobs. |
| Authentic Z - Current | 42.20.2 | 85 | Outfit distribution volume + “don’t stack with Lite”. Zombie variety if we ever ship outfits. |
| BlanketsFade | 1.2.1 | 7 | Removable bedding as world objects. Tiles addon / world-edit props. |
| BuildcraftReborn | 0.5.1 | 76 | Three-pane workspace, virtual lists, search debounce, batch index, optional FJL UI accel, CSR-safe repair. **IKappaID_UI + IKST Jobs.** |
| ChadedMilitaryConvoy | 2.0.0 | 5 | Military-zone-only spawns; require toolkit. Loot spawn policy. |
| CharacterCreator | 1.2.2 | 71 | Three-column creator, hair gallery, loadout/vehicle pickers, pack API. **IKappaID_UI.** **IKST-done** (Jobs uiScale mixes Small font height). |
| Common Sense Reborn | 1.9.2 | 483 | Durable vehicleKey, claims registry, flat object modData, 518 sandbox. **IKST (done for identity).** |
| Common Sense Reborn (Test) | 1.9.3 | 484 | Same as CSR; don’t dual-enable. |
| CSR_ClearviewGPS | 1.1.2 | 26 | Movable launcher, persist layout locally, server route graph. **IKappaID_UI + IKST waypoints.** **IKST-done** (Jobs xy/wh client file). |
| CSRAdminCommandCenter | 0.2.7 | 63 | View vs control vs export; paged lists; passive claim snapshot; durable key only. **IKST staff.** **IKST-done** (paged vehicle/safehouse lists). |
| CSRFundamentals | 0.2.1 | 108 | Vanilla-only QoL slice. Keep IKST features optional/simple. |
| DebugMeNot | 1.0.0 | 1 | Hide debug clutter; F10 toggle; sandbox instead of split mods. IKST debug UX. |
| EchoesOfHumanity | 0.1.7-stage1 | 10 | Native **Java** NPC framework (roles: civilian/companion/trader/guard/raider/story); Lua is a late-bound facade + MOF bridge. Ships `42/java/*.jar`. **Resonance / Faction NPCs.** Requires FJL — IKappaID stays Lua-complete. |
| Faded More Variety Loot | 1.0.0 | 1 | Single sandbox loot multiplier. Loot addon. |
| Faded Origins - Occupations & Traits | 1.0.1 | 10 | Server-authoritative trait progression (Resolve). Occupations, not IKST claims. |
| FadedAdvancedMedical | 2.1.3 | 45 | Chromeless three-window Health replace; server medicine. **IKappaID_UI** layout; medical if we ship it. |
| FadedAfflictions | 0.3.1 | 14 | Admin-only persistent hidden status; local FX. Resonance / staff tools. |
| FadedArmageddon | 1.0.1 | 11 | Server-authored hazard events + warnings. Resonance / weather tools. |
| FadedArsenalDeadCountyMunitions | 1.0.4 | 17 | Optional DeadCode weapons framework. Item packs; don’t take the framework. |
| FadedBuildingExpansion | 1.1.1 | 3 | Native B42 recipes for doors/gates. Tiles / Buildcraft overlap. |
| FadedCombatText | 2.2.0 | 5 | Damage numbers + HP bar colors. Combat HUD if we want one; keep HyperOS colors. |
| FadedConditionGuns | 1.1.1 | 1 | Server-side spawn condition by loot zone. Loot addon. |
| FadedFarmingFishingReborn | 0.2.5 | 189 | Hub UI + server command rails + farm-vehicle namespace. Economy/tiles; command rails like IKST. |
| FadedFeastcraft | 0.3.1 | 84 | Three-pane kitchen; MP cook validation. **IKappaID_UI**; IKST journal-style server check. |
| FadedFieldOperations | 1.2.2 | 32 | Mission board + tracker HUD dock; MP turn-in; faction reputation. **Resonance + Faction.** |
| FadedFromTheWindow_ZCTW | 1.1.1 | 1 | Zombies smash windows. Vanilla AI tweak; skip unless we want it. |
| FadedHuntersCalling | 2.1.1 | 47 | Three-pane fieldbook; optional FJL tracking + Lua fallback. UI + ZombieBuddy pattern. |
| FadedJavaLoaderBridge | 0.3.0 | 3 | MP plugin-hash handshake (nonce, timeout, kick/block-move fail-closed); Java binds a **narrow** Lua surface (no FS/process/reflection). Detect-only for IKappaID. Handshake key uses `getOnlineID()` — do not copy that. |
| FadedLocomotion | 0.9.4 | 50 | Rail track **authority** + claims + RV cars. Vehicles / IKST claims on non-cars. |
| FadedModSorter | 1.1.2 | 11 | Topological load order; IKappaID catalog mention. Server ModLoadOrder tooling. |
| FadedNinja | 1.2.2 | 13 | Grapple + throwables. Item/traversal pack. |
| FadedPacketSavior | 0.1.1 | 11 | Join grace, command queue, sanitizer, payload caps. **All MP mods.** |
| FadedsClearViewUI | 0.5.0 | 170 | Theme tokens + HUD; Tetris/Notloc inside. **Steal tokens/layout persist only.** |
| FadedsErrorDetected | 0.2.3 | 8 | Copyable error + mod attribution. Debug / ErrorMagnifier workflow. |
| FadedSkies | 1.0.6 | 9 | Helicopters + combat. Vehicle physics / IKFRVP if we ever fly. |
| FadedsLastChance | 0.3.2 | 4 | Server life-save charges. Recovery journal adjacent. |
| FadedsLegacyCodex | 1.0.1 | 4 | Knowledge on **physical items** (survives death). **IKST journal** (item not player modData). |
| FadedsMilitaryToolKitFix | 2.2.0 | 17 | Dependency pack for convoy. Vehicles. |
| FadedsRideOrRot | 0.2.2 | 15 | Pickup-bed ride + MP tow QoL; soft CSR/MVP. **IKFRVP tow.** |
| FadedsTheHive | 2.0.0 | 25 | Persistent quarry + roosts; optional FJL. **Resonance Choir.** |
| FadedsWeaponPack | 42.20 | 65 | DeadCode framework weapons. Item pack only. |
| FadedTradeNetwork | 0.5.2 | 23 | Shops, lease **bounds**, faction treasury, schema.ensure; username+card identity is a **warning**. **Phone Shop + Economy + Faction.** |
| FadedTrenchCoats | 1.0.1 | 2 | Clothing port, namespaced. Clothing packs. |
| FadedVehiclesReborn | 0.2.1 | 4 | Server **replacement tickets** + safe spawn scans. **PinkSlip.** |
| FaithsTraditions | 1.1.1 | 36 | Server-owned miracles + status panel. Resonance / traits. |
| ForMyFurries | 1.2.4 | 101 | Unified outfits + Feastcraft diet bridge. Animation/outfit pipeline; IKappaID stays original IP. |
| Hydrocraft | 42.20.2 | 177 | Huge item/recipe continuation. Don’t absorb; note B42 recipe/item layout. |
| IntoTheRiver | 1.3.0 | 60 | Boats + swim + optional RV interiors. Vehicles / RVs. |
| ISyncYouSyncWeAllSyncForDeSync | 1.1.0 | 42 | Server vehicle impact, tick budget, FJL optional. **IKFRVP + ZombieBuddy.** |
| ItsATrap | 1.2.1 | 13 | Ground craft vs vehicle device split. Traps / tiles. |
| Just2Faded | 2.2.2 | 22 | Standalone crafting + moodle UI. Moodles if we add HUD. |
| JustFaded | 2.0.0 | 1 | Single outfit. Skip. |
| KnoxNetOS | 0.8.2 | 29 | Multi-app OS: cameras, logistics, bank, WEX telemetry. **Hub density** for IKappaID_UI / Phone Shop; don’t ship a second OS. |
| KnoxReborn | 0.3.3 | 49 feat / ~187 w/ maps | Hybrid PZF map stack; Lua always runs; optional FJL for Tikitown **power mission** + lighting. Hometown knowledge API (register only, no “reveal coords”). **Skip** vanilla map monkey-patches (`ISWorldMap` / minimap). Map/ops, not IKST claims. |
| KnoxTransit | 1.0.1 | 18 | Server transit stops + FTN. Economy / world. |
| Lifestyle | 0.4.0 | 509 | Hobbies all-in-one. QoL breadth vs IKST “simple”; don’t port the kitchen sink. |
| MassiveKI5Pack | 1.2.2 | 877 | Performance-focused KI5 roster. **IKFRVP profiles** already cover KI5; spawn/perf notes. |
| MassiveVehiclePack | 0.4.2 | 206 | Public MVP API; timed actions still send session `getId()`. **IKFRVP / PinkSlip / IKST** — resolve live vehicle. |
| MilitaryVehiclesReborn | 2.0.1 | 7 | Independent military vehicles. Vehicle pack. |
| MPChronoController | 2.0.0 | 10 | Pause/play/FF **vote** + admin override + sleep accel. IKST time/weather tools. |
| MyOnlyFriend | 2.1.3 | 29 | Companion persist + FJL cancel engine AI. Resonance/NPC; Java optional. |
| Never Forget | 1.0.4 | 9 | Admin-place memorial. World-edit placeable. |
| Never Survive Alone | 0.4.1 | 6 | Explicit-opt-in MP intimacy; server-validated. Pattern: opt-in + server check. Not IKappaID content. |
| OnTheMove | 1.2.0 | 7 | Bikes/scooters + MP anim sync. Light vehicles. |
| ParentsJournal | 1.0.1 | 8 | Starting item, one-shot choices → traits/XP. **IKST journal** UX. |
| ProjectFadedCar | 2.0.1 | 20 | Workshop UI, roadside, **optional IKFRVP detect**, UI scale. **IKFRVP + IKappaID_UI.** |
| ProximityAutoRead | 1.2.1 | 1 | Auto-read nearby literature via vanilla timed actions. QoL. |
| RVsReborn | 0.2.7 | 42 | Interiors + dashboard + admin; maps. Vehicles + IKST protect interiors. |
| SalvagedFuelRecoveryStation | 2.0.1 | 6 | Placeable fuel manufacture. Economy / tiles / WEX. |
| SaveTheBabies | 0.3.1 | 17 | Server persist + care GUI + FTN/FAM soft hooks. Persist+GUI pattern. |
| SimpleOverhaulTraitsAndOccupations | 1.0.3 | 14 | Server trait progression + icons. Occupations. |
| SkillBook Expansion | 0.1.1 | 3 | Missing B42 skill books. **OmniPacking.** |
| SolarNeverFaded | 1.1.0 | 30 | Server power graph + three-panel UI + CSR/WEX. **IKST utilities + IKappaID_UI.** |
| SpongiesFadedClothing_B42Port | 21.42.20.5 | 6 | Clothing hide-model via **public** body-location rebuild (`reset` / `setHideModel`). 42.20.2: `getDeclaredField` crashes Kahlua. Clothing packs; no Java reflection. (They wrap with `tryCall` — we still don’t.) |
| SpongiesFadedJackets | 19 | 4 | Open-cloth variants. Clothing. |
| Survivors | 0.42.20 | 164 | NPC port; CSR bridge; claims. **Faction / Resonance / IKST** NPC-safe claims. Uses `pcall` heavily — don’t copy. |
| TeaTime | 1.0.1 | 12 | Teas + cafe props. Items. |
| TempControl | 1.0.1 | 10 | Server HVAC schedules. IKST utilities. |
| TheBigTreeFix | 0.3.2 | 8 | Save-loadable canopy fade; filter XL trees near roads. World/tiles. |
| TheLastTestament | 1.0.1 | 12 | Custom parchment reader window. **IKappaID_UI** reading chrome. |
| ThePathLessTraveled | 1.0.2 | 7 | Skills 10–15 + server permanent buffs. Progression; UI cells. |
| ThePriceWePay | 0.2.3 | 16 | Arrest/restraint/escort server. **Cell phone 911 / Faction.** |
| TheYoungDiedToo | 1.0.1 | 13 | Native IsoZombie conversion, population-neutral. Zombie variety. Uses `pcall`. |
| tsarslib | 3.27 | 65 | Shared lib; MP timed actions; SP ModData. How a **library mod** should behave for IKappaID_UI consumers. |
| UpdateTheRealm | 0.2.1 | 3 | Dedicated Workshop update watch + safe restart. Ops / host tooling. |
| Water Expanded | 2.4.0 | 147 | Server pipe/fuel **graph**; optional FJL. **IKST utilities.** |
| WaterFaded | 1.1.1 | 6 | Fixture expiry + tap filters. Smaller WEX sibling. |
| WhatAWreck | 1.0.0 | 4 | Server wreck spawn pools vs burnt cars. Vehicles / world. |
| WhimsyWeapons | 0.3.3 | 1 | Five custom melees. Items. |
| YearsFaded | 0.31.2 | 57 | Years-later overlays; geometry-safe blood/generators. World aging / Resonance look. |

**Java Loader bridges (Lua fallback required):** ISync, Water Expanded, Hunters Calling, Buildcraft UI, The Hive, MyOnlyFriend, Echoes NPCs, KnoxReborn hybrid/lighting. Lua must stay complete without the agent.

---

## UI deep scan (HyperOS — do not copy palettes)

ClearView is two skins in one pack: **purple glass** on vanilla inventory, and **ErgUI near-black + orange `#F25F00`**. We keep HyperOS `#FF6B35`, not their purple or ErgUI orange number.

| Idea | Where seen | IKappaID use |
|------|------------|--------------|
| Named viewport rects (`craft` / `build` / `dock`) + resize signature | Buildcraft, Hunters, Feastcraft, Character Creator | IKST Q1–Q4 / Jobs layout |
| Virtual list (pooled ~visible×1.5 rows) | Buildcraft | Claim/job catalogs |
| Font-relative metrics (`rowHeight = Small + 8`) | Character Creator | All panels at 1.0 / 1.5 / 2.0 UI scale |
| Client **ini whitelist** for window xy/wh (not ModData) | GPS, ClearView ErgUI / speed HUD | Persist chrome locally |
| Sparing accent: 2px top bar, left nav pill, underline on active tab | Mod Sorter, KnoxNet, Feastcraft | IKST_Chrome / IKappaID_UI |
| Three **sibling** windows so the world stays clickable | Buildcraft, Hunters | Claim tools vs one overlay |
| One window when it is a workstation | Feastcraft, ACC, KnoxNet | Hub / Jobs |
| Access check **before** constructing admin UI | ACC | IKST staff |
| Offline/empty app copy as first-class UI | KnoxNet | **IKST-done** (Guard “waiting for server”); Phone Shop / hub |
| 18px resize grip + always-on-top only for modals | GPS, Mod Sorter | Already in UI rules |

**Skip:** Tetris/Notloc, monkey-patch `ISInventoryPage` / `ISWorldMap` / minimap, `tryCall`/`safeCall(fn)` wrappers, mega-files (Feastcraft ~2.9k, Character Creator loadout ~4.5k), hardcoded English chrome, 20-tab ACC kitchen sink, hair/3D avatar, neon green CRT.

---

## MP deep scan (authority / persist)

| Idea | Where | Do |
|------|-------|----|
| Join grace (~15s) + queue commands until ClientHello | Packet Savior | **IKST-done** (15s mutate hold + `retryAfterMs`; no 100-packet queue) |
| Payload clone/validate: depth 6, 200 keys, 4096 chars, finite numbers | Packet Savior | **IKST-done** (`IKST_Args.sanitize`) |
| Observe-first: corrections **off** until sandbox opt-in | ISync | IKFRVP / vehicle damage |
| Token bucket (burst 20 / 8 per sec) + SteamID rate key | Locomotion | IKST RateLimit |
| Prefixed durable ids (`fl:train:`, `pzrv:ts:sqlId`, `KT_n_x_y_z`, `ikst:`) | Locomotion, RVs, KnoxTransit | PinkSlip / IKST |
| Dual index (lot ↔ vehicle, card ↔ balance, stop ↔ coords) | RVs, FTN, KnoxTransit | Claims / economy |
| Physical object owns the amount; GMD is topology only | Water Expanded | Tiles / utilities |
| Replacement **ticket** (scriptName + reason), not `getId()` | Vehicles Reborn | **IKST-done** (relocate backup by `IKST_vkey`; PinkSlip still owns tickets) |
| Idempotent payout key `user:quest:hour` | Field Ops | Phone Shop / economy |
| Clock/votes in **RAM**; persist only if reboot must keep them | MP Chrono | IKST time tools |
| Square modData **does not** persist as a DB | RVs (they abandoned it) | Never use squares as registry |
| Nested `player.modData.quests` is not MP authority | Field Ops | Server commands + GMD |
| `grantItem` / client `costCents` / client rep | Field Ops | **Skip** — re-validate from whitelist |
| Nested `PFC` / `WEX` blobs on parts/objects | PFC, WEX | **IKST-done** (journal + shop prices flattened; still skip PFC/WEX blobs) |
| FastMoveCheat default on | RVs | **Skip** |
| FJL MP handshake: plugin-hash + nonce; kick if client loader/manifest mismatch | Java Loader Bridge | **Skip for IKappaID** — we do not require FJL. Idea: fail-closed when a **required** peer plugin is missing |
| Handshake / session key = `onlineID:username` | Java Loader Bridge | **Skip** — `getOnlineID()` recycles; use account/Steam key |
| B42.20.2: no Lua Java reflection (`getDeclaredField` / Class indexing) | Spongie clothing port | Clothing / any hide-model tweak: public BodyLocation APIs only |

**CSR extras vs what IKST already shipped:**

1. **Candidate keys** — stored `csr:` then live/stored `sql:`, not a single stamp only.
2. **Physical claim-key item** (`keyId` + token + owner SteamID); ignition keys can count.
3. Registry is truth; vehicle modData is a **mirror**; keep the durable key after unclaim.
4. Once a durable key exists, do not require script-name match.

IKST already stamps `IKST_vkey` and refuses recycled `getId()`. sqlId bind is unique-only (skip if two rows share it). Candidate lookup + optional key item are later tickets, not a copy of CSR.

---

## Extra packs the remaining-mod pass highlighted

- **FAM:** per-command cooldowns, clinical consent grants, timed-action tombstones — IK UI / Resonance.
- **SolarNeverFaded:** sprite-typed power banks + KnoxNet API — IKST utilities.
- **UpdateTheRealm:** dedicated Workshop poll, countdown, wait-for-empty restart — host ops.
- **ThePriceWePay:** AccessLevel allowlist; server restraint, not client flags — Faction / 911.
- **FadedSkies:** bounded helicopter fire contract; owner applies zombie health — IKFRVP if we fly.
- **MVP API:** `Vehicles[fullName]` + `legacyFullNames` — identity aliases, still don’t persist `getId()`.
- **EchoesOfHumanity:** Java-authoritative NPCs; Lua late-binds a global bridge and no-ops if missing. Resonance/Faction if we ever ship NPCs.
- **KnoxReborn:** map hybrid; hometown knowledge is register-only (no public reveal-coords). Power mission is server-side when FJL is present.
- **Spongie clothing port:** rebuild body-location groups instead of mutating private Java lists.

---

## By IKappaID repo (do next)

| Repo | Packs to mine first |
|------|---------------------|
| **IKappaID_UI** | Buildcraft, Character Creator, Feastcraft, FAM, Hunters, ClearView tokens, GPS layout persist, PFC scale, KnoxNet hub density, Last Testament reader, Solar three-panel |
| **Suite Tools** | CSR, ACC, Packet Savior, Fundamentals, DebugMeNot, ErrorDetected, GPS waypoints, Locomotion claims, MP Chrono, Solar/WEX/TempControl, Codex/Parents journal, Field Ops (protect), UpdateTheRealm |
| **PinkSlip** | Vehicles Reborn tickets, RVs `pzrv:` string id, CSR candidate keys / claim-key item (idea), MVP `getId()` footgun |
| **IKFRVP** | PFC bridge, ISync impact, RideOrRot tow, MassiveKI5/MVP APIs, FadedSkies if flying |
| **Phone Shop / Economy** | Trade Network, KnoxTransit, KnoxNet banking, Salvaged fuel |
| **Faction** | FTN treasury, Field Ops reputation, The Price We Pay, Survivors |
| **Resonance** | Field Ops, Hive, Afflictions, Armageddon, Years Faded, Faiths, Echoes NPC roles (Lua-only) |
| **ZombieBuddy** | ISync / WEX / FHC / BCR / Hive / MOF / Echoes Java bridges (detect FJL, never require) |
| **OmniPacking** | Skill Book Expansion, More Variety Loot |
| **Cell phone** | Price We Pay, Packet Savior join, KnoxNet cameras |

---

## Faded Java Loader (found)

Not a Workshop pack. Installed into the **game directory**: `steamapps/common/ProjectZomboid/FadedJavaLoader/` (`install-kind`: `CLIENT_WINDOWS`).

| Piece | What it is |
|-------|------------|
| `FadedJavaLoader-Agent.jar` | JVM `-javaagent` on `ProjectZomboid64.bat` |
| `FadedJavaLoader-Native.dll` | `-agentpath` in `ProjectZomboid64.json` |
| `plugins/` | Empty on this install — plugins ship inside mods as `42/java/*.jar` (Echoes) |
| `FadedJavaLoaderBridge` mod | Lua handshake + `isAvailable()`; Java fills a narrow bind |

**IKappaID policy:** do not copy the agent, native DLL, or launch-bat patches. Do not make FJL a Workshop dependency. Detect `FadedJavaLoaderBridge.isAvailable()` only if a feature can accelerate; **Lua path must work with the agent absent**. Dedicated/listen hosts would need a matching agent — we will not require that.

**Failure modes to remember:** launch files get rewritten (`.fjl-hotfix-backup`); MP clients without the same plugin hashes get movement-blocked then kicked; handshake keyed on recycled `getOnlineID()`.
