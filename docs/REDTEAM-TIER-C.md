# IKST Tier C Red Team Checklist

**Environment:** Dedicated server B42.18, 2 clients (player + admin)  
**Build:** Tier C testing branch  
**Status:** Manual verification required in-game

| # | Attack | Expected | Pass |
|---|--------|----------|------|
| 1 | Non-admin `sendClientCommand` healSelf | Denied + `[IKST-AUDIT]` deny | ☐ |
| 2 | Non-admin giveItem | Denied | ☐ |
| 3 | Non-admin backupSafehouses | Denied | ☐ |
| 4 | Spoof economyWithdraw far from ATM | too far | ☐ |
| 5 | Spam lockTryUnlock | rate limited / lockout | ☐ |
| 6 | Spoof quickWater as player | not allowed / utilities disabled | ☐ |
| 7 | StaffToolsEnabled=false, admin healSelf | staff tools disabled | ☐ |
| 8 | vehicleClaim other player's vehicle | not your claim / need key | ☐ |
| 9 | economyVendSetPrice on another's shop | not owner | ☐ |
| 10 | Rapid duplicate vendBuy packets | no dupe, throttle | ☐ |

## Notes

- Run attacks via modified client or debug `sendClientCommand` if available.
- Verify console shows `[IKST-AUDIT]` for denies on rows 1–3, 6–7.
- Do not ship public Tier C until all P0 rows pass.
