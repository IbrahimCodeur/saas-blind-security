# Changelog

All notable changes are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning: [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Author & Maintainer section (README in English and French), `AUTHORS.md` and `CITATION.cff` author metadata.
- Admin exposure checks: builtin rule `sbs-builtin-admin-indexable` (admin area in a project with no noindex
  mechanism, MEDIUM) and `sbs-builtin-robots-reveals-admin` (INFO); `check-headers.sh --admin-paths` (or
  `SBS_ADMIN_PATHS`) verifies that admin pages, their login page and redirects answer with `X-Robots-Tag: noindex`
  or `<meta name="robots" content="noindex">`.
- `SBS_COMPOSER_BIN` to run composer audit when Composer is a `.phar` outside `PATH` (MAMP, shared hosting).
- Semgrep unit tests for `blade-saas.yaml`.
- `check-headers.sh`: plain HTTP must redirect to HTTPS (`HTTPS-redirect`); `--listing-paths` (or
  `SBS_LISTING_PATHS`) fails on automatic directory listings; admin paths that reveal themselves to anonymous
  visitors (redirect to a login page, 401, 403) are reported as `Admin-discoverable` (LOW).
- Builtin rule `sbs-builtin-indexes-inside-ifmodule` (LOW): `Options -Indexes` only inside `<IfModule>`, skipped on
  servers without that module (LiteSpeed, some shared hosts).
- Semgrep rule `sbs-laravel-login-throttle-single-key` (INFO): login rate limit with a single key, bypassed by
  rotating IP addresses.

### Fixed
- Lockfile check reported `package.json without a lockfile` when `package-lock.json` existed but another lockfile
  name was missing (`ls` with several operands).
- A secret in a local, uncommitted `.env` was reported as a CRITICAL hardcoded secret; it is now
  `sbs-builtin-secret-in-local-env` (INFO). Committed environment files are still CRITICAL/HIGH.
- `sbs-blade-unescaped-output` no longer reports `{!! nl2br(e(...)) !!}` and `{!! json_encode(..., JSON_HEX_TAG) !!}`.
- Stack detection scanned `.claude/` and `.saas-blind-security/` (agent scripts detected as Python) and
  read the `team_id` option of `config/permission.php` (spatie/laravel-permission) as multi-tenancy.
- `check-headers.sh` no longer asks for `HttpOnly` on CSRF double-submit cookies (`XSRF-TOKEN`, `csrftoken`),
  which JavaScript must read.

## [0.1.0] — 2026-11-07

### Added
- `security-check.sh` with default, `--report` and `--check-only` modes; severity gating; honest coverage tracking.
- Stack detection (PHP/Laravel, Node.js/Express/NestJS, Python/Django/FastAPI, React/Next.js/Vue/Nuxt/Angular,
  MySQL/MariaDB/PostgreSQL/MongoDB/Redis, Docker/GitHub Actions/Nginx/Apache, SaaS features).
- Dependency-free builtin checks (secrets, env files, debug flags, lockfiles, Docker, GitHub Actions).
- Result normaliser for Semgrep, Snyk, SARIF (CodeQL/Snyk Code/IaC), npm audit, composer audit, ZAP.
- Markdown report generator, severity gate, environment validator, HTTP header checker.
- 41 custom Semgrep rules for SaaS risks with unit tests.
- Workflows: CodeQL, Semgrep, Snyk, ZAP baseline, ZAP full scan (manual, guarded), Security audit with
  Dependency Review, Dependabot review helper, self-test CI.
- `install.sh`, `configure-github-security.sh`, `generate-dependabot.sh`, `install-fabric-patterns.sh`.
- `CLAUDE.md` and 12 Claude Code skills; 9 Fabric patterns; report, threat-model and remediation templates.
- Documentation in English, main documentation in French.

[0.1.0]: https://github.com/IbrahimCodeur/saas-blind-security/releases/tag/v0.1.0
