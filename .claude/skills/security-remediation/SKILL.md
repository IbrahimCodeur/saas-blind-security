---
name: security-remediation
description: Fix confirmed security vulnerabilities safely — test-first, minimal, root-cause fixes that preserve functionality, with re-scans and before/after comparison. Use after an audit when the user asks to correct findings.
---

# Security remediation

Part of saas-blind-security — created and maintained by IbrahimCodeur.

## Objectives

- Remove the vulnerability at its root, prove it with a test, and break nothing else.
- Keep every unresolved issue visible.

## Steps

1. **Select** findings to fix with the user (by severity and effort). Confirm each is `CONFIRMED`; if not,
   verify first.
2. **Explain before changing**: problem, proposed fix, files affected, risks, rollback. Ask for approval on
   significant changes (auth flows, migrations, dependency majors, payment logic, deletions).
3. **Understand dependencies**: callers, tests, configuration, other tenants/roles affected. Search for the
   same pattern elsewhere — fix the class of bug, not one instance.
4. **Write a failing test** reproducing the vulnerability (unit, feature/integration or E2E). Examples:
   cross-tenant read returns 404; SQLi payload treated as data; forged webhook rejected; XSS payload escaped.
5. **Apply the minimal correct fix** using framework mechanisms (bindings, policies, validation, escaping,
   signature verification, CSPRNG, adaptive hashing). No unrelated refactors.
6. **Dependency fixes**: upgrade to the first fixed version compatible with constraints; read the changelog;
   run the full test suite; for majors, ask first.
7. **Run**: the new test, the full test suite, linters, and the scanners that reported the issue
   (`$SBS/scripts/security-check.sh --report`). Compare `findings.json` before/after.
8. **Check for regressions and new issues**: error messages, logging of sensitive data, performance of new
   queries, other roles' access.
9. **Document**: update the remediation plan (status, commit, test name), keep unfixed items with reason/owner.

## Security rules

- Never delete, skip or weaken tests, scanners, CI checks, auth/authorization, CSRF, validation or TLS checks
  to make something pass.
- Never add suppressions (`nosemgrep`, `.snyk` ignore, ZAP IGNORE) without a written justification approved
  by the user.
- Never mark an issue fixed without a passing verification.
- One logical fix per commit; message references the finding ID (e.g. `fix(SBS-004): scope invoice lookup by tenant`).

## Validation criteria

- [ ] A test fails before and passes after each fix.
- [ ] Full test suite passes; re-scan shows the finding gone and no new HIGH/CRITICAL.
- [ ] Remediation plan updated; open items still listed.
