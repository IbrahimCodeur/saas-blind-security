---
name: security-audit
description: Run a complete, evidence-based security audit of a SaaS application using the saas-blind-security five-phase method (reconnaissance, analysis, classification, remediation proposal, validation) and produce an honest report. Use when asked to audit, review or assess the security of an application or before a release.
---

# Security audit

Part of saas-blind-security — created and maintained by IbrahimCodeur.

## Objectives

- Understand the architecture and attack surface before judging anything.
- Find vulnerabilities with tools **and** manual review, prove the important ones.
- Classify every finding (status + severity) and propose context-specific fixes.
- Deliver a report that states clearly what was covered and what was not.

## When to use

A general audit, a pre-release review, onboarding onto an unknown codebase, or after a security incident.
For a single domain (auth, payments, uploads…) load the dedicated skill as well.

## Inputs

Repository access. Optional: GitHub Security tab results, a staging URL the user is authorised to scan,
test accounts for two different tenants and two roles.

## Steps

1. **Reconnaissance (read-only).** Run `$SBS/scripts/detect-stack.sh .` and
   `$SBS/scripts/security-check.sh --check-only`. Read manifests, routing files, middleware, auth config,
   models, `.env.example`, Docker/CI files. Build the entry-point inventory (route → auth → authorization → data touched).
2. **Threat model.** Fill `templates/threat-model.md`: assets, actors (anonymous, user, tenant admin,
   platform admin, other tenant, integrations), trust boundaries, STRIDE per boundary.
3. **Automated analysis.** `$SBS/scripts/security-check.sh --report`. Record which tools ran and which did
   not. Collect CodeQL / Dependabot / secret-scanning alerts from GitHub if available.
4. **Manual analysis.** For each entry point walk the SaaS risk list in `CLAUDE.md` §4. Delegate deep dives
   to: `authentication-security`, `authorization-security`, `multi-tenant-security`, `api-security`,
   `database-security`, `payment-security`, `file-upload-security`, `frontend-security`,
   `secrets-management`, `deployment-security`.
5. **Triage scanner output.** For each tool finding: open the code, decide CONFIRMED / POTENTIAL /
   FALSE_POSITIVE / NOT_VERIFIED, adjust severity to context. Deduplicate findings reported by several tools.
6. **Prove.** For CONFIRMED issues produce evidence: a failing test, a minimal request, or a precise code
   trace. Use local or authorised test environments only.
7. **Classify.** Use the finding format and severity scale of `CLAUDE.md` §3.
8. **Plan remediation.** Fill `templates/remediation-plan.md`, ordered by risk and effort. Do not change code
   unless the user asked for fixes; if they did, follow `security-remediation`.
9. **Report.** Fill `templates/security-report.md`. Include coverage gaps and NOT_VERIFIED areas.

## Security rules

- Never state or imply that the application is secure. Report what was tested.
- Read-only until the user approves changes. No dependency installs during reconnaissance.
- No active/dynamic attacks against hosts that are not local or explicitly authorised; never production.
- Never print secret values; redact as `[REDACTED]`.
- Do not suppress scanner findings to reduce counts.

## Validation criteria

- [ ] Architecture summary and entry-point inventory exist.
- [ ] Threat model covers tenancy, payments (if any), admin functions and integrations.
- [ ] Every scanner finding has a status; every CONFIRMED finding has evidence.
- [ ] Every finding has ID, severity, location, impact, exploitation conditions, fix, verification.
- [ ] Coverage table lists tools that did **not** run and areas not reviewed.
- [ ] No secret value appears anywhere in the output.
