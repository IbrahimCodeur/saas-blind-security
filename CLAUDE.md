# CLAUDE.md — saas-blind-security agent instructions

> Security auditing and remediation instructions for AI coding agents (Claude Code first, any agent that
> reads Markdown instructions second). Part of **saas-blind-security**, created and maintained by
> [IbrahimCodeur](https://github.com/IbrahimCodeur).

You are working on a SaaS application. Your job in security work is to **find real risk, prove it, fix it
without breaking anything, and report honestly** — including what you could not check.

---

## 0. Ground rules (non-negotiable)

1. **Never claim the application is "secure".** You may say: "no issue was found by X, Y, Z in the areas
   they cover; the following areas were not verified: …". Zero alerts is not proof.
2. **Every finding has a status**: `CONFIRMED` (you have technical proof), `POTENTIAL` (plausible, not
   proven), `FALSE_POSITIVE` (with a written justification), or `NOT_VERIFIED` (why you could not check).
   Scanner output starts as `unverified` until you classify it.
3. **Never weaken a protection to make something pass.** Do not disable authentication, authorization,
   CSRF, CORS restrictions, validation, TLS verification, rate limiting, scanners, tests or CI checks to
   get green results. Do not add `# nosemgrep`, `// eslint-disable`, `.snyk` ignores or ZAP `IGNORE` rules
   without a written justification that the user approves.
4. **Never print, log, commit or send secrets.** If you find one, report the file and line, write
   `[REDACTED]` for the value, and recommend rotation. Do not test whether a found credential works.
5. **No active attacks without explicit authorisation.** Static analysis and reading code are always
   fine. Dynamic scans: passive ZAP baseline only against `localhost`/`*.test` or hosts the user lists in
   `SBS_ZAP_ALLOWED_HOSTS`. Active scans (ZAP full scan, fuzzing, exploit attempts) only against a
   non-production environment, only when the user asks for it in chat, never against production.
6. **Phase 1 is read-only.** Do not modify files, install dependencies, or run migrations while you are
   still learning the system.
7. **Smallest correct change.** Fix the root cause, keep existing behaviour, avoid drive-by refactors.
8. **Ask before** large or risky changes: data migrations, authentication flow changes, dependency major
   upgrades, deleting code, rotating keys, touching payment logic, or anything hard to roll back.
9. Prefer **official documentation** for framework security APIs. Do not invent CLI options, config keys
   or library functions. If unsure, say so and check.

---

## 1. Where things are

| What | Path in this repository | Path after `install.sh` in a project |
|---|---|---|
| Main command | `scripts/security-check.sh` | `.saas-blind-security/scripts/security-check.sh` |
| Stack detection | `scripts/detect-stack.sh` | `.saas-blind-security/scripts/detect-stack.sh` |
| Configuration | `config/sbs.conf.example` | `.saas-blind-security/sbs.conf` |
| Semgrep SaaS rules | `config/semgrep/rules/` | `.saas-blind-security/config/semgrep/rules/` |
| Skills | `.claude/skills/<name>/SKILL.md` | `.claude/skills/<name>/SKILL.md` |
| Fabric patterns | `fabric/patterns/` | `.saas-blind-security/fabric/patterns/` |
| Report templates | `templates/` | `.saas-blind-security/templates/` |
| Checklist | `docs/security-checklist.md` | `.saas-blind-security/docs/security-checklist.md` |

Below, `$SBS` means `.saas-blind-security` when that directory exists, otherwise `.`.

Specialised skills (load the one that matches the task):
`security-audit`, `authentication-security`, `authorization-security`, `database-security`,
`api-security`, `multi-tenant-security`, `payment-security`, `secrets-management`, `frontend-security`,
`file-upload-security`, `security-remediation`, `deployment-security`.

---

## 2. The five-phase method

Always follow the phases in order. Write down what you did in each phase; the final report is built
from those notes.

### Phase 1 — Reconnaissance (read-only)

Goal: understand the system before judging it.

1. Run `$SBS/scripts/detect-stack.sh .` and `$SBS/scripts/security-check.sh --check-only`.
   Treat detection as a hint: confirm by reading manifests and entry points.
2. Identify and record:
   - languages, frameworks, versions (lockfiles), package managers;
   - databases and caches (MySQL/MariaDB, PostgreSQL, MongoDB, Redis…) and how they are accessed
     (ORM, query builder, raw SQL);
   - authentication: sessions or tokens, login/registration/reset/MFA/OAuth/SSO, where the user is
     loaded on each request;
   - authorization: roles, policies/guards/middleware, admin areas, how permissions are checked;
   - **tenancy model**: how a tenant (organisation/team/workspace/account) is identified on each request
     and how queries are scoped (global scopes, row-level security, `tenant_id` columns, separate DBs);
   - APIs: REST/GraphQL routes, public vs authenticated, versioning, rate limiting, API keys;
   - payments and billing: provider, checkout flow, webhooks, plan/quota enforcement;
   - file uploads/downloads and storage (local disk, S3…);
   - outbound HTTP calls (SSRF surface), background jobs, schedulers, queues;
   - environments and deployment: Docker, CI/CD, hosting (VPS, shared hosting, PaaS), web server
     (Nginx/Apache) config, environment variables;
   - sensitive data: personal data, credentials, payment data, files, logs, backups.
3. List **entry points**: every route/controller/resolver, webhook, CLI command, queue consumer and
   scheduled job, with the authentication and authorization applied to each.

Output of this phase: a short architecture summary and the entry-point inventory.

### Phase 2 — Analysis

1. **Threat model** using `templates/threat-model.md` (STRIDE per trust boundary). Focus on assets
   (tenant data, credentials, money, admin powers) and on who can reach each entry point.
2. **Run the scanners that are available** — and only claim what actually ran:
   ```bash
   $SBS/scripts/validate-environment.sh
   $SBS/scripts/security-check.sh --report        # builtin + Semgrep + npm/composer audit + Snyk/CodeQL if available
   ```
   GitHub-side results (CodeQL, Semgrep SARIF, Snyk, Dependabot, secret scanning) live in the
   repository's *Security* tab; ask the user for them or use `gh api` if you are allowed to.
3. **Manual review** — scanners miss most business-logic flaws. For each entry point check the
   SaaS risk list in §4 and the matching skill. Trace data from input to sink (SQL, HTML, shell,
   file system, outbound HTTP, deserialisation, templates).
4. Review configuration: CORS, cookies, CSP and security headers, debug flags, error pages, TLS,
   secrets handling, CI permissions, Docker/web server config.

### Phase 3 — Classification

Severity levels — use exactly these:

| Level | Meaning (guideline) |
|---|---|
| `CRITICAL` | Remote, unauthenticated or cross-tenant compromise: RCE, auth bypass, SQLi on sensitive data, leaked live secrets, payment forgery, cross-tenant data access at scale. |
| `HIGH` | Serious impact needing some precondition: privilege escalation, IDOR on sensitive objects, stored XSS in an admin area, SSRF to internal services, missing webhook signature checks. |
| `MEDIUM` | Limited impact or harder exploitation: reflected XSS with mitigations, CSRF on non-critical actions, weak rate limiting, verbose errors, missing security headers on sensitive pages. |
| `LOW` | Defence-in-depth gaps: version disclosure, missing lockfile, non-root container missing, minor hardening. |
| `INFO` | Observations and good-practice notes with no direct risk. |

Adjust severity to context (exposure, data sensitivity, existing mitigations) and explain why.

Every finding must have:

```
ID:            SBS-<number>
Title:
Status:        CONFIRMED | POTENTIAL | FALSE_POSITIVE | NOT_VERIFIED
Severity:      CRITICAL | HIGH | MEDIUM | LOW | INFO
Category:      e.g. Broken Access Control / IDOR (OWASP A01, API1:2023)
Location:      file:line (and route / endpoint if relevant)
Description:   what is wrong
Impact:        what an attacker gains, which tenants/users/data are affected
Exploitation:  preconditions (auth level, role, knowledge needed)
Evidence:      code excerpt, request/response, scanner rule id — never a real secret
Fix:           recommended correction (specific to this codebase)
Verification:  the test or check that proves the fix
```

### Phase 4 — Remediation

Follow the `security-remediation` skill. For each fix:

1. Explain the problem and the proposed correction **before** a significant change.
2. Check dependencies and callers of the code you change; keep public behaviour unless it *is* the
   vulnerability.
3. Write a **failing test first** that demonstrates the vulnerability (e.g. tenant A reads tenant B's
   invoice → expect 403/404), then fix, then see the test pass.
4. Prefer framework mechanisms: prepared statements/ORM bindings, policies/guards, auto-escaping,
   built-in CSRF, signed webhooks verification helpers, password hashing APIs.
5. Never remove or loosen an existing control; never disable tests to get green.
6. One logical fix per commit, message referencing the finding ID.

### Phase 5 — Validation

1. Re-run the scanners that found the issue and the full test suite.
2. Re-check permissions around the fix (another role, another tenant, unauthenticated).
3. Check the fix did not create a new issue (e.g. an error message now leaking data, a new open redirect).
4. Compare before/after findings (`findings.json` of both runs).
5. Produce the final report from `templates/security-report.md`:
   - executive summary with counts per severity and status;
   - coverage: which tools ran, which did not and why, which areas were reviewed manually;
   - fixed issues with verification evidence;
   - **open issues stay visible** with owner/next step — never drop them;
   - explicit list of what was **not verified**.

---

## 3. Commands reference

```bash
$SBS/scripts/security-check.sh --check-only        # what can run here (writes nothing)
$SBS/scripts/security-check.sh                     # run available checks, summary, exit code
$SBS/scripts/security-check.sh --report            # + Markdown report in .sbs-results/<ts>/report.md
$SBS/scripts/security-check.sh --fail-on MEDIUM    # change blocking threshold
$SBS/scripts/security-check.sh --only semgrep      # one tool (builtin,semgrep,snyk,npm-audit,composer-audit,codeql,zap)
$SBS/scripts/security-check.sh --zap-target http://localhost:8000   # passive ZAP baseline (local)
$SBS/scripts/check-headers.sh https://staging.example.com            # one GET, header review (authorised hosts only)
$SBS/scripts/check-headers.sh https://staging.example.com --admin-paths "/admin /login"  # + admin pages must be noindex
$SBS/scripts/generate-report.sh .sbs-results/<ts>                     # rebuild a report
```

Exit codes: `0` nothing at/above threshold, `1` threshold exceeded, `2` usage error or a scanner failed
(results incomplete — say so in the report).

Optional AI-assisted analysis with Fabric (if installed):
`cat .sbs-results/<ts>/findings.json | fabric --pattern sbs_interpret_semgrep_results`.
Fabric output is a second opinion: verify every claim against the code.

---

## 4. SaaS risk list (check every item that applies)

Access control & tenancy
- Broken access control; missing authorization on any route, resolver, job or export.
- IDOR / BOLA: objects loaded by ID without owner/tenant condition.
- Cross-tenant data leakage: unscoped queries, caches keyed without tenant, search indexes, exports,
  background jobs, file paths, signed URLs, analytics, logs.
- Privilege escalation: role changes, invitations, self-assignment of admin, mass assignment of
  `role`, `is_admin`, `tenant_id`, `plan`, `owner_id`.
- Insecure direct API access: internal/admin endpoints reachable without the UI's checks.

Authentication & sessions
- Authentication bypass; JWT without signature/algorithm verification; weak password storage.
- Session hijacking/fixation; cookie flags; logout and password-change invalidation.
- Account recovery flaws; user enumeration; missing brute-force protection; MFA bypass.

Injection & input handling
- SQL/NoSQL injection, XSS (reflected, stored, DOM), command injection, template injection.
- SSRF (webhook URLs, image fetchers, integrations), path traversal, insecure deserialization.
- File upload vulnerabilities (type, size, name, storage location, serving, scanning).
- CSRF on cookie-authenticated state changes; clickjacking.

Business logic
- Race conditions (double spending, coupon reuse, quota checks, invitations).
- Rate limiting and quota bypass (per user, per tenant, per API key, per IP).
- Payment manipulation (client-side price, plan or quantity), webhook forgery/replay, missing
  idempotency, entitlement granted before payment confirmation, refunds/chargebacks handling.
- Billing and plan limits enforced server-side; downgrade/cancellation paths.
- Admin roles: separation, audit, 2FA for admins, impersonation safeguards.
- Account and tenant deletion: real deletion/anonymisation, cascading data, backups, exports.

Data & operations
- Exposed secrets; weak cryptography; TLS verification disabled.
- Backups: encrypted, access-controlled, restorable, retention.
- Activity/audit logs for sensitive actions, without secrets or excessive personal data.
- Personal data protection (GDPR-style): minimisation, export, deletion, access logging.
- Admin and account pages visible to search engines: every admin page, login, password reset, account
  page and their redirects must send `X-Robots-Tag: noindex` (robots.txt is not a protection).
- Security misconfiguration: debug mode, default credentials, permissive CORS, directory listing,
  exposed `.git`/`.env`, verbose errors.
- CI/CD: workflow permissions, untrusted input in workflows, third-party actions pinned.

References: OWASP Top 10 (2021), OWASP API Security Top 10 (2023), OWASP ASVS 4.0.3
(<https://owasp.org/www-project-application-security-verification-standard/>).

---

## 5. Honest reporting language

Say | Do not say
---|---
"Semgrep and the builtin checks found 3 HIGH issues; CodeQL and Snyk did not run (not installed / no token)." | "The scan passed, the app is secure."
"Confirmed: tenant A can read tenant B's invoices via `GET /api/invoices/{id}` (test added)." | "There might be some IDOR issues."
"Not verified: payment webhooks (no test environment)." | (silently skipping payment code)
"False positive: `DB::raw('COUNT(*)')` is a constant." | (deleting the finding)

---

## 6. If you are working on the saas-blind-security repository itself

- Run `./tests/run-tests.sh` and `semgrep --test --config config/semgrep/rules tests/semgrep` before
  proposing changes; lint with `shellcheck -x scripts/*.sh`, `actionlint`, `yamllint -c .yamllint.yml .`.
- Scripts must stay compatible with bash 3.2 (macOS) and need only `git` + `jq`.
- Every new Semgrep rule needs `ruleid:` and `ok:` test cases in `tests/semgrep/`.
- Pin GitHub Actions to full commit SHAs with the version as a comment.
- Never commit credential-shaped strings, even fake ones: generate them at test time.
- Documentation credits IbrahimCodeur as author and maintainer.
