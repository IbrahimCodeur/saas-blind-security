# Security Report — <Project name>

| Field | Value |
|---|---|
| Date | YYYY-MM-DD |
| Commit / version | |
| Auditor | |
| Scope | repositories, environments, features in scope |
| Out of scope | |
| Method | saas-blind-security five-phase method |

> This report describes what was tested and found. It does **not** certify that the application is secure.

## 1. Executive summary

- Overall assessment in 3–5 sentences (risk, main themes, urgency).
- Counts:

| Severity | Confirmed | Potential | Not verified | Fixed |
|---|---|---|---|---|
| CRITICAL | | | | |
| HIGH | | | | |
| MEDIUM | | | | |
| LOW | | | | |
| INFO | | | | |

## 2. Coverage

| Check | Ran? | Version / detail | Notes |
|---|---|---|---|
| Built-in checks | | | |
| Semgrep (SaaS rules + registry) | | | |
| CodeQL | | | languages |
| Snyk Open Source / Code / IaC | | | token available? |
| npm audit / composer audit | | | |
| Dependabot alerts | | | |
| Secret scanning | | | |
| OWASP ZAP baseline / full | | | target, authorisation |
| Manual review | | | areas reviewed |

**Not verified** (and why):

- …

## 3. Architecture and threat model summary

Short summary; full threat model in `threat-model.md`.

## 4. Findings

### SBS-001 — <title>

| Field | Value |
|---|---|
| Status | CONFIRMED / POTENTIAL / FALSE_POSITIVE / NOT_VERIFIED |
| Severity | CRITICAL / HIGH / MEDIUM / LOW / INFO |
| Category | e.g. Broken Access Control — OWASP A01:2021, API1:2023 |
| Location | `path/to/file.ext:line` — endpoint |
| Source | tool + rule id, or manual |

**Description.**

**Impact.**

**Exploitation conditions.**

**Evidence.** (code excerpt / request — never real secrets or personal data)

**Recommended fix.**

**Verification.** (test name, re-scan result)

## 5. False positives

| Tool | Rule | Location | Justification |
|---|---|---|---|

## 6. Remediation status

| ID | Severity | Status | Commit / PR | Verified by |
|---|---|---|---|---|

## 7. Recommendations beyond findings

Hardening, process (branch protection, reviews), monitoring, training.

---
Template from saas-blind-security — created and maintained by IbrahimCodeur.
