# IKST — PZ-AI-Dev-Guidance compliance audit

**Guidance repo:** [fearthebest/PZ-AI-Dev-Guidance](https://github.com/fearthebest/PZ-AI-Dev-Guidance)  
**Mod:** IKappaID Suite Tools · **Build:** `42.18/` · **Branch:** `cursor/tier-c-testing-05ab`  
**Audit date:** 2026-06-27  
**Checklist source:** `AI-DEV-GUIDANCE/MOD-QUALITY-CHECK.md` + `cursor-rules/pz-security-safety-first.mdc`

**Legend:** `[x]` pass · `[!]` fail / known issue · `[~]` partial · `[ ]` not verified in this run

**Pass bar (guidance):** Every **Blocker** must pass before Workshop upload / public MP.

---

## Summary scorecard

| Section | Blockers pass | Warnings pass | Ship? |
|---------|---------------|---------------|-------|
| §1 Lua / MP authority | **6 / 14** | partial | **No** |
| §2 Stability | mostly | partial | — |
| §3 Code quality | — | partial | — |
| §4 Networking | 0 / 3 tested | partial | **No** |
| §5 Items / sandbox | **5 / 5** | partial | Yes |
| §6 UI | — | pass | Yes |
| §7 Repository | — | partial | — |
| §8 Test matrix | **0 / 8** | — | **No** |
| §9 Grep audit | **2 / 2** | partial | — |
| §10 Content / IP | **2 / 2** | pass | Yes |

**Verdict (0.2.4):** P0 security fixes implemented. Run `REDTEAM-TIER-C.md` on IB before public MP ship.

---

## §1 Blockers — documentation and research

| Item | Status | Notes |
|------|--------|-------|
| Live Unstable build confirmed | [~] | Targets `42.18`; user runs B42.19 — test on live build |
| PZwiki read before MP changes | [x] | Networking patterns documented in `docs/COMMAND-MATRIX.md` |
| MP/modData matches Networking wiki | [!] | Lock passwords + economy store synced as authority — violates wiki intent |

---

## §1 Blockers — Lua absolutes

| Item | Status | Notes |
|------|--------|-------|
| Zero `pcall` / `xpcall` / `tryCall` / `safeCall` | [x] | Grep clean across 115 Lua files |
| No `obj:method and obj:method()` | [x] | Grep clean |
| No Lua `next()` | [x] | Hits are Java iterator `:next()` only |
| Server JVM guard on all `server/*.lua` | [!] | **11 / 20** server files lack top guard (see below) |
| Client JVM guard on all `client/*.lua` | [x] | 53 / 53 use `isServer() and not isClient()` pattern |

**Server files missing JVM guard (guidance Blocker):**

- `IKST_GuardOps.lua`, `IKST_StaffOps.lua`, `IKST_WorldOps.lua`, `IKST_VehicleUtil.lua`, `IKST_RestoreServer.lua`
- `IKST_VehicleOps.lua`, `IKST_TilesWorldOps.lua`, `IKST_TilesGuardOps.lua`, `IKST_ProtectOps.lua`, `IKST_CommandQueue.lua`, `IKST_AutomationOps.lua`

**Fix:** Add standard guard as first lines (same as `IKST_Server.lua`).

---

## §1 Blockers — multiplayer authority

Maps to `pz-security-safety-first.mdc` trust model.

| Item | Status | Notes |
|------|--------|-------|
| Server mutates synced world state in MP | [x] | Claims, economy, tiles, loot via server ops |
| Remote clients don't double-apply | [x] | `utilitySync` / result commands for client UI |
| `modData` not auto-synced authority | [!] | `IKST_Locks` passwords + `IKST_Economy` full store synced |
| Identity from event `player`, not client username | [x] | `OnClientCommand` uses `playerObj`; staff targets resolved server-side |
| Client payloads validated | [!] | `IKST_Args` only in gate for 4 families; coords/IDs often raw |
| Server re-checks range / ownership | [!] | ATM bank, claims, locks missing distance (see P0 in `AUDIT-SECURITY-DEV.md`) |
| Fail closed + server log | [x] | `ServerGate.deny` + `IKST_AuditLog` |

---

## §1 Blockers — assets, packaging, security

| Item | Status | Notes |
|------|--------|-------|
| B42 item script format | [x] | `module IKST { item ... }` pattern |
| Placeholder / valid icons | [x] | Custom icons present |
| Recipes reference loaded items | [x] | |
| `mod.info` id matches folder | [x] | `IKappaIDSuiteTools` etc. |
| Build folder `42.18/` | [x] | |
| Workshop tree — no dev files in `Contents/` | [x] | No `.md` / `.cursor` in ship tree |
| Edits in git → sync to Workshop | [~] | Dual `IKST_Workshop/` + `Workshop/` — drift risk |
| Clean load — no SEVERE | [ ] | Manual — user had orphan `IKST_RecipeGate.lua` locally |
| No secrets in Lua/git | [!] | Lock **passwords** stored in ModData (operator data, not API keys) |
| Economy/spawn server-only + verify | [~] | Server-only writes; ATM distance gap |
| Admin actions server-gated; default deny | [x] | `ServerGate` + sandbox flags |
| Rate limit ~500 ms on abusable commands | [x] | `IKST_RateLimit` — groups from 400 ms–12 s |

---

## §2 Stability (warnings)

| Item | Status | Notes |
|------|--------|-------|
| No full-world OnTick scans | [~] | `GuardHooks.onTickSafehouses`, `WorldPick.onTick` — scoped/throttled |
| Boot APIs gated | [x] | `IKST_Lifecycle.worldReady`; StaffOps climate lazy-load |
| ModData shape validation | [~] | Partial; corrupt entries not uniformly skipped+log |
| OnTick catch enforcement | [x] | `IKST_Server.onTickCatch` every 30 ticks — intentional |

---

## §3 Code quality (warnings)

| Item | Status | Notes |
|------|--------|-------|
| Smallest correct diff | [x] | Tier C focused changes |
| One path per concern | [~] | `IKST_Plugins` registry — **documented exception** (multi-addon suite) |
| No copied Workshop mod code | [x] | Original IKappaID |
| Standalone unless approved deps | [x] | Optional addons via `require=`; PhoneShop soft bridge |
| Version unchanged unless asked | [x] | `0.2.3` |

Guidance prefers no plugin/registry for one-offs; IKST is intentionally a **hub + addon suite** — keep registry but document in mod README.

---

## §4 Networking

| Item | Status | Notes |
|------|--------|-------|
| SP tested | [ ] | Manual |
| Listen-host / co-op tested | [ ] | Manual |
| Dedicated server (IB) tested | [ ] | `REDTEAM-TIER-C.md` unchecked |
| Allowlisted command strings | [x] | `IKST.CMD.*` constants |
| Single `OnServerCommand` router | [x] | `IKST_Z_Bootstrap.onServerCommand` |
| No trust of client coords/IDs/prices | [!] | **Fails** — P0 items in security audit |

**B42 branch pattern:** IKST uses `isClient()` / `isServer()` / SP integrated paths in `IKST_Shared.dispatchCommand` — aligned with guidance §4.

---

## §5 Items, recipes, sandbox

| Item | Status | Notes |
|------|--------|-------|
| `sandbox-options.txt` `VERSION = 1` | [x] | All 5 addons |
| Locale `EN` folders | [x] | |
| `craftRecipe` with inputs/outputs | [x] | Journal, keypad, shop terminal |
| ATM admin-only — no recipe | [x] | Script + server command pattern |

---

## §6 UI and client

| Item | Status | Notes |
|------|--------|-------|
| UI in `client/` only | [x] | |
| `IKST_Chrome.lua` house style | [x] | Dark + orange |
| Singleton panel (`JobsPanel.instance`) | [x] | |
| World mutations via server command | [x] | `dispatchCommand` / `sendClientCommand` |
| Exception: `setUtilityOn` MP client API | [!] | Still callable — P0-5 |

---

## §7 Repository and workflow

| Item | Status | Notes |
|------|--------|-------|
| Private GitHub repo | [x] | `fearthebest/IKappaID_Suite_Tools` |
| Workspace at git root | [x] | |
| Dev docs in `docs/` not `Contents/` | [x] | |
| Sync script for Workshop | [~] | Manual dual-tree copy; add robocopy script |
| Guidance repo linked | [x] | This audit references PZ-AI-Dev-Guidance |

---

## §8 Test matrix — not executed

All rows **unchecked** in repo. Required before ship per guidance:

- SP load + feature + save/reload
- IB dedicated + 2 clients
- Remote client cannot dupe items/money
- `REDTEAM-TIER-C.md` rows 1–10

---

## §9 Automated grep (2026-06-27)

```bash
# From IKST_Workshop/
rg -n "pcall|xpcall|tryCall|safeCall" --glob "*.lua"     # 0 matches ✓
rg -n "sendClientCommand" --glob "*.lua"                  # 8 refs → IKST_Shared + ClientNet ✓
rg -n "OnClientCommand" --glob "*.lua"                    # IKST_Server.lua ✓
```

---

## §10 Content and IP

| Item | Status | Notes |
|------|--------|-------|
| No third-party franchise in ship text | [x] | |
| Dangerous sandbox labeled / conservative defaults | [x] | Tier C security options documented |

---

## Mapping: guidance rules → IKST P0 fixes

| Guidance rule (`pz-security-safety-first`) | IKST gap | Fix |
|---------------------------------------------|----------|-----|
| Never trust client coordinates | `bankGate`, claims, locks | `playerNearCoord` / `actorNearCoord` |
| Never trust client vehicle/item IDs | `vehicleClaim` | Server proximity resolve |
| `modData` untrusted; server owns sync writes | Lock passwords synced | Server-only hash; redacted sync |
| No secrets in mod Lua | Passwords in `IKST_Locks` | Hash or server-only store |
| Clients request; server commits | `setUtilityOn` in MP | Client no-op |
| Rate-limit abusable commands | Mostly done | Extend to all economy/claim paths |
| Server JVM guard on server files | 11 files | Add top-of-file guard |

---

## Recommended actions (priority)

1. Fix P0 security items (`docs/AUDIT-SECURITY-DEV.md`)
2. Add server JVM guards to 11 server Lua files
3. Run `MOD-QUALITY-CHECK.md` §8 on IB + update `REDTEAM-TIER-C.md`
4. Add Workshop sync script; single canonical tree (`IKST_Workshop` → `Workshop`)
5. Copy `PZ-AI-Dev-Guidance` cursor rules to maintainer machine; link from `README.md`

---

## Per-mod notes (§13)

```
Mod name:        IKappaID Suite Tools
Build folder:    42.18
Last full check: 2026-06-27
Checked by:      Cursor agent (guidance cross-audit)
Known issues:    P0 coords/ModData; 11 server guards; IB tests pending
MP sign-off (IB): not yet
```

---

## Related

- [AUDIT-SECURITY-DEV.md](./AUDIT-SECURITY-DEV.md) — detailed P0/P1/P2
- [SECURITY.md](./SECURITY.md) — Tier C threat model
- [REDTEAM-TIER-C.md](./REDTEAM-TIER-C.md) — attack checklist
- [PZ-AI-Dev-Guidance](https://github.com/fearthebest/PZ-AI-Dev-Guidance) — canonical rules
