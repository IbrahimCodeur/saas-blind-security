# Architecture

```
                         ┌──────────────────────────── your SaaS repository ───────────────────────────┐
 developer / AI agent    │                                                                             │
 ──────────────────────▶ │  CLAUDE.md + .claude/skills/*      (how to audit, fix, validate, report)    │
                         │                                                                             │
 local run               │  .saas-blind-security/scripts/security-check.sh                             │
 ──────────────────────▶ │     ├─ detect-stack.sh        → languages, frameworks, DBs, infra, features │
                         │     ├─ builtin-checks.sh      → secrets, env files, Docker, workflows       │
                         │     ├─ semgrep (SaaS rules + registry)                                      │
                         │     ├─ snyk test / code / iac (if token)                                    │
                         │     ├─ npm audit / composer audit (if lockfile + tool)                      │
                         │     ├─ codeql CLI (if installed)                                            │
                         │     ├─ ZAP baseline in Docker (local or allowed hosts only)                 │
                         │     ├─ normalize-results.sh   → findings.json (common format)              │
                         │     └─ generate-report.sh     → report.md                                   │
                         │                                                                             │
 push / pull request     │  .github/workflows/                                                         │
 ──────────────────────▶ │     codeql.yml · semgrep.yml · snyk.yml · security-audit.yml                │
                         │     zap-baseline.yml · zap-full-scan.yml (manual) · dependabot-auto-review   │
                         │     → SARIF to GitHub code scanning, reports as artifacts + job summary     │
                         │  .github/dependabot.yml → update PRs                                        │
                         │                                                                             │
 optional AI analysis    │  fabric/patterns/sbs_* → `fabric --pattern …` on findings / reports         │
                         └─────────────────────────────────────────────────────────────────────────────┘
```

## Design principles

1. **Honest coverage.** Each run writes `tools.json` with `ran / skipped / missing / n/a / refused / error` per
   tool. Reports show it first. Missing tools are never reported as passed checks.
2. **One finding format.** Every tool is normalised to `{id, tool, rule, severity, title, file, line, detail, status}`.
   `status` starts as `unverified`; humans/agents classify it.
3. **No mandatory account.** Builtin checks, Semgrep local rules, CodeQL (GitHub), Dependabot, npm/composer audit and
   ZAP need no token. Snyk is optional.
4. **Safe by default.** Read-only analysis; ZAP limited to local hosts unless explicitly allowed; full active
   scan manual-only with confirmation, allow-list, production deny-list and a protected environment.
5. **Least privilege CI.** `permissions: contents: read` at the top of every workflow, elevated per job; actions
   pinned to commit SHAs; untrusted data passed through `env:`.
6. **Portable.** bash 3.2+ (macOS default) and `jq`; no other runtime dependency.
7. **Extensible.** Add a Semgrep rule (with tests), a normaliser kind, a skill or a Fabric pattern without touching
   the rest.

## Exit codes

| Code | `security-check.sh` | `gate-findings.sh` | `check-headers.sh` |
|---|---|---|---|
| 0 | nothing at/above threshold | below threshold | required headers present |
| 1 | threshold exceeded | threshold reached | a required header is missing |
| 2 | usage error or a scanner failed | usage error | usage error |

## Repository layout

See the [README](../README.md#repository-structure).
