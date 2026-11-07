# Threat modeling for SaaS

A threat model answers four questions: *what are we building, what can go wrong, what are we doing about it,
did we do a good job?* Use [templates/threat-model.md](../templates/threat-model.md).

## Method (≈ 1–2 hours for a typical SaaS)

1. **Describe the system**: components, data stores, third parties, deployment. Use `scripts/detect-stack.sh`
   as a starting inventory and correct it.
2. **Describe tenancy**: tenant unit, isolation strategy, how the tenant is resolved per request.
3. **List assets and actors** — always include *a user of another tenant* and *a platform admin*.
4. **Mark trust boundaries**: internet → edge, edge → app, app → DB/cache/storage, app → third parties,
   provider → webhooks, tenant ↔ tenant, user ↔ admin, CI → production.
5. **Apply STRIDE per boundary** (Spoofing, Tampering, Repudiation, Information disclosure, Denial of service,
   Elevation of privilege).
6. **Write abuse cases** specific to the product (see below) and map each to a control and a test.
7. **Prioritise gaps** and feed them into the audit (Phase 2) and the remediation plan.
8. **Revisit** when you add a feature that crosses a boundary: new integration, payment flow, file feature,
   public API, admin tool.

## SaaS abuse cases to always consider

| Abuse case | Typical control | Test idea |
|---|---|---|
| Cross-tenant read via ID change (IDOR/BOLA) | scoped queries, policies | tenant A requests tenant B's object → 404 |
| Role escalation via mass assignment | allow-listed fields | POST `role=admin` ignored |
| Invitation abuse (join any tenant) | signed, single-use, email-bound invites | reuse/forward invite fails |
| Payment webhook forgery / replay | signature verification, event-id idempotency | unsigned event → 400; duplicate → no effect |
| Plan/quota bypass | server-side limits in every create path and job | create N+1 resources → refused |
| Race on credits/coupons | transactions, unique constraints, locks | parallel redemption → one success |
| SSRF via webhook/import URL | allow-list, block private ranges | `http://169.254.169.254/` refused |
| Account takeover via reset/OAuth | single-use tokens, verified emails | reused token fails |
| Data left after tenant deletion | deletion job over DB, files, search, caches | no rows/files remain |
| Admin/support tool misuse | MFA, audit log, scoped impersonation | impersonation logged and visible |
| CI/CD compromise | least-privilege tokens, pinned actions, protected envs | fork PR cannot access secrets |

## References

- OWASP Threat Modeling Cheat Sheet — https://cheatsheetseries.owasp.org/cheatsheets/Threat_Modeling_Cheat_Sheet.html
- OWASP Multi-Tenant Security Cheat Sheet — https://cheatsheetseries.owasp.org/cheatsheets/Multi_Tenant_Security_Cheat_Sheet.html
- OWASP API Security Top 10 (2023) — https://owasp.org/API-Security/
