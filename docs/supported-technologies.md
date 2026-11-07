# Supported technologies

**Detection** means `detect-stack.sh` recognises the technology (heuristic, tested against fixtures in
`tests/fixtures/`). **Scanning** lists which configured tool actually analyses it. "Guidance" means the skills
and checklist cover it but no automated scanner in this framework analyses its configuration.

Legend: ✅ configured and tested in this repository's test suite · ☑️ configured, depends on the external
tool/service (not exercised by this repository's tests) · ➖ not covered.

## Backend

| Technology | Detection | Custom Semgrep rules | CodeQL | Snyk | Native audit | Notes |
|---|---|---|---|---|---|---|
| PHP | ✅ | ✅ `php-saas.yaml` | ➖ (CodeQL has no PHP support) | ☑️ composer | ☑️ `composer audit` | normaliser tested with sample output |
| Laravel | ✅ | ✅ Eloquent/DB raw, mass assignment, Blade, uploads | ➖ | ☑️ | ☑️ | |
| Node.js | ✅ | ✅ `javascript-saas.yaml` | ☑️ `javascript-typescript` | ☑️ npm | ☑️ `npm audit` | |
| Express.js | ✅ | ✅ SQLi, XSS, SSRF, traversal, webhooks, CORS, JWT | ☑️ | ☑️ | ☑️ | |
| NestJS | ✅ | partial (`enableCors`, generic JS rules) | ☑️ | ☑️ | ☑️ | no NestJS decorator-specific rules yet |
| Python | ✅ | ✅ `python-saas.yaml` | ☑️ `python` | ☑️ pip (deps must be installed) | ➖ (pip-audit not integrated) | |
| Django | ✅ | ✅ raw/extra SQL, `mark_safe`, `csrf_exempt`, DEBUG | ☑️ | ☑️ | ➖ | |
| FastAPI | ✅ | ✅ CORS, SQL text(), SSRF, JWT | ☑️ | ☑️ | ➖ | |

## Frontend

| Technology | Detection | Custom Semgrep rules | CodeQL | Notes |
|---|---|---|---|---|
| React | ✅ | ✅ `dangerouslySetInnerHTML`, DOM sinks | ☑️ | |
| Next.js | ✅ | ✅ (React/JS rules) | ☑️ | server actions/middleware: guidance |
| Vue.js | ✅ | ✅ `v-html` | ☑️ | |
| Nuxt | ✅ | ✅ `v-html` | ☑️ | |
| Angular | ✅ | ✅ `bypassSecurityTrust*` | ☑️ | |

## Databases

| Technology | Detection | Automated checks | Guidance |
|---|---|---|---|
| MySQL / MariaDB | ✅ | SQL injection rules (code side) | ✅ `database-security` |
| PostgreSQL | ✅ | SQL injection rules (code side) | ✅ (incl. Row-Level Security for tenancy) |
| MongoDB | ✅ | NoSQL injection rule (Node) | ✅ |
| Redis | ✅ | ➖ | ✅ |

No tool in this framework connects to a database or inspects server configuration.

## Infrastructure

| Technology | Detection | Automated checks | Guidance |
|---|---|---|---|
| Docker | ✅ | ✅ builtin (root user, `:latest`); ☑️ Snyk IaC; ☑️ Dependabot `docker` | ✅ |
| GitHub Actions | ✅ | ✅ builtin (pwn-request, script injection, unpinned actions); ☑️ CodeQL `actions`; ☑️ Dependabot | ✅ |
| Nginx | ✅ | ☑️ runtime headers via `check-headers.sh` / ZAP | ✅ |
| Apache | ✅ (`.htaccess`, `httpd.conf`) | ☑️ runtime headers | ✅ |
| VPS / shared hosting | ➖ | ➖ | ✅ `deployment-security` |
| Terraform / Kubernetes | ✅ (`iac`) | ☑️ Snyk IaC | partial |

## What "☑️" means in practice

The workflow or command is written against the tool's documented interface and passes `actionlint` /
`shellcheck`, but its real execution depends on the tool, its version and (for Snyk) your account. Report
problems in an issue.
