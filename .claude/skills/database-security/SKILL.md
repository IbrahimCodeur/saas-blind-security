---
name: database-security
description: Secure database access in SaaS applications — SQL/NoSQL injection prevention with prepared statements, least-privilege DB accounts, encryption, Redis/MongoDB hardening, backups and migrations. Use for MySQL, MariaDB, PostgreSQL, MongoDB and Redis reviews.
---

# Database security

Part of saas-blind-security — created and maintained by IbrahimCodeur.

## Objectives

- No query can be altered by user input.
- Database credentials and network exposure follow least privilege.
- Sensitive data is encrypted where required and backups are protected.

## Steps

1. **Inventory data access**: ORM (Eloquent, Django ORM, Prisma, TypeORM, Sequelize, Mongoose,
   SQLAlchemy), query builders, raw SQL, stored procedures, migrations, reporting queries.
2. **Injection review.** Search raw-query APIs: `DB::raw/select/statement`, `whereRaw/orderByRaw`,
   `->query()`, `mysqli_query`, `cursor.execute`, `.raw()`, `.extra()`, `text()`, `$queryRawUnsafe`,
   `sequelize.query`, template literals in SQL. All values must be bound parameters. Identifiers (column
   names, sort direction) cannot be bound: validate against an allow-list. Semgrep rules
   `sbs-*-sqli-*` give leads.
3. **NoSQL.** Mongo filters must not accept raw request objects (`{$ne: null}`, `$where`, `$regex`
   injection). Cast types or validate with a schema; set `sanitizeFilter` in Mongoose ≥ 6 where suitable.
4. **Accounts & network.** Application user without SUPER/DDL rights in production (migrations with a
   separate account where practical); DB not exposed publicly (bind to private network, firewall);
   TLS for remote connections; strong unique passwords from the environment; Redis with `requirepass`/ACLs,
   `protected-mode yes`, not bound to `0.0.0.0` on a public interface; MongoDB authentication enabled.
5. **Data protection.** Hash passwords (never encrypt); encrypt highly sensitive columns (API tokens of
   integrations, OAuth refresh tokens, personal identifiers) with framework encryption (Laravel
   `encrypted` cast, Django field encryption libraries) with keys outside the DB; consider PostgreSQL
   Row-Level Security for multi-tenant tables.
6. **Errors & logging.** No SQL errors shown to users; slow-query logs must not contain secrets.
7. **Backups.** Encrypted at rest, access-restricted, tested restore, retention policy, deleted-tenant data
   handled according to the deletion policy.
8. **Migrations.** Reversible, no data loss without approval, no default credentials or seed admin accounts
   in production seeds.

## Security rules

- Never run destructive SQL or migrations on shared/production databases during an audit.
- Never paste real connection strings or data samples into reports.
- Fix injection with parameterisation, not with escaping functions or blacklist filters.

## Validation criteria

- [ ] No string-built query with external input remains (Semgrep rules clean or justified).
- [ ] Tests with injection payloads (`' OR 1=1 --`, `{"$ne": null}`) return normal "not found"/validation errors.
- [ ] DB/Redis not reachable from the internet (config reviewed; verified if environment is available).
- [ ] Backup and restore procedure documented.
