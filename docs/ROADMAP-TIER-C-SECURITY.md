# IKST Tier C Security Roadmap — Large Public Server Hardening

**Mod:** IKappaID Suite Tools (IKST) · **Target:** B42.18 · **Baseline:** 0.2.5  
**Ship path:** Workshop `IKappaID Suite Tools`  
**Dev docs:** `docs/` in this repository

---

## Copy-paste prompt for Composer 2.5

**Standalone files:** [PROMPT-TIER-C-COMPOSER.md](./PROMPT-TIER-C-COMPOSER.md) · plain-text variant in uploads

Use the prompt block in those files as the **full task prompt** for an agent session. Work phase-by-phase; do not skip acceptance criteria.

---

## AI guide (any agent)

This section explains **why** each phase exists and how to execute without context loss.

### Threat model (assume true)

1. **Attackers control their client.** They can call `sendClientCommand`, patch Lua, automation tools, packet replay.
2. **UI hiding means nothing** for security. Only **server JVM** decisions matter.
3. **Honest admins can misclick.** Audit logs and sandbox toggles protect the server from admins too.
4. **PZ access levels:** `admin`, `moderator`, `gm`, `overseer`, `none`. IKST currently treats only `admin` as full tool user; moderators get utilities only. Tier C should make this **explicit in ServerGate**, not scattered.
5. **Plugins bypass** the base `playerMayRunCommand` path today — they run first with their own checks. Tier C must **not** leave plugins as a side door.

### Current architecture (baseline 0.2.5)

```
Client UI → IKST.dispatchCommand → sendClientCommand(IKST.MODULE, cmd, args)
                                              ↓
Dedicated server → Events.OnClientCommand → IKST_Server.handleCommand
                                              ├→ IKST.Plugins.handleServerCommand (economy/tiles/loot/vehicles)
                                              ├→ IKST_Server.playerMayRunCommand
                                              └→ IKST_GuardOps / IKST_StaffOps / IKST_WorldOps / ...
```

**Known weak points:**

| Area | Issue | Tier C fix |
|------|-------|------------|
| Utilities | Client `SandboxOptions:sendToServer()` | Server commands + authorize |
| Weather | Client `ClimatePresets` on admin client path | Server gate + MP routing rules |
| Plugins | `canUseAdmin = canUseTools` ignores StaffTools sandbox | Use `canUseStaffTools` |
| Locks | No brute-force limit | Rate limit + lockout |
| Staff cmds | No rate limit | Rate limit groups |
| Audit | Client ActionLog only | Server audit log |
| Permissions | Duplicated checks | `IKST_ServerGate.authorize` |

### Key files (start here)

| File | Role |
|------|------|
| `shared/IKST_Access.lua` | Role + sandbox policy (client + server) |
| `server/IKST_Server.lua` | Main command router |
| `shared/IKST_Plugins.lua` | Addon command dispatch |
| `shared/IKST_Shared.lua` | CMD constants, STAFF/GUARD/PLAYER command sets |
| `shared/IKST_Utility.lua` | Water/power (client-trust risk) |
| `client/IKST_ClientStaff.lua` | Weather/time (client-trust risk) |
| `server/IKST_EconomyOps.lua` | Economy server (has throttle) |
| `server/IKST_GuardOps.lua` | Claims, catch, safehouse |
| `server/IKST_StaffOps.lua` | Heal, give, TP, waypoints |
| `shared/IKST_EconomyRegister.lua` | Economy plugin registration |
| `shared/IKST_TilesRegister.lua` | Tiles plugin registration |
| `docs/COMMAND-MATRIX.md` | Phase 0 inventory (command contract) |

### Definition of done — Tier C

- [x] `COMMAND-MATRIX.md` complete for all commands
- [ ] `IKST_ServerGate.authorize` enforces every server command path including plugins
- [ ] No sensitive action relies on client-only sandbox/climate apply in MP
- [ ] Rate limits on economy, locks, staff power commands
- [ ] Server audit log with console + ring buffer
- [ ] `REDTEAM-TIER-C.md` — all P0 tests pass on dedicated server
- [ ] `SECURITY.md` + `ADMIN-RUNBOOK.md` published in dev docs
- [ ] Known limitations documented honestly

### Implementation order (strict)

0 → 1 → 2 → 3 → 4 → 6 (parallel with 5) → 5 → 7 → 8 → 9

See [PROMPT-TIER-C-COMPOSER.md](./PROMPT-TIER-C-COMPOSER.md) for full phase acceptance criteria.

---

*Last updated: 2026-06-27 — Phase 0 complete in repo*
