# Tools integration

| Tool | Where | Account / token | What it covers | Licence / terms |
|---|---|---|---|---|
| GitHub CodeQL | `codeql.yml` (advanced setup), optional local CLI | none (free for public repos; private repos need GitHub Code Security) | SAST for JS/TS, Python, GitHub Actions | GitHub terms; CodeQL CLI licence restricts use on private code without a license |
| GitHub secret scanning + push protection | repository settings (`configure-github-security.sh`) | none for public repos | leaked credentials | GitHub terms |
| Dependabot | `.github/dependabot.yml`, alerts, security updates | none | vulnerable/outdated dependencies (npm, Composer, pip, Docker, GitHub Actions) | GitHub terms |
| Dependency Review | `security-audit.yml` (PRs) | none for public repos | new vulnerable dependencies in a PR | GitHub terms |
| Semgrep CE | `semgrep.yml`, `security-audit.yml`, local | none (registry rules downloaded at run time) | SAST, custom SaaS rules | Semgrep CE engine: LGPL-2.1; registry rules have their own licences (Semgrep Rules License) — this repository does not redistribute them |
| Snyk | `snyk.yml`, local | **`SNYK_TOKEN`** (free tier available) | dependencies, SAST (Snyk Code), IaC | Snyk terms of service |
| OWASP ZAP | `zap-baseline.yml`, `zap-full-scan.yml`, local Docker | none | DAST: headers, cookies, XSS, injection (full scan) | Apache-2.0 |
| npm audit / composer audit | local, `security-audit.yml` | none | dependency advisories | npm / Composer terms |
| Fabric | optional, local | an AI provider of your choice | AI analysis of reports via `sbs_*` patterns | MIT (Fabric); patterns here are original, MIT |

## GitHub native security

- **CodeQL**: `codeql.yml` detects languages, runs `security-extended` with `build-mode: none` and uploads
  results to *Security → Code scanning*. Weekly schedule + push + PR + manual.
  Do not enable "default setup" at the same time.
- **Secret scanning / push protection**: enable with `configure-github-security.sh` or in
  *Settings → Code security*. Public repositories have it free.
- **Branch protection**: `configure-github-security.sh` creates a ruleset (no deletion, no force-push, PR required,
  optional required checks). Choose required checks after the workflows have run once (their names appear then).
- **Alerts**: review in the *Security* tab; Dependabot security updates open PRs automatically.

## Semgrep

```bash
pipx install semgrep              # or: python3 -m pip install semgrep
semgrep scan --metrics=off --config config/semgrep/rules --config p/owasp-top-ten .
```
The framework always passes `--metrics=off`. Registry configs require network; offline runs fall back to local rules.
Semgrep AppSec Platform (`SEMGREP_APP_TOKEN`, `semgrep ci`) is **not** used — the free CLI is enough here.

## Snyk

See [config/snyk/README.md](../config/snyk/README.md). Commands used: `snyk test --all-projects`,
`snyk code test`, `snyk iac test`, with `--json-file-output` / `--sarif-file-output`. Exit codes: 0 no issues,
1 issues, 2 error, 3 no supported project.

## OWASP ZAP

- Local: `security-check.sh --zap-target http://host.docker.internal:8000` runs
  `ghcr.io/zaproxy/zaproxy:stable zap-baseline.py -t <url> -J zap.json -r zap.html -I` in Docker.
  On Linux, add your host network setup (or use the container IP). Only local hosts or hosts in
  `SBS_ZAP_ALLOWED_HOSTS` are accepted.
- CI baseline: `zaproxy/action-baseline`, target from `vars.SBS_ZAP_TARGET`, host must be in
  `vars.SBS_ZAP_ALLOWED_HOSTS`. Reports (HTML, JSON, Markdown) are uploaded as artifact `zap-baseline-report`.
- CI full scan: `zaproxy/action-full-scan`, manual only, confirmation phrase, allow-list, production deny-list,
  `security-testing` environment. **Active attacks — never against production.**

## Fabric

See [fabric/README.md](../fabric/README.md).

## Why not more tools?

Each additional scanner adds noise and maintenance. The set above covers SAST (CodeQL + Semgrep), SCA
(Dependabot + Snyk/npm/composer audit), secrets (GitHub + builtin + Semgrep), DAST (ZAP) and CI hygiene
(builtin + CodeQL actions). Extend only when a real gap appears.
