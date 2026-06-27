# IKST Security & Development Audit

**Mod:** IKappaID Suite Tools · **Build:** B42.18 / B42.19 · **Repo branch:** `cursor/tier-c-testing-05ab`  
**Audit date:** 2026-06-27  
**Baseline:** Tier C testing build (`IKST_ServerGate`, `IKST_RateLimit`, `IKST_AuditLog`, `IKST_Args`)

**Guidance reference:** [PZ-AI-Dev-Guidance](https://github.com/fearthebest/PZ-AI-Dev-Guidance) — full checklist cross-walk in [`PZ-GUIDANCE-COMPLIANCE.md`](./PZ-GUIDANCE-COMPLIANCE.md). This audit also uses IKST’s `docs/SECURITY.md`, `docs/COMMAND-MATRIX.md`, `docs/REDTEAM-TIER-C.md`, and standard PZ MP rules: **server JVM is authoritative; never trust client coords, IDs, or sandbox mutations.**

---

## Executive summary

| Area | Grade | Notes |
|------|-------|-------|
| Command authorization (Tier C) | **B+** | `IKST_ServerGate.authorize` runs before every handler — good foundation |
| Input validation | **C** | `IKST_Args` exists but only covers 4 command families in the gate |
| ModData / secrets | **D** | Lock passwords plaintext + synced to all clients |
| Client-trust surface | **C-** | Utilities UI fixed; `setUtilityOn` API still callable in MP |
| Documentation | **B** | Strong Tier C docs; some claims ahead of code |
| Dev hygiene | **C+** | Dual Workshop trees, dead code, no automated tests |

**Do not ship Tier C to a hostile public server until P0 items below are fixed and `REDTEAM-TIER-C.md` rows pass.**

---

## What Tier C got right

1. **Single gate before handlers** — `IKST_Server.handleCommand` calls `IKST_ServerGate.authorize` first; plugins run only after allow (`IKST_Server.lua`).
2. **Server utilities** — `quickWater` / `quickPower` on server JVM + `utilitySync` to clients (UI paths use `toggleUtilityForPlayer`).
3. **Rate limiting** — `IKST_RateLimit` groups for staff, economy, locks, claims.
4. **Audit trail** — `[IKST-AUDIT]` console + ModData ring buffer; denies logged via `ServerGate.deny`.
5. **Economy write protection** — `mayMutateStore()` blocks client JVM balance mutations.
6. **Transfer hooks** — `IKST_TransferGuard` on server JVM for container/vehicle rules.
7. **Load-order hardening** — `IKST_StaffOps` avoids aliasing `IKST_ClimatePresets` at require time.
8. **Operator docs** — `SECURITY.md`, `ADMIN-RUNBOOK.md`, sandbox security options.

---

## P0 — Fix before public MP

### P0-1: Lock passwords synced to all clients

**Files:** `IKST_Locks.lua`, `IKST_ModDataSync.lua`

Passwords are stored in global ModData key `IKST_Locks` and transmitted to every client. Any modified client can read `ModData.getOrCreate("IKST_Locks")` and bypass keypad UI + rate limits.

**Fix:** Store server-only (hash or opaque token). Sync only per-player unlock state via `lockUnlockSync`. Remove `Locks` from client sync or redact `locks` table on transmit.

---

### P0-2: Remote ATM banking (spoofed coordinates)

**Files:** `IKST_EconomyOps.lua` (`bankGate`, `deposit`, `withdraw`, `exchange`, `idCardReissue`)

`bankGate` checks that `(x,y,z)` is an ATM square but **not** that the player is near it. Handler uses client `args.x/y/z` (`EconomyOps.handle` ~1487). `vendBuy` already uses `playerNearCoord` — bank ops do not.

**Red-team:** `REDTEAM-TIER-C.md` row 4 (“too far”) **fails today**.

**Fix:** Add `IKST_Economy.playerNearCoord(player, x, y, z, atmMaxDist)` inside `bankGate`. Prefer server-derived coords for player actions.

---

### P0-3: Remote vehicle claim via `vehicleId`

**File:** `IKST_GuardOps.lua` ~702–744

If `args.vehicleId` is set, no proximity check. Default `VehicleClaimRequireKeys` is false → claim any unclaimed vehicle map-wide.

**Fix:** For non-admin, resolve vehicle server-side (`nearestId`) or verify `vehicleId` within `getVehicleNearRadius()`.

---

### P0-4: Remote safehouse claim via spoofed coordinates

**File:** `IKST_GuardOps.lua` ~475–480, 663–667

`safehouseClaim` accepts client `args.x/y` without `actorNearCoord`.

**Fix:** Non-admin claims must use player position or pass distance gate.

---

### P0-5: Client utility API still trusted in MP

**File:** `IKST_Utility.lua` ~114–138

UI routes through server commands, but `IKST.setUtilityOn` → `SandboxOptions:sendToServer()` remains callable on the MP client JVM.

**Fix:** No-op `setUtilityOn` on MP client; only `setUtilityOnServer` + `utilitySync` may change utilities.

---

## P1 — High priority hardening

| ID | Finding | Location | Recommendation |
|----|---------|----------|----------------|
| P1-1 | `lockTryUnlock` has no distance check | `ServerGate.lua`, `TilesGuardOps.lua` | Add `actorNearCoord` (sandbox `LockTryDistance`) |
| P1-2 | Tiles lock `canUsePlayer` = any online player | `IKST_TilesRegister.lua` | Require `IKST_ClaimPolicy.playerClaimsEnabled()` |
| P1-3 | Full economy store synced to clients | `IKST_Economy.lua` `persistStore` | Per-player snapshots only (`economySnapshotResult`) |
| P1-4 | `economyVendSetPrice` / `economyVendDisable` no distance | `IKST_EconomyOps.lua` | Add `playerNearCoord` like `vendBuy` |
| P1-5 | `IKST_Args` barely used in ops handlers | Economy, Guard, Tiles ops | Extend gate + centralize parsing |
| P1-6 | `IKST_Server.playerMayRunCommand` dead code | `IKST_Server.lua:24–32` | Remove or wire; avoid dual auth paths |
| P1-7 | `economyOps.throttle()` never called | `IKST_EconomyOps.lua:17–28` | Remove dead code or integrate |
| P1-8 | Plugin success audit skips player-tier economy | `IKST_Server.lua` | Log deposits/wires on success |

---

## P2 — Development & maintainability

| ID | Finding | Recommendation |
|----|---------|----------------|
| P2-1 | Duplicate `IKST_Workshop/` and `Workshop/` (115 Lua files each) | Single canonical tree + publish script |
| P2-2 | No automated tests | Unit tests for `ServerGate.authorize`, `bankGate`, `IKST_Args` |
| P2-3 | `COMMAND-MATRIX.md` describes pre–Tier C flow in §1.1–1.4 | Refresh to match `ServerGate` order |
| P2-4 | `SECURITY.md` claims economy distance revalidation | Update after P0-2 fix or soften claim |
| P2-5 | `canOpenPanel` returns true for all players | Document as intentional shell; gate actions in UI |
| P2-6 | Debug `print` in economy placement | Gate behind sandbox debug flag |
| P2-7 | `REDTEAM-TIER-C.md` manual — all rows unchecked | Run dedicated-server pass before release |
| P2-8 | Version drift (`0.2.3` code vs `0.2.5` docs) | Align doc baseline labels |

---

## Command flow (current Tier C)

```
Client → sendClientCommand("IKST", cmd, args)
              ↓
Server JVM → IKST_Server.handleCommand
              ↓
         IKST_ServerGate.authorize   ← all commands
              ↓ deny → audit + result
         IKST.Plugins.handleServerCommand (economy/tiles/loot/vehicles)
              OR base handlers (Staff/Guard/Threat/…)
```

**Not bypasses:** `runServerCommand` (SP/co-op host) still goes through `handleCommand` → `authorize`.

---

## ModData sensitivity matrix

| Key | Synced to clients? | Sensitive? | Action |
|-----|-------------------|------------|--------|
| `IKST_Locks` | Yes | **Passwords plaintext** | P0-1 |
| `IKST_Economy` | Yes | All account balances | P1-3 |
| `IKST_VehicleClaim` | Yes | Ownership metadata | OK for UI |
| `IKST_SafehouseClaim` | Yes | Claim metadata | OK for UI |
| `IKST_Protect` / `IKST_WorldRules` | Yes | Protection rules | OK |
| `IKST_AuditLog` | Server-focused | Staff actions | OK |

---

## Sandbox profile (public server)

See `docs/ADMIN-RUNBOOK.md`. Minimum for hostile MP:

- `StaffToolsEnabled` — false when no staff on duty
- `StaffRemoteAdmin` — false (force proximity for radius/protect)
- `RateLimitEnabled` / `AuditLogEnabled` — true
- `EnableUtilitiesToggle` — false on PVP public
- `RecoveryJournalEnabled` — false on PVP public
- `ClaimAdminBypass` — false

---

## Recommended fix order

1. P0-1 Lock password sync
2. P0-2 ATM `playerNearCoord`
3. P0-3 / P0-4 Claim proximity
4. P0-5 MP client utility no-op
5. P1-2 Tiles lock policy alignment
6. P1-3 Economy store sync reduction
7. Extend `IKST_Args` + `ServerGate.checkRateAndArgs`
8. Run `REDTEAM-TIER-C.md` on dedicated server
9. Refresh `COMMAND-MATRIX.md` / `SECURITY.md`
10. Consolidate Workshop trees; add tests

---

## PZ-AI-Dev-Guidance alignment

Full MOD-QUALITY-CHECK cross-walk: [`PZ-GUIDANCE-COMPLIANCE.md`](./PZ-GUIDANCE-COMPLIANCE.md).

| Guidance theme | IKST status |
|----------------|-------------|
| Server authority for MP mutations | Partial — gate yes; coords/secrets gaps |
| No client-trusted globals | Partial — utilities API remains |
| Input validation at boundary | Partial — `IKST_Args` underused |
| Secrets never on client | **Fail** — lock passwords in ModData |
| Zero `pcall` | **Pass** |
| Server JVM guards on all server Lua | **Fail** — 11 / 20 files |
| Red-team / IB sign-off before ship | **Fail** — not executed |
| Single source tree | Partial — dual Workshop copies |
| MOD-QUALITY-CHECK Blockers | **6 / 14 pass** — do not ship public MP |

---

## Related docs

- [SECURITY.md](./SECURITY.md) — threat model
- [COMMAND-MATRIX.md](./COMMAND-MATRIX.md) — command inventory
- [REDTEAM-TIER-C.md](./REDTEAM-TIER-C.md) — manual attack checklist
- [ADMIN-RUNBOOK.md](./ADMIN-RUNBOOK.md) — operator guide
- [AUDIT-0.2.5.md](./AUDIT-0.2.5.md) — Tier C implementation status
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — load errors (orphan files)
- [PZ-GUIDANCE-COMPLIANCE.md](./PZ-GUIDANCE-COMPLIANCE.md) — PZ-AI-Dev-Guidance checklist
