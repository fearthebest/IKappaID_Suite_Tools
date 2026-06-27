# IKST Security Audit — Baseline 0.2.5 → Tier C Testing

## Baseline 0.2.5 findings (pre-Tier C)

- Permissions scattered across plugins and `playerMayRunCommand`
- Client-trusted utilities (`SandboxOptions:sendToServer`)
- Client-trusted weather on admin client path
- Economy-only 400ms throttle
- No server audit log
- No lock brute-force protection

## Tier C testing build status

| Item | Status |
|------|--------|
| `COMMAND-MATRIX.md` | Complete |
| `IKST_ServerGate.authorize` | Implemented |
| Server utilities (`quickWater`/`quickPower`) | Implemented |
| MP weather via `dispatchCommand` | Implemented |
| `IKST_RateLimit` | Implemented |
| `IKST_AuditLog` | Implemented |
| `IKST_Args` validation | Partial (giveItem, coords, locks, protect) |
| `REDTEAM-TIER-C.md` | Template — **manual pass pending** |
| `SECURITY.md` / `ADMIN-RUNBOOK.md` | Published |

## Remaining gaps (Tier C+ / follow-up)

- Dedicated-server weather may still require admin client JVM (PZ API limit)
- Economy transaction ledger (dispute resolution)
- HMAC / nonce on commands (likely skip)
- Full handler migration to `IKST_Args` helpers in every ops file
