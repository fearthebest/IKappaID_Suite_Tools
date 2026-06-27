# Local install — IKappaID Suite Tools (Tier C testing)

## From this repository

Copy the entire folder:

```text
Workshop/IKappaID Suite Tools/
```

to your Project Zomboid Workshop directory:

```text
C:\Users\mpass\Zomboid\Workshop\IKappaID Suite Tools\
```

(or `%UserProfile%\Zomboid\Workshop\IKappaID Suite Tools\` on Windows)

## Zip download

Pre-packaged archive (same contents):

```text
releases/IKappaID-Suite-Tools-TierC-Testing.zip
```

Extract so you have:

```text
IKappaID Suite Tools\
  workshop.txt
  Contents\mods\
    IKappaIDSuiteTools\42.18\
    IKappaIDSuiteToolsEconomy\42.18\
    ...
```

## In-game

1. Enable all addons you need in the main menu mod list.
2. Start or join a server (dedicated recommended for Tier C tests).
3. Check server console for `[IKST] ... Tier C gate` on load.

## Git branch

Tier C testing code: `cursor/tier-c-testing-05ab`

## Troubleshooting

If you see **`IKST_RecipeGate.lua: attempted index of non-table`** at startup, delete that file from your local mod copy — it is not part of official IKST. See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
