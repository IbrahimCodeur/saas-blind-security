# Remediation Plan — <Project name>

Source report: `security-report.md` (date) · Owner: · Target dates:

## 1. Priorities

| Order | Work item | Findings | Severity | Effort (S/M/L) | Owner | Target date | Status |
|---|---|---|---|---|---|---|---|
| 1 | | SBS-… | | | | | TODO |

Statuses: TODO · IN_PROGRESS · FIXED_PENDING_VERIFICATION · VERIFIED · RISK_ACCEPTED (owner + expiry) · WONT_FIX (reason).

## 2. Containment for critical issues

Immediate measures while a fix is prepared (rotate keys, disable feature, WAF rule, restrict access).

## 3. Work items

### WI-1 — <title>

- **Findings:** SBS-…
- **Root cause:**
- **Fix approach:** (framework mechanism; files/components)
- **Test that proves the fix:** (fails before, passes after)
- **Regression risks / dependencies:**
- **Rollback plan:**
- **Verification:** scanners to re-run, manual checks, result

## 4. Verification plan

- [ ] `security-check.sh --report` re-run and compared with the previous `findings.json`
- [ ] CodeQL / Semgrep / Snyk results on the fix PR
- [ ] Full test suite green
- [ ] Manual re-test of CONFIRMED issues (other role, other tenant, unauthenticated)

## 5. Open risks

Everything not fixed stays here with reason, owner and review date.

---
Template from saas-blind-security — created and maintained by IbrahimCodeur.
