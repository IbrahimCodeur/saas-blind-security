---
name: api-security
description: Secure REST and GraphQL APIs of a SaaS application — authentication, object and function level authorization, input validation, rate limiting and quotas, pagination limits, CORS, error handling and abuse prevention, following the OWASP API Security Top 10 (2023).
---

# API security

Part of saas-blind-security — created and maintained by IbrahimCodeur.

## Objectives

- Every API operation is authenticated (unless explicitly public), authorized per object and per function,
  validated, and protected against abuse and resource exhaustion.

## Steps

1. **Inventory**: routes files (`routes/api.php`, Express routers, NestJS controllers, DRF routers, FastAPI
   routers, Next.js `app/api`/route handlers), OpenAPI specs, GraphQL schema and resolvers, versions, internal
   endpoints, webhooks. Compare with the documented API — undocumented endpoints are API9:2023.
2. **Authentication (API2).** Default-deny middleware applied to the router; public routes explicit. Tokens
   verified (see `authentication-security`). API keys scoped per tenant, hashed, revocable.
3. **Authorization (API1, API3, API5).** Apply `authorization-security` and `multi-tenant-security`:
   object-level checks, property-level filtering of input *and output*, admin functions separated.
4. **Input validation.** Schema validation at the boundary: Laravel FormRequest, DRF serializers,
   Pydantic models (FastAPI), NestJS `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })`,
   zod/joi for Express. Types, ranges, lengths, formats, enums; reject unknown fields.
5. **Resource consumption (API4).** Rate limits per user / API key / tenant / IP (Laravel `throttle`,
   `express-rate-limit`, DRF throttles, `slowapi`); max page size; request body size limits; timeouts;
   file size limits; expensive operations queued. Plan quotas enforced server-side.
6. **GraphQL.** Disable introspection in production if the schema is not public, limit query depth and
   complexity, disable or limit batching/aliases for login/OTP mutations, authorize in resolvers (not only at
   the gateway), avoid exposing internal IDs of other tenants through connections/nodes.
7. **Sensitive business flows (API6).** Signup, invitations, coupons, checkout, password reset: add
   anti-automation (rate limits, CAPTCHA where appropriate — never bypass existing CAPTCHAs), idempotency keys.
8. **SSRF (API7).** Any user-supplied URL (webhooks, imports, avatars): allow-list schemes/hosts, resolve and
   block private, loopback, link-local and metadata ranges, disable redirects or re-validate them.
9. **Configuration (API8).** CORS allow-list (never reflect any origin with credentials), security headers,
   no stack traces, HTTPS only, correct `Content-Type` handling.
10. **Third-party APIs (API10).** Validate data from integrations; TLS verification on; timeouts.

## Security rules

- Never load-test or fuzz an API that is not local or explicitly authorised for that purpose.
- Do not relax validation or rate limits to "fix" a client error.
- Keep error messages generic for clients; log details server-side without secrets.

## Validation criteria

- [ ] Endpoint inventory with auth + authorization per endpoint.
- [ ] Tests: unauthenticated → 401, wrong tenant → 404/403, unknown fields rejected, oversize page/body rejected,
      rate limit returns 429.
- [ ] GraphQL depth/complexity limits configured (if GraphQL is used).
- [ ] CORS configuration reviewed and tested.
