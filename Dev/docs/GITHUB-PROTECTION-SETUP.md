# GitHub protection setup — IKappaID Suite Tools

**Repo:** https://github.com/fearthebest/IKappaID_Suite_Tools  
**Default branch:** `master`

## Quick apply (recommended)

1. Install GitHub CLI: `winget install GitHub.cli`
2. Log in: `gh auth login` (as **fearthebest**, with `repo` scope)
3. From repo root:

```powershell
.\Dev\scripts\setup_github_protection.ps1
```

4. Enable **2FA** on your GitHub account (Settings → Password and authentication).

## What “optimal” means for a solo public mod repo

| Layer | Setting | Why |
|-------|---------|-----|
| Account | **2FA on** | Stops account takeover → malicious pushes |
| `master` | **Block force push** | No history rewrite / stealth overwrites |
| `master` | **Block branch delete** | Cannot wipe default branch |
| PRs from others | **1 approving review** | You must review before merge |
| PRs from others | **Require CODEOWNERS** | `.github/CODEOWNERS` → `@fearthebest` |
| PRs from others | **Resolve conversations** | No drive-by merge with open threads |
| Your workflow | **`enforce_admins=false`** | You can still push hotfixes directly to `master` |
| Merges | **Squash only** | Clean history, one commit per PR |
| Hygiene | **Delete branch on merge** | Less stale fork branches |
| Reports | **`SECURITY.md`** | Private vuln reporting path |
| Issues | **Issue template** | Structured bug reports with logs |
| Wiki | **Off** | Less spam surface |

## Manual UI path (no `gh`)

### Branch protection

1. https://github.com/fearthebest/IKappaID_Suite_Tools/settings/branches  
2. **Add branch ruleset** or **Add classic rule** for `master`  
3. Enable:
   - Require a pull request before merging → **1 approval**
   - Require review from Code Owners
   - Require conversation resolution
   - **Do not allow bypassing** — leave **off** if you want direct pushes as owner  
   - Block force pushes  
   - Block deletions  

### Code security

1. https://github.com/fearthebest/IKappaID_Suite_Tools/settings/security_analysis  
2. Enable **Dependabot alerts**  
3. Enable **Private vulnerability reporting**  
4. Enable **Secret scanning** / push protection if available on your plan  

### General

1. https://github.com/fearthebest/IKappaID_Suite_Tools/settings  
2. Features: **Wikis** off (optional)  
3. Pull Requests: allow **Squash** only; **Automatically delete head branches**

## What strangers still cannot do

- Push to `master` (unless you add them as collaborator)  
- Merge PRs without your approval (when review rules apply)  
- Change Steam Workshop files (separate from GitHub)  

## What remains public by design

- Read and fork the repo (MIT license)  
- Open Issues and Pull Requests  

## Files in this repo that support protection

| File | Role |
|------|------|
| `.github/CODEOWNERS` | PR review routing to `@fearthebest` |
| `.github/ISSUE_TEMPLATE/bug_report.yml` | Guided bug reports |
| `.github/pull_request_template.md` | PR checklist for you |
| `SECURITY.md` | Vulnerability reporting policy |
| `Dev/scripts/setup_github_protection.ps1` | One-shot `gh` setup |
