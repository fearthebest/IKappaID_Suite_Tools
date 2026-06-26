# IKappaID Suite Tools

Build 42 admin and player toolkit for Project Zomboid: safehouse and vehicle claims, recovery journal, server utilities, and optional **World Edit**, **Vehicles**, **Economy**, and **Loot** addons.

[![Steam Workshop](https://img.shields.io/badge/Steam-Workshop-blue)](https://steamcommunity.com/sharedfiles/filedetails/?id=3750835193)
[![Version](https://img.shields.io/badge/Version-0.2.3-green)](https://github.com/fearthebest/IKappaID_Suite_Tools)
[![Build](https://img.shields.io/badge/Project%20Zomboid-Build%2042-orange)](https://pzwiki.net/wiki/Build_42)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Overview

IKappaID Suite Tools is a hub panel (`Ctrl+Shift+W`) for multiplayer servers and the players on them. The base mod covers claims, recovery journal, and staff tools. Optional addons add world editing, vehicle admin, player economy (with [IKappaID Phone Shop](https://steamcommunity.com/sharedfiles/filedetails/?id=3749926419)), and admin loot repopulation.

## Mod IDs

| Addon | Mod ID |
|-------|--------|
| Base | `IKappaIDSuiteTools` |
| Economy | `IKappaIDSuiteToolsEconomy` |
| World Edit / Tiles | `IKappaIDSuiteToolsTiles` |
| Vehicles | `IKappaIDSuiteToolsVehicles` |
| Loot | `IKappaIDSuiteToolsLoot` |

Enable only the addons your server needs.

## Repository layout

| Path | Purpose |
|------|---------|
| `IKST_Workshop/` | Steam Workshop upload tree (`Contents/mods`, `workshop.txt`, `preview.png`) |
| `CHANGELOG.md` | Version history |
| `docs/ASSETS-CREDITS.md` | Third-party tile art attribution |

## Steam publish

1. Edit Lua and assets under `IKST_Workshop/Contents/mods/`.
2. Bump `modversion` in each addon `mod.info`.
3. Upload from `IKST_Workshop/` using the in-game Workshop uploader.
4. Add a **Change note** on Steam (see `CHANGELOG.md`); keep the main Workshop description stable unless intentionally rewritten.

## Art credits

Economy tile sprites (`ikst_economy_01`) are 2D renders from CGTrader models (Royalty Free). See [docs/ASSETS-CREDITS.md](docs/ASSETS-CREDITS.md).

## Links

- **Steam Workshop:** https://steamcommunity.com/sharedfiles/filedetails/?id=3750835193
- **Ko-fi:** https://ko-fi.com/ikappaid

Community mod — not affiliated with or endorsed by The Indie Stone.
