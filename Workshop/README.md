# Local Workshop test copy

This folder holds a **local install mirror** of IKappaID Suite Tools for in-game testing. It matches the Steam upload tree in `IKST_Workshop/`.

## Install for testing

Copy or symlink this folder into your Project Zomboid Workshop directory:

| OS | Path |
|----|------|
| Windows | `%USERPROFILE%\Zomboid\Workshop\` |
| Linux / macOS | `~/Zomboid/Workshop/` |

Example (Linux/macOS):

```bash
cp -r "Workshop/IKappaID Suite Tools" ~/Zomboid/Workshop/
```

Then in Project Zomboid: **Main Menu → Mods** → enable the IKST addons you need → restart.

## Keeping it up to date

After editing files under `IKST_Workshop/`, refresh this copy:

```bash
rsync -a --delete IKST_Workshop/ "Workshop/IKappaID Suite Tools/"
```

## What is what

| Folder | Purpose |
|--------|---------|
| `IKST_Workshop/` | Canonical source — edit here, upload to Steam from here |
| `Workshop/IKappaID Suite Tools/` | Local test copy — drop into `~/Zomboid/Workshop/` |

Both trees contain the same five addons under `Contents/mods/` (`IKappaIDSuiteTools`, Economy, Tiles, Vehicles, Loot).
