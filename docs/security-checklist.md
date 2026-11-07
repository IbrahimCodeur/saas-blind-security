# SaaS security checklist

Use during reviews and before releases. Tick only what you verified; write *N/A* or *Not verified* otherwise.
References: OWASP Top 10 2021 (A01–A10), OWASP API Security Top 10 2023 (API1–API10), OWASP ASVS 4.0.3 (V1–V14).

## Access control & multi-tenancy (A01, API1, API3, API5 · ASVS V4)
- [ ] Every endpoint, resolver, job and export enforces authorization server-side (deny by default).
- [ ] Every lookup by ID is scoped by owner/tenant or checked by a policy (no IDOR/BOLA).
- [ ] Tenant is derived from the authenticated membership, never from a client value alone.
- [ ] Central tenant scoping (global scopes / RLS / managers); bypasses reviewed.
- [ ] Protected attributes not mass-assignable (`role`, `is_admin`, `tenant_id`, `owner_id`, `plan`, `credits`).
- [ ] Caches, queues, file paths, search indexes, websockets and logs are tenant-aware.
- [ ] Admin roles separated; admin actions audited; impersonation restricted and logged.
- [ ] Two-tenant automated tests exist for sensitive resources.

## Authentication & sessions (A07, API2 · ASVS V2, V3)
- [ ] Adaptive password hashing (bcrypt/argon2/PBKDF2); no fast hashes.
- [ ] Login, reset and MFA rate-limited; no user enumeration.
- [ ] Session regenerated on login; invalidated on logout and password change.
- [ ] Cookies `HttpOnly`, `Secure`, `SameSite`.
- [ ] JWT verified with pinned algorithms; `exp/iss/aud` checked; refresh tokens rotated and revocable.
- [ ] Reset tokens random, hashed, single-use, short-lived.
- [ ] MFA available (mandatory for admins); recovery codes single-use.
- [ ] OAuth: `state`, PKCE, exact redirect URIs, verified emails only for linking.

## Input handling & injection (A03, A08, A10, API7 · ASVS V5)
- [ ] All SQL parameterised; identifiers allow-listed; NoSQL filters typed.
- [ ] Output encoding by default; raw HTML only from sanitised sources.
- [ ] CSRF protection on cookie-authenticated mutations.
- [ ] No user input in shell commands, `eval`, templates, deserialisers.
- [ ] Outbound requests to user URLs restricted (SSRF).
- [ ] File paths confined (no traversal).
- [ ] Schema validation at API boundaries; unknown fields rejected.

## Files (ASVS V12)
- [ ] Type (content-based) and size validated; server-generated names.
- [ ] Stored outside web root / private bucket; upload dirs non-executable.
- [ ] Downloads authorized per tenant; `nosniff`; attachments for untrusted types.

## Payments & business logic (API6 · ASVS V11)
- [ ] Prices/plans computed server-side.
- [ ] Webhooks signature-verified on raw body; idempotent; replay-safe.
- [ ] Entitlements granted only on confirmed payment events.
- [ ] Credits/coupons/quotas protected against races.
- [ ] Plan limits enforced in every creation path and background job.

## API protection (API4, API8, API9)
- [ ] Rate limits per user, API key, tenant and IP; 429 responses.
- [ ] Pagination and body size limits; timeouts.
- [ ] GraphQL depth/complexity limits; introspection policy decided.
- [ ] CORS allow-list; never wildcard with credentials.
- [ ] Endpoint inventory/documentation matches reality; old versions retired.

## Secrets & cryptography (A02 · ASVS V6)
- [ ] No secrets in code, history, images, client bundles or logs.
- [ ] Secret scanning + push protection enabled.
- [ ] Per-environment keys; rotation procedure documented.
- [ ] TLS everywhere; certificate verification never disabled.
- [ ] CSPRNG for tokens; modern algorithms only.

## Configuration & deployment (A05, A06 · ASVS V14)
- [ ] Debug off in production; generic error pages.
- [ ] Security headers: HSTS, CSP, frame protection, nosniff, Referrer-Policy (`scripts/check-headers.sh`).
- [ ] Admin area, login, password reset and every page showing account data answer with `X-Robots-Tag: noindex`
      (also on redirects and errors); robots.txt does not list them (`scripts/check-headers.sh URL --admin-paths "/admin /login"`).
- [ ] Web server hides versions; denies `/.git`, `/.env`, backups; no directory listing.
- [ ] Dependencies monitored (Dependabot/Snyk); lockfiles committed; no known HIGH/CRITICAL unaddressed.
- [ ] Containers non-root, pinned base images, no secrets in layers.
- [ ] CI: minimal permissions, pinned actions, no untrusted code with secrets, protected deploy environments.
- [ ] Branch protection/ruleset with required security checks.
- [ ] VPS: SSH keys only, firewall, automatic updates; DB/Redis not public.

## Data protection, logging & resilience (A09 · ASVS V7, V8)
- [ ] Audit log of security-relevant actions (login, role change, export, deletion, billing) without secrets.
- [ ] Alerts on auth anomalies and error spikes.
- [ ] Personal data minimised; export and deletion supported; retention defined.
- [ ] Account/tenant deletion removes data across DB, files, search, caches; backups handled per policy.
- [ ] Backups encrypted, access-restricted, restore tested.

---
Checklist from saas-blind-security — created and maintained by IbrahimCodeur.
