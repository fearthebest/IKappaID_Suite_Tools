# IKappaID Suite Tools

Build 42 admin and player toolkit for Project Zomboid: safehouse and vehicle claims, recovery journal, server utilities, and optional World Edit, Vehicles, Economy, and Loot addons.

[![Steam Workshop](https://img.shields.io/badge/Steam-Workshop-blue)](https://steamcommunity.com/sharedfiles/filedetails/?id=3750835193)
[![Version](https://img.shields.io/badge/Version-0.3.2.5-green)](https://steamcommunity.com/sharedfiles/filedetails/?id=3750835193)
[![Build](https://img.shields.io/badge/Project%20Zomboid-Build%2042-orange)](https://pzwiki.net/wiki/Build_42)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Overview

IKappaID Suite Tools is a hub panel (`Ctrl+Shift+W`) for multiplayer servers and the players on them. The base mod covers claims, recovery journal, and staff tools. Optional addons add world editing, vehicle admin, player economy (with IKappaID Phone Shop), and admin loot repopulation.

## Mod IDs

| Addon | Mod ID |
|-------|--------|
| Base | `IKappaIDSuiteTools` |
| Economy | `IKappaIDSuiteToolsEconomy` |
| World Edit / Tiles | `IKappaIDSuiteToolsTiles` |
| Vehicles | `IKappaIDSuiteToolsVehicles` |
| Loot | `IKappaIDSuiteToolsLoot` |

Enable only the addons your server needs.

## Repository structure

```text
.
├── README.md
├── CHANGELOG.md
├── LICENSE
├── docs/
│   └── LICENSED-ART.md        # Licensed economy tile attribution (ship line only)
└── IKST_Workshop/             # Steam Workshop upload tree
    ├── workshop.txt
    ├── preview.png
    └── Contents/
        └── mods/
            ├── IKappaIDSuiteTools/42.18/
            ├── IKappaIDSuiteToolsEconomy/42.18/
            ├── IKappaIDSuiteToolsTiles/42.18/
            ├── IKappaIDSuiteToolsVehicles/42.18/
            └── IKappaIDSuiteToolsLoot/42.18/
```

Edit Lua and assets under `IKST_Workshop/Contents/mods/`. Upload from `IKST_Workshop/` using the in-game Workshop uploader.

## Steam publish checklist

1. Edit Lua and assets under `IKST_Workshop/Contents/mods/`.
2. Bump `modversion` in each enabled addon `mod.info`.
3. Upload from `IKST_Workshop/`.
4. Add a change note on Steam (see `CHANGELOG.md`). Keep the main Workshop description stable unless intentionally rewritten.

## Licensed art

Economy tile sprites (`ikst_economy_01`) use royalty-free source models; see `docs/LICENSED-ART.md` for the Workshop credit line.

## Links

- **Steam Workshop:** https://steamcommunity.com/sharedfiles/filedetails/?id=3750835193
- **Support:** https://ko-fi.com/ikappaid

Community mod — not affiliated with or endorsed by The Indie Stone.
