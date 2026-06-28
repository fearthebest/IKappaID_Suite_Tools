#Requires -Version 5.1
<#
.SYNOPSIS
  Apply recommended GitHub protection for fearthebest/IKappaID_Suite_Tools

.DESCRIPTION
  Requires GitHub CLI (gh) logged in as repo owner:
    winget install GitHub.cli
    gh auth login

  Run from repo root:
    .\Dev\scripts\setup_github_protection.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Repo = 'fearthebest/IKappaID_Suite_Tools'
$Branch = 'master'

function Require-Gh {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error @"
GitHub CLI (gh) is not installed.
  winget install GitHub.cli
  gh auth login
Then re-run this script.
"@
    }
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'gh is not authenticated. Run: gh auth login'
    }
    Write-Host 'GitHub CLI OK' -ForegroundColor Green
}

function Invoke-GhJson {
    param(
        [string]$Method,
        [string]$Endpoint,
        [string]$JsonBody
    )
    $tmp = New-TemporaryFile
    try {
        Set-Content -Path $tmp.FullName -Value $JsonBody -Encoding UTF8 -NoNewline
        gh api $Endpoint -X $Method --input $tmp.FullName
        if ($LASTEXITCODE -ne 0) {
            throw "gh api failed: $Method $Endpoint"
        }
    }
    finally {
        Remove-Item -Path $tmp.FullName -Force -ErrorAction SilentlyContinue
    }
}

function Set-BranchProtection {
    Write-Host "`n=== Branch protection: $Branch ===" -ForegroundColor Cyan

    # Solo-friendly: block force-push and branch delete; require review on PRs.
    # enforce_admins=false -> owner can still push hotfixes directly to master.
    $body = @'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true
}
'@

    Invoke-GhJson -Method PUT -Endpoint "repos/$Repo/branches/$Branch/protection" -JsonBody $body
    Write-Host 'Branch protection applied.' -ForegroundColor Green
}

function Set-RepoSettings {
    Write-Host "`n=== Repository merge and hygiene ===" -ForegroundColor Cyan

    gh api "repos/$Repo" -X PATCH `
        -f allow_squash_merge=true `
        -f allow_merge_commit=false `
        -f allow_rebase_merge=false `
        -f delete_branch_on_merge=true `
        -f allow_auto_merge=false `
        -f allow_update_branch=true `
        -f has_wiki=false `
        -f has_discussions=false

    if ($LASTEXITCODE -ne 0) { throw 'Repo settings patch failed' }
    Write-Host 'Merge settings: squash-only, delete branch on merge, wiki off.' -ForegroundColor Green
}

function Enable-SecurityFeatures {
    Write-Host "`n=== Security features ===" -ForegroundColor Cyan

    gh api "repos/$Repo/vulnerability-alerts" -X PUT 2>$null

    Write-Host 'Requested Dependabot vulnerability alerts (enable security updates in GitHub UI if needed).' -ForegroundColor Green
    Write-Host 'Also enable in UI: Settings -> Code security -> Private vulnerability reporting.' -ForegroundColor Yellow
}

function Show-Summary {
    Write-Host "`n=== Done ===" -ForegroundColor Cyan
    Write-Host @"
Manual checks (GitHub web UI):
  1. Account -> enable 2FA (most important)
  2. Settings -> Code security -> Dependabot + private vulnerability reporting
  3. Settings -> Branches -> confirm master rule is active

Protection model:
  - master: no force-push, no delete
  - External PRs: 1 review + CODEOWNERS (@fearthebest)
  - You (owner): can still push directly to master (enforce_admins=false)

Issues:     https://github.com/$Repo/issues
Security:   https://github.com/$Repo/security
Branches:   https://github.com/$Repo/settings/branches
"@
}

Require-Gh
Set-BranchProtection
Set-RepoSettings
Enable-SecurityFeatures
Show-Summary
