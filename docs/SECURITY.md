# IKST Security — Tier C Threat Model

**Mod:** IKappaID Suite Tools · **Tier:** C (testing build)

## What we assume

- Attackers control their game client and can call `sendClientCommand` with arbitrary args.
- UI hiding is not security; only the **dedicated server JVM** may authorize sensitive actions.
- Co-op / listen hosts are trusted for local server paths (documented limitation).

## What Tier C protects

| Area | Mechanism |
|------|-----------|
| All server commands | `IKST_ServerGate.authorize` before handlers |
| Staff/admin tools | `StaffToolsEnabled` sandbox + access level admin |
| Utilities (water/power) | Server `quickWater` / `quickPower` + `utilitySync` |
| Rate abuse | `IKST_RateLimit` per command group |
| Lock brute force | Per-player lockout after `LockMaxAttempts` fails |
| Audit | `[IKST-AUDIT]` console lines + ModData ring buffer |
| Economy distance | Server revalidates ATM/shop distance |
| Claims | Server ownership checks; list size capped |

## What IKST does NOT protect

- Speed hacks, wall hacks, vanilla dupes, Lua injection in general
- Weather on dedicated server if PZ requires an admin **client** JVM for climate (server returns clear error)
- Co-op host cheating (host runs server locally)
- Compromised admin accounts with `StaffToolsEnabled=true`

## Known limitations

- `auditTail` command shows recent log to staff in client action log (not a full SIEM).
- Rate limits are per-username ephemeral tables (reset on server restart).
- Tier C+ (HMAC, IP ban hooks) not implemented.

See `docs/ADMIN-RUNBOOK.md` for operator guidance.
