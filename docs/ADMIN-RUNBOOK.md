# IKST Admin Runbook — Public Server (Tier C)

## Recommended sandbox profile

| Option | Public server | Notes |
|--------|---------------|-------|
| `StaffToolsEnabled` | true when admin on duty | Set **false** when no active staff |
| `EnableThreatTools` | false | Enable only for events |
| `EnableCatchJail` | true | Requires audit review |
| `EnableUtilitiesToggle` | false or moderator-only | Global grief risk |
| `RecoveryJournalEnabled` | false on PVP public | Combat restore abuse |
| `ClaimAdminBypass` | false | Admins follow claim rules |
| `RateLimitEnabled` | true | |
| `AuditLogEnabled` | true | |
| `StaffRemoteAdmin` | false | Force admins near radius actions |

## Audit log

- **Console:** grep server log for `[IKST-AUDIT]`
- **ModData:** key `IKST_AuditLog`, field `entries` (ring buffer)
- **In-game:** staff can run `auditTail` via dispatch (logged in action log)

## Incident response

1. Set `StaffToolsEnabled=false` in sandbox and restart server.
2. Pull console audit lines for the incident window.
3. Roll back ModData backups if safehouse/economy corruption suspected.
4. Disable `EnableUtilitiesToggle` if water/power grief occurred.

## If something “breaks”

Classify before treating it as an IKST defect:

1. **IKST bug** — a non-staff player **kept** money, a claim, guarded loot, a sledged/picked-up claim tile, or a staff command after ~1s on a dedicated host you control.
2. **Operator** — sandbox too open, `StaffToolsEnabled` left on, wrong addons, forgot IKappaID_UI.
3. **Out of scope** — hacked dedicated box, listen-host cheating, vanilla speed/wall hacks.

See `docs/SECURITY.md` fault line.

## Testing checklist

See `docs/REDTEAM-TIER-C.md` — run on dedicated server with player + admin clients before go-live.
