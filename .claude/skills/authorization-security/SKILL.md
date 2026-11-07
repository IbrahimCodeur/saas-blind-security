---
name: authorization-security
description: Audit and enforce authorization — roles, permissions, policies, ownership checks and admin functions — to prevent broken access control, IDOR/BOLA, privilege escalation and mass assignment in SaaS applications. Use when reviewing endpoints, roles or any code that loads or changes resources by ID.
---

# Authorization security

Part of saas-blind-security — created and maintained by IbrahimCodeur.

## Objectives

- Every action on every resource is checked server-side against the current user, role and tenant.
- Users cannot escalate privileges or modify protected attributes.
- Maps to OWASP A01:2021, API1:2023 (BOLA), API3:2023 (BOPLA), API5:2023 (BFLA).

## Steps

1. **Build an authorization matrix**: rows = endpoints/actions (including GraphQL resolvers, exports, jobs,
   webhooks, admin panels), columns = roles (anonymous, member, tenant admin, billing admin, platform admin,
   other tenant). Fill expected access; then verify the code matches.
2. **Locate the enforcement mechanism** and check it is applied consistently:
   Laravel Policies/Gates (`$this->authorize()`, `can` middleware, `Gate::define`), Django permissions /
   DRF `permission_classes` + `get_queryset`, NestJS Guards (`@UseGuards`, `@Roles`), Express middleware,
   Next.js middleware + server actions/route handlers (check *server-side*, not only in the UI).
3. **Object-level checks (IDOR/BOLA).** Every lookup by ID must include the owner/tenant condition or a
   policy check *before* returning or mutating data. Semgrep lead: `sbs-js-idor-find-by-request-id`.
   Prefer scoped queries: `$request->user()->projects()->findOrFail($id)`, `Project.objects.filter(tenant=request.tenant).get(pk=pk)`.
   Return 404 rather than 403 when existence itself is sensitive.
4. **Property-level checks / mass assignment.** Allow-list writable fields: Laravel `$fillable` +
   `$request->validated()`, Django forms/serializers with explicit `fields`, DTOs with `whitelist: true` /
   `forbidNonWhitelisted: true` in NestJS `ValidationPipe`. Never let clients set `role`, `is_admin`,
   `tenant_id`, `owner_id`, `plan`, `credits`, `email_verified_at`. Check response serialisers do not leak
   internal fields.
5. **Function-level checks.** Admin and billing routes protected by role checks on the server; hidden
   buttons are not protection. Check HTTP method overrides and alternative routes (API v1 vs v2).
6. **Role management.** Who can invite, change roles, transfer ownership, remove the last owner? Users must
   not grant roles above their own. Impersonation: restricted, audited, visible to the user.
7. **Indirect paths.** File downloads, signed URLs, exports, search, notifications, websockets/channels
   (Laravel broadcasting `channels.php`, Socket.IO rooms), background jobs triggered with user-supplied IDs.
8. **Write tests** for each sensitive endpoint: allowed role succeeds, lower role fails, other tenant fails.

## Security rules

- Deny by default; never fix an access bug by widening permissions.
- Never rely on client-side checks, hidden fields, obscure IDs or UUIDs as authorization.
- Do not remove a policy/guard because a test fails — fix the test data or the logic.

## Validation criteria

- [ ] Authorization matrix written and compared with the code.
- [ ] Automated tests: cross-user and cross-tenant access denied for read, update, delete, export.
- [ ] Mass-assignment tests: protected attributes ignored or rejected.
- [ ] Admin/billing functions unreachable for non-admin roles (tested).
