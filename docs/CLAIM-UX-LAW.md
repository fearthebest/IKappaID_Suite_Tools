# Claim UX law — dual path (request vs self-claim)

**Shell:** [`SOFT-HUB-LAW.md`](SOFT-HUB-LAW.md) — soft hub only. Ship IKappaID Lua and assets only.

## Two acquire modes

| Mode | When | Player does | Server rules |
|------|------|-------------|--------------|
| **Claim request** | `ClaimHouseRequestEnabled` | Walk **A→B** on **any** land (open ground or any building) → queue | Soft: size, overlap, PhunZones. **No** residential / road auto-reject. Staff decide. |
| **Self-claim** | `ClaimHouseSelfService` | Stand on spot → **size** or **whole building** → Claim | Strict sandbox: roads, near-SH buffer, min/max tiles, optional square. Building mode stays residential. |

Staff path for requests: **Claim → Requests** → select → **TP** + **highlight** → **Apply borders** (edit W×H) → **Approve** / **Deny**.

## Soft Claim UI

1. **Request-only:** hide Size / Claim mode bands; Actions = Ask staff (A→B) + list/manage.  
2. **Self-claim on:** keep Claim mode + Size + Claim here; land rules on square size claims.  
3. **Manage** (Overview / list): invites, members, perms, release — selection-gated; no auto-select.

## Soft Claim → Overview (manage)

1. Get a claim / pending invite Accept/Decline.  
2. List — empty copy only until explicit select.  
3. Actions gated on selection.  
4. Layout: `softMasterDetail` / bands + `contains`.

## World / radial

Acquire on world when policy allows; hub manages after.

## Checklist

- [ ] Request submit works on empty lot (not residential-only)
- [ ] Staff TP + orange highlight on selected request
- [ ] Staff can resize W×H then approve
- [ ] Self-claim road / near-SH sandbox toggles work
- [ ] No third-party code pasted
