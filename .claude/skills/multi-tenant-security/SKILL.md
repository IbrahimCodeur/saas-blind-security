---
name: multi-tenant-security
description: Verify tenant isolation in a multi-tenant SaaS — detect IDOR/BOLA, cross-tenant queries, filtering mistakes, leaky caches, jobs, files, search and exports — and enforce tenant scoping by design. Use whenever the app serves several organisations, teams, workspaces or customer accounts.
---

# Multi-tenant security

Part of saas-blind-security — created and maintained by IbrahimCodeur.

## Objectives

- No user can read, modify, infer or delete data of another tenant through any channel.
- Tenant scoping is enforced centrally, not remembered per query.

## Steps

1. **Identify the tenancy model**: shared DB with `tenant_id`/`team_id`/`organization_id` columns, schema per
   tenant, DB per tenant, or packages (`stancl/tenancy`, `spatie/laravel-multitenancy`, `django-tenants`,
   Prisma middleware, PostgreSQL RLS). Write down where the *current tenant* comes from on each request
   (subdomain, path, header, session, token claim) and how it is validated against the user's memberships.
2. **Tenant resolution.** The tenant must be derived from the authenticated user's membership, never from a
   client-supplied value alone (header, query param, body field, subdomain) without a membership check.
3. **Central enforcement.** Prefer: Eloquent global scopes / tenant-aware base model, Django managers that
   require a tenant, ORM middleware, or PostgreSQL Row-Level Security with `SET app.tenant_id`. Then search for
   bypasses: `withoutGlobalScopes`, `withoutGlobalScope`, `.unscoped`, raw SQL, `objects.all()` in admin/API
   code, aggregate/report queries, `DB::table()` without scope.
4. **Object access.** Every by-ID lookup includes the tenant (or goes through the scoped relation). Check
   nested resources: `/projects/{p}/tasks/{t}` must verify `t` belongs to `p` *and* `p` to the tenant.
5. **Writes.** `tenant_id` set server-side, never mass-assignable; foreign keys pointing to another tenant's
   objects rejected (e.g. assigning a task to a user of another tenant).
6. **Side channels.** Caches keyed with tenant (`cache key = tenant:{id}:...`), queues/jobs carry and re-check
   the tenant, file storage paths namespaced per tenant with authorization on download, signed URLs short-lived,
   search indexes filtered by tenant, websockets/channels authorized per tenant, emails/notifications to the
   right tenant, logs and analytics not exposing other tenants, sequential IDs revealing customer counts.
7. **Admin & support tools.** Platform-admin access audited; impersonation limited and logged.
8. **Tenant lifecycle.** Tenant deletion removes or anonymises all data (DB, files, search, caches, backups per
   policy); tenant export contains only that tenant's data.
9. **Tests.** Create two tenants with one user each; for every endpoint and job, assert tenant A cannot access
   tenant B's resources (read, list, update, delete, export, search, file download).

## Security rules

- Treat any confirmed cross-tenant access as at least HIGH, usually CRITICAL.
- Never "fix" by filtering in the frontend or by hiding IDs.
- Do not use production tenant data in tests or reports.

## Validation criteria

- [ ] Tenancy model and tenant resolution documented.
- [ ] Scope bypasses (`withoutGlobalScopes`, raw queries, `unscoped`) listed and justified or fixed.
- [ ] Two-tenant automated tests cover all resource types and file downloads.
- [ ] Caches, jobs, storage and search verified for tenant namespacing.
