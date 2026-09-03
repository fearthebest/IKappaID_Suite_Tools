# IKST suite law — SoftBody frontend, SoftTools feature UI

**NON-NEGOTIABLE.** Soft hub layout must stay clean: absolute content rects, no crushed bands, no overlap. Ship **100% IKappaID** Lua and assets.

**Binding for:** IKappaID Suite Tools core + Admin / Tiles / Vehicles / Economy / Loot (soft hub).  
**Implement with:** IKappaID Lua + dark grey / orange (`IKappaID_UI`).

## One approach only (total soft refactor)

**The old mod is gone.** There is **one** UI architecture for the entire suite:

| Live | Dead — do not keep, extend, or hybridize |
|------|------------------------------------------|
| Soft hub: `IKST_Hub` → `IKUI_Shell` → `IKST_SoftPageHost` → HubNav → SoftTool_* / Page* | Old JobsPanel dock as a parallel shell |
| Soft bodies only: `IKUI_SoftBody` (+ JobLayout soft aliases) | Equal `splitBands` / `listPillSplit` dock strips as primary layout |
| One content rect; box model + `contains` | Guessed `y`, crushed equal stacks, overlap “fix later” |
| Primary actions **in soft** | Primary CTAs that open a second floating window (`EconomyUI`, `ClaimPermissionsUI`, etc.) |
| World context / radial for **acquire** only | Duplicate acquire CTAs fighting the soft manage surface |

- **No hybrids** — soft + floating primary, soft + dock, or “temporary” dual paths.
- **Floating windows** are not a second product UI. If a detach exists, it is optional **Open window** only and must not be the primary soft CTA.
- **Refactor target:** convert or delete leftover dock / dual-window / auto-select paths until every workspace matches this law. Do not patch the old shape to look soft.

Claim-specific rules: [`CLAIM-UX-LAW.md`](CLAIM-UX-LAW.md).

## Before any soft UI edit (gate)

1. Read this file + `HUB-NAV-SCHEMA.md`.
2. Layout **only** via `IKUI_Layout` / `IKST_UI_Layout` box model: `box` → `inset` → `rowIn`/`columnIn` → `contains` before place.
3. Soft tool body: `softMasterDetail` | `softPageBands` | `softStackBands` / `toolBands` with heights ≥ content (`fieldActionBandH`, `compactPillBandH`).
4. **Forbidden on soft:** equal `splitBands` / `splitCompactFlex`; placing a control then clamping it onto another; guessing `y` without a parent content rect.
5. If `contains(parent, child)` would be false, **fix the budget** (taller band / narrower child) — never draw overlap.

## Pillars (must match)

| # | Idea | IKST implementation |
|---|------|---------------------|
| 1 | One window: header + sidebar + content | `IKUI_Shell` |
| 2 | Pages register once; switch hide/show | `IKUI_Shell.registerPage` / `switchPage` via `IKST_Hub` |
| 3 | Page fills `contentArea` from width/height | Soft host `_softContentRect`; Job bodies use `toolContentRect` |
| 4 | Sidebar = workspace pages | Shell nav → Everyone / Claim / Utilities / … |
| 5 | In-page tool rail = tools for that page | `IKST_HubNav` + SoftPageHost tool rail |
| 6 | One tool = one body | SoftPageHost paints only `navTool` |
| 7 | Layout from page size; no crushed equal stacks | Soft helpers above — never soft `splitBands` |
| 8 | Outer scroll only when content taller than view | `SoftPageHost` calls `SoftBody.finish` after tool paint |
| 9 | Resize: stretch live, rebuild on release | `IKUI_Shell` rebuildWanted |
| 10 | Chrome owns paint; pages compose widgets | `IKUI_Chrome`; Job* only place controls |
| 11 | State survives rebuild where possible | SoftPageHost drafts + select ids |
| 12 | Server authority for mutations | UI is not security |

## Soft body layout

Prefer **`IKUI_SoftBody`** from SoftTools. JobLayout soft helpers (`softMasterDetail` / `softPageBands` / `softStackBands`) **delegate** to SoftBody when loaded.

| Tool shape | SoftBody / JobLayout |
|------------|----------------------|
| Primary list + actions | `masterDetail` / `softMasterDetail` (~280 list \| detail) |
| One flex + fixed footers | `pageBands` / `softPageBands` |
| Multi section stack | `stack` / `softStackBands` / `toolBands` |
| Field + action | `fieldAction` / `placeFieldActionCorner` |
| Single full card | `section` at `contentRect` height |
| Finish scroll | `SoftBody.finish` — **`IKST_SoftPageHost` only**; SoftTools return content bottom, never call `finish` |

## Ownership

| Concern | Owner |
|---------|--------|
| Window / pages / resize | `IKappaID_UI` (`IKUI_Shell`) |
| Soft body layout API | `IKappaID_UI` (`IKUI_SoftBody`) — frontend only |
| Box model APIs | `IKUI_Layout` (wrappers: `IKST_UI_Layout`) |
| Workspace list + tool ids | `IKST_HubNav.WORKSPACES` |
| Soft host (rail + scroll) | `IKST_SoftPageHost` |
| Feature soft paint entry | `IKST_SoftTool_*` (core + addons); SoftPageHost prefers SoftTool over Job* |
| Job* builders | Thin soft aliases + dispatch/request helpers; SoftTools own SoftBody paint |
| Theme | `IKUI_Chrome` (dark grey + orange) |

**Frontend vs feature UI:** `IKUI_SoftBody` = shared soft layout (IKappaID_UI). SoftTools = per-workspace feature UI.

**Phase 5 SoftBody-native SoftTools:** Claim, Everyone, Admin, Utilities, Home helpers, Economy, Vehicle, Loot, Tiles — paint via SoftBody only under soft shell.

Addons register **builders** for tool ids (`buildJobTools` → SoftTool). No second in-page tab strip that duplicates HubNav.

## Conversion / review rule

When touching any Job builder: if it still uses dock `splitBands`, `listPillSplit` as primary, or opens a floating window from a primary soft CTA, **convert or delete in the same change** — do not leave a hybrid. Overlap is a ship blocker. Soft equal `splitBands` is forbidden.

See also: `docs/HUB-NAV-SCHEMA.md`.

## Soft refactor closeout (2026-09)

Soft hub only: `IKST_Hub` → `IKUI_Shell` → SoftPageHost → SoftTool. Primary CTAs stay in soft (Claim perms, Briefing Rules, Economy shop, Help tickets). Action log is not a hub satellite. Job* `build` aliases SoftTool. StaffRemoteAdmin default off + DANGER tooltip. Optional Economy **Open window** detach only.
