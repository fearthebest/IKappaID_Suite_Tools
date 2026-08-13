# IKST Tier C Red Team Checklist

**Environment:** Dedicated server you control, Build **42.20**, pack **0.3.2.0 BETA**, 2 clients (player + admin)  
**Status:** Manual — if all rows pass (plus SP smoke below), bump to **1.0.0.0**

**SP smoke (same pack, before or with this list):** hub `Ctrl+Shift+W`, no ErrorMagnifier, no recursive-require WARN, claim radial once on foot and once in a seat, **Move here** with trunk/glovebox loot, `console.txt` no SEVERE from IKST.

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
| 11 | Take from a claimed container you may not loot | item reversed (~1s) | ☐ |
| 12 | Sledge / pickup on a claim you may not destroy (bypass UI if you can) | tile restored; pickup item gone | ☐ |

**Also on dedicated (honest play, not attacks):** two clients, safehouse + vehicle claims and permissions, relog still shows the right owner, economy deposit/wire with Phone Shop loaded.

## Notes

- Run attacks via modified client or debug `sendClientCommand` if available.
- Verify console shows `[IKST-AUDIT]` for denies on rows 1–3, 6–7.
- After a green pass: a modified client **keeping** IKST-protected state is an IKST bug; admin mistakes / hacked dedicated / vanilla movement cheats are not (`docs/SECURITY.md` fault line).
- Then: commit the 42.20 pack, bump to 1.0.0.0, set IKappaID_UI as Steam required item on Suite Tools.
