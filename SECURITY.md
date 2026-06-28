# Security policy — IKappaID Suite Tools

## Supported versions

| Version | Supported |
|---------|-----------|
| Latest Workshop / `master` | Yes |
| Older 0.2.x | Best-effort fixes if reproducible |
| Pre–0.2.5 Tier C builds | No |

## Reporting a vulnerability

**Do not** open a public GitHub Issue for exploit details (dupes, auth bypass, remote abuse).

Please report privately via:

- **Discord:** `callmekappaid`
- **Ko-fi:** https://ko-fi.com/ikappaid
- **GitHub private report:** [Security advisories](https://github.com/fearthebest/IKappaID_Suite_Tools/security/advisories/new) (preferred if you have a GitHub account)

Include:

1. IKST version and Build 42 version  
2. Dedicated MP vs listen host vs SP  
3. Steps to reproduce  
4. Impact (e.g. remote claim, economy dupe, staff tool bypass)  
5. `DebugLog-server.txt` or relevant log excerpt  

We aim to acknowledge within **7 days**. Fixes ship in the next testing/stable release as appropriate.

## Scope

In scope: IKST server command authorization, economy/claims/locks, ModData exposure, MP client trust bugs.

Out of scope: vanilla PZ dupes, speed hacks, compromised admin accounts, listen-host trust model.

## Safe harbor

Good-faith testing on **your own server** or with **host permission** is welcome. Do not test against public servers without consent.
