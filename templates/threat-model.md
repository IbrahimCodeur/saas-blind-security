# Threat Model — <Project name>

Date: YYYY-MM-DD · Version/commit: · Author:

## 1. System overview

- Purpose of the SaaS and main user journeys.
- Components (frontend, API, workers, DB, cache, storage, third parties) — diagram or list.
- Hosting / deployment (VPS, shared hosting, PaaS, containers).

## 2. Tenancy model

- Tenant unit (organisation / team / workspace / account):
- Isolation strategy (shared tables + `tenant_id`, schema per tenant, DB per tenant, RLS):
- How the current tenant is resolved on each request and validated against membership:
- Places where tenant scoping can be bypassed (raw queries, admin tools, jobs, caches, files, search):

## 3. Assets

| Asset | Sensitivity | Where stored | Who should access |
|---|---|---|---|
| Tenant business data | | | |
| Personal data | | | |
| Credentials, tokens, API keys | | | |
| Payment/billing data | | | |
| Uploaded files | | | |
| Admin capabilities | | | |

## 4. Actors

Anonymous visitor · registered user · tenant member · tenant admin · billing admin · platform admin/support ·
user of **another tenant** · integration/webhook sender · compromised dependency/CI · insider.

## 5. Entry points and trust boundaries

| Entry point | Auth | Authorization | Boundary crossed | Notes |
|---|---|---|---|---|
| | | | internet → app | |
| Webhooks | signature? | | provider → app | |
| Jobs / queues | n/a | re-checks tenant? | app → worker | |

## 6. STRIDE analysis

| Boundary / component | Spoofing | Tampering | Repudiation | Information disclosure | Denial of service | Elevation of privilege |
|---|---|---|---|---|---|---|
| Login / sessions | | | | | | |
| API | | | | | | |
| Tenant isolation | | | | | | |
| Payments / webhooks | | | | | | |
| File storage | | | | | | |
| Admin panel | | | | | | |
| CI/CD | | | | | | |

## 7. Abuse cases (SaaS specific)

- Tenant A enumerates IDs to read tenant B's objects.
- User upgrades own role via mass assignment.
- Attacker forges/replays a payment webhook to unlock a paid plan.
- Concurrent requests redeem a coupon or consume credits twice.
- SSRF through webhook URL / import feature to cloud metadata.
- API abuse beyond plan quota; credential stuffing on login.
- …

## 8. Mitigations and gaps

| Threat | Existing control | Gap | Priority |
|---|---|---|---|

## 9. Assumptions and open questions

---
Template from saas-blind-security — created and maintained by IbrahimCodeur.
