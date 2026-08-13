# IKST Security — Threat Model

**Mod:** IKappaID Suite Tools · **Tier:** C (accepted for 1.0 if red-team passes)

## What we assume

- Attackers **fully control their game client** (patched Lua, forged `sendClientCommand`, skipped UI wraps).
- UI hiding is not security. Only the **dedicated server JVM** may change IKST-protected state.
- A **compromised dedicated server** (host OS, server Lua, admin with `StaffToolsEnabled`) is **out of scope**. That is not a mod bug.
- Co-op / listen hosts **are** the server JVM. A cheating host is the same class as a hacked server.

## Goal

A modified client must not keep any IKST-protected change: claims, protect, shops/locks, economy balances, staff tools, guarded tiles, guarded containers, claimed vehicles. Vanilla engine actions that Lua cannot cancel mid-packet are **reversed on the server** (`IKST_TransferServer`, `IKST_DestroyServer`).

## What IKST protects (server JVM)

| Area | Mechanism |
|------|-----------|
| All IKST commands | `IKST_ServerGate.authorize` before handlers |
| Staff/admin tools | `StaffToolsEnabled` sandbox + access level admin |
| Utilities (water/power) | Server `quickWater` / `quickPower` + `utilitySync` (`setUtilityOn` is SP-only) |
| Rate abuse | `IKST_RateLimit` per command group |
| Lock brute force | Per-player lockout after `LockMaxAttempts` fails |
| Audit | `[IKST-AUDIT]` console lines + ModData ring buffer |
| Economy | Server distance, ownership, check-then-commit |
| Lock passwords | Server-only hashes; clients get `IKST_LocksPublic` flags only |
| Claims | Server ownership + proximity |
| Guarded loot | `IKST_TransferServer` reverse (~1s) |
| Guarded tiles (sledge / pickup / grief build) | `IKST_DestroyServer` reverse (~1s); staff World Edit allowlists the square |
| Claimed vehicles | Server `IKST_GuardOps.enforceVehicleClaim` |

## What is vanilla PZ (not IKST)

- Speed hacks, wall hacks, aim bots, vanilla item dupes that never touch a guarded container
- Weather on dedicated if the engine requires an admin **client** JVM for climate

## Known engine limits (still server-reversed, not cancelled mid-packet)

- Java `ItemTransaction` and vanilla destroy cannot be aborted from Lua. Reverse is the authority path.
- Loot `trimDuplicateContainers` clears extra contents; it cannot always remove the extra IsoObject.
- `SafeHouse.allowSafeHouse` is skipped if the method is missing on that JVM.
- Dual UI kits are frozen: hub = IKappaID_UI; jobs = `IKST_Chrome`.

## Fault line (1.0)

**IKST’s job:** a modified client must not **keep** IKST-protected state (commands, money, claims, guarded loot, guarded tiles, claimed vehicles). If they still have it after the server reverse (~1s), that is an IKST bug.

**Not IKST’s job:**

| If this happens | Whose fault |
|-----------------|-------------|
| Admin left `StaffToolsEnabled` on and griefed | Operator |
| Sandbox lets guests destroy/loot and they do | Operator (config) |
| Listen / co-op host cheats | Host **is** the server |
| Dedicated process / server Lua / OS is compromised | Hacked server — out of scope |
| Speed hack, wall hack, aim bot, vanilla dupe off a **unguarded** world container | Vanilla PZ |
| Brief flash of a stolen item/tile before reverse | Engine (Lua cannot cancel the Java packet) |
| Weather tools need an admin client JVM | Engine |

Honest-client UI wraps are convenience only. They are not the lock.

See `docs/ADMIN-RUNBOOK.md` for operator guidance.
