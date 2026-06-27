# IKST Sandbox Options — Tier C Security

Base mod page: **IKappaID Suite Tools**

## Tier C security options (new)

| Option | Default | Purpose |
|--------|---------|---------|
| `StaffToolsEnabled` | true | Master gate for staff/admin server commands |
| `EnableThreatTools` | true | `threatCull`, `threatPopulation` |
| `EnableCatchJail` | true | catch/release player commands |
| `EnableUtilitiesToggle` | true | Global water/power server commands |
| `RateLimitEnabled` | true | Server-side throttles |
| `AuditLogEnabled` | true | Console + ModData audit |
| `AuditLogMaxEntries` | 500 | Ring buffer size |
| `ClaimListMaxSize` | 200 | Cap list query responses |
| `LockMaxAttempts` | 20 | Wrong passwords before 60s lockout |
| `LockInstallDistance` | 3 | Tiles for keypad install |
| `StaffRemoteAdmin` | false | Skip actor-near check on protect radius |

## Rate limit groups (when `RateLimitEnabled=true`)

| Group | Default | Commands |
|-------|---------|----------|
| economy_write | 400ms | deposit, withdraw, wire, vend*, shop |
| economy_read | 1/s | snapshot, vendList |
| staff_give | 1/s | giveItem, giveKit, giveTarget |
| staff_tp | 1/s | teleport commands |
| staff_power | 1/s | heal, god, clearZombies, catch |
| threat_cull | 5s | threatCull |
| lock_auth | 5/min | lockTryUnlock (+ lockout) |
| list_query | 1/s | *List, dumpPlayers |
| claim_write | 1/s | claims, journal |
| utility | 1/s | quickWater, quickPower |

Existing claim and economy options unchanged — see base `sandbox-options.txt`.
