# IKST UI guardrails

## Framework dependency

Suite Tools requires **IKappaID UI Framework** (`mod.info`: `require=\IKappaID_UI`).

- **Canonical chrome:** `IKappaID_UI/IKUI_Chrome.lua` — require directly; do not add local chrome copies.
- **Layout tokens:** `IKappaID_UI/IKUI_Config.lua`, `IKUI_Layout.lua`
- **Widgets:** `IKappaID_UI/IKUI_Widgets.lua` (`IKUI_ScrollHost`, rich-text scroll helpers)

- `IKST_JobsPanel`, job modules, hub navigation content
- `IKST_JobLayout` (suite geometry: log dock, armed banner height, quadrants)
- Business logic, server commands, translations, mod icons

## Workshop load order

Players and MP hosts need **both**:

1. IKappaID UI Framework
2. IKappaID Suite Tools

## Intellectual property (strict)

IKST and IKappaID_UI ship **only IKappaID-original** Lua, scripts, and assets.

| Allowed | Not allowed |
|---------|-------------|
| Vanilla PZ APIs (`ISUI/*`, `TimedActions/*`, TIS JavaDoc/wiki links in dev comments) | `require` or paste from other Workshop mods |
| IKappaID_UI + IKST addon chain in `mod.info` | Third-party UI libraries or frameworks |
| Optional runtime bridge to **IKappaID Phone Shop** (Economy addon; guarded, not in `mod.info`) | Copying Lua, textures, or layout from other authors' mods |
| Licensed 2D tile renders with attribution in `docs/LICENSED-ART.md` | Study notes, mod dumps, or reference trees inside this repo |

External mod study (patterns only) belongs in a **local untracked** overlay (`private/`), never in `Contents/` or git `docs/`.

Scroll UI uses `IKUI_ScrollView` / `IKUI_ScrollBar` for widget lists (jobs hub). **Action log** uses Briefing-style `ISRichTextPanel` + vanilla scrollbars (`IKUI_Widgets.configureRichText`).
