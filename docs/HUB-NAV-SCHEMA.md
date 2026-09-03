# IKST hub nav schema (Aegis-inspired)

**Whole-suite law:** [`AEGIS-SUITE-LAW.md`](AEGIS-SUITE-LAW.md) — Aegis architecture for all of IKST, not pagination alone.

**Law:** One workspace = one shell page. One tool = one left-rail tab = one scroll body.  
**Patterns only from Aegis** — HyperOS orange; no Aegis Lua/assets.  
**Owners:** `IKST_HubNav.WORKSPACES` (canonical tabs) + addon `buildJobTools` (content only).

## How Aegis paginates (study → our code)

| Aegis | IKappaID |
|-------|----------|
| `AegisWindow.registerPage` + `switchPage` (hide/show, create once) | `IKUI_Shell.registerPage` + `switchPage` |
| `contentArea()` = full window minus sidebar/header | same in `IKUI_Shell` |
| Page lays out from **`self.height` / `self.width`** | Soft host sets `_softContentRect` to the viewport |
| **Players:** left list ~280px fills height; right detail fills rest | `IKST_JobLayout.softMasterDetail` + soft Players/Admin builders |
| Actions adapt `stepY` to available height | right column `softPageBands` / pill groups sized to `areaW` |
| Outer scroll only if `designH > contentH` | Soft scroll only when content bottom exceeds viewport |
| Tool tabs = separate shell pages or in-page groups | Shell pages = workspaces; HubNav rail = tools |

## Soft body layout (suite-wide)

| Shape | Helper |
|-------|--------|
| SoftTool entry | `IKST_SoftTool_*` → `IKUI_SoftBody` |
| List + actions | `SoftBody.masterDetail` / `softMasterDetail` |
| Flex + fixed footers | `SoftBody.pageBands` / `softPageBands` |
| Multi section stack | `SoftBody.stack` / `toolBands` / `softStackBands` |
| Forbidden on soft | equal `splitBands` / `splitCompactFlex` |

## Shell pages (left chrome) — Aegis → IKST

| Aegis page | IKST workspace | Who |
|------------|----------------|-----|
| dashboard | `home` | core |
| (player blue) | `everyone` | core |
| zones / factions | `claim` | core |
| powers / players / items / world / horde | `utilities` tools | core |
| tools (builder/clear/inspect) | `tiles` | Tiles addon |
| vehicles | `vehicles` | Vehicles addon |
| — | `economy` | Economy addon |
| — | `loot` | Loot addon |
| roles / moderation | `admin` | Admin addon |

## Tool tabs (rail inside a workspace)

### Everyone
| Tool id | Body |
|---------|------|
| `overview` | Server day / online / claim counts |
| `claims` | Public claim list |
| `events` | Event join/return / unstuck |
| `help` | Help request, report, tickets, rules |

### Claim
| Tool id | Body |
|---------|------|
| `overview` | Claim dashboard |
| `requests` | Staff claim queue |
| `safehouses` | Safehouse claim ops |
| `vehicleclaim` | Vehicle claim ops |
| `catch` | Freeze / catch (staff) |

### Utilities (staff)
| Tool id | Aegis cousin | Body |
|---------|--------------|------|
| `self` | powers | God / noclip / self cheats |
| `items` | items / kits | Give / item cheats |
| `players` | players | Master–detail (list \| care/help/clearance) |
| `zombies` | horde | Threat / zombie tools |
| `servertools` | world / server | Time, weather, power/water |
| `teleport` | — | Waypoints / TP |
| `batch` | — | Batch staff ops (MP) |

### Tiles (staff)
`overview` · `remove` · `paint` · `inspect` · `blueprints` · `area` · `protect`

### Vehicles (staff)
`overview` · `spawn` · `repair` · `prune`

### Economy
`money` · `shop` · `valuables` · `admin` (staff)

### Loot (staff)
`loot`

### Admin (staff)
`ghost` · `kick` · `ban` — each tool is master–detail (list \| action)

## Rules for addons

1. Register **builders** (`buildJobTools` / SoftTool) keyed by tool id — do not invent a second in-page tab row when soft shell owns the rail.
2. `hubTools` may list tools; HubNav already lists them — `toolsForWorkspace` **dedupes by id**.
3. SoftPageHost paints **only** the active `navTool` body.
4. Never dump another workspace’s tools into this page’s scroll.
5. Soft layout helpers only — see [`AEGIS-SUITE-LAW.md`](AEGIS-SUITE-LAW.md).
