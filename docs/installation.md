# Installation

saas-blind-security is copied **into** the SaaS project you want to protect. Requirements: `bash` (3.2+),
`git`, `jq`. Every scanner is optional; see [tools-integration.md](tools-integration.md).

## 1. Clone the framework

```bash
git clone https://github.com/IbrahimCodeur/saas-blind-security.git
cd saas-blind-security
./scripts/validate-environment.sh
```

## 2. Copy it into your project

```bash
./scripts/install.sh --dry-run /path/to/your-saas   # preview
./scripts/install.sh /path/to/your-saas
```

What is installed (existing files are never overwritten unless you pass `--force`):

| Source | Destination in your project |
|---|---|
| `scripts/`, `config/`, `fabric/`, `templates/` | `.saas-blind-security/` |
| `config/sbs.conf.example` | `.saas-blind-security/sbs.conf` |
| security workflows | `.github/workflows/` (`codeql`, `semgrep`, `snyk`, `zap-baseline`, `zap-full-scan`, `security-audit`, `dependabot-auto-review`) |
| generated `dependabot.yml` | `.github/dependabot.yml` (only if absent; ecosystems detected from your manifests) |
| `.claude/skills/*` | `.claude/skills/` |
| `CLAUDE.md` | `CLAUDE.md`, or `.saas-blind-security/CLAUDE.security.md` if you already have one — then add the line `@.saas-blind-security/CLAUDE.security.md` to your `CLAUDE.md` |

`.sbs-results/` is added to your `.gitignore`.

Manual alternative: copy the same folders yourself; workflows look for `.saas-blind-security/` and fall back to
the repository root.

## 3. Configure variables and secrets

Local: edit `.saas-blind-security/sbs.conf` ([configuration.md](configuration.md)).

GitHub → *Settings → Secrets and variables → Actions*:

| Name | Type | Required | Purpose |
|---|---|---|---|
| `SNYK_TOKEN` | secret | no | enables `snyk.yml` |
| `SBS_FAIL_ON_SEVERITY` | variable | no | blocking level, default `HIGH` |
| `SBS_SEMGREP_CONFIGS` | variable | no | registry rules, default `p/owasp-top-ten`, `none` to disable |
| `SBS_ZAP_TARGET` | variable | no | staging URL for the baseline scan |
| `SBS_ZAP_ALLOWED_HOSTS` | variable | for ZAP | hosts you are authorised to scan |
| `SBS_ZAP_PRODUCTION_HOSTS` | variable | recommended | hosts the full scan must refuse |
| `SBS_ZAP_FAIL_ON` | variable | no | ZAP blocking level, default `HIGH` |
| `SBS_DEPENDENCY_REVIEW_FAIL_ON` | variable | no | `low`/`moderate`/`high`/`critical`, default `high` |
| `SBS_DEPENDABOT_AUTOMERGE` | variable | no | set to `patch` to auto-merge patch updates after checks pass |

For the manual full scan, create the environment **security-testing** (*Settings → Environments*) with
required reviewers.

## 4. Enable the workflows and GitHub security features

Commit and push. Then (needs the GitHub CLI and admin rights):

```bash
./.saas-blind-security/scripts/configure-github-security.sh OWNER/REPO --dry-run
./.saas-blind-security/scripts/configure-github-security.sh OWNER/REPO --reviews 1 \
  --required-checks "Security audit,Semgrep scan"
```

This enables Dependabot alerts and security updates, secret scanning with push protection (public repos or
plans that include it), and a ruleset protecting the default branch. Do **not** also enable CodeQL
"default setup": `codeql.yml` is an advanced setup.

## 5. Run the first audit

```bash
cd /path/to/your-saas
./.saas-blind-security/scripts/security-check.sh --check-only
./.saas-blind-security/scripts/security-check.sh --report
```

## 6. Review the report

Open `.sbs-results/<timestamp>/report.md`. Check the *Coverage* table first: tools that did not run mean
risk areas that were not checked. Triage each finding (confirmed / false positive / not verified).

## 7. Fix

Ask your AI agent (e.g. Claude Code) to follow `CLAUDE.md` and the `security-remediation` skill, or fix
manually. Re-run step 5 and compare.

## Updating

Pull the new framework version and run `install.sh --force` on a clean working tree; review the diff before
committing. Your `sbs.conf` is overwritten only with `--force` — back it up first.
