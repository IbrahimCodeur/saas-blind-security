---
name: deployment-security
description: Harden SaaS deployment — CI/CD (GitHub Actions permissions, pinned actions, secrets, branch protection), Docker images, Nginx/Apache configuration, TLS and headers, VPS and shared-hosting setups, environment separation, logging, backups and monitoring.
---

# Deployment security

Part of saas-blind-security — created and maintained by IbrahimCodeur.

## Objectives

- Only reviewed code reaches production, built by a trustworthy pipeline.
- Runtime environments expose the minimum and are configured securely.

## Steps

1. **CI/CD (GitHub Actions).** Top-level `permissions: contents: read`, elevated per job only; actions pinned to
   commit SHAs and updated by Dependabot; no `pull_request_target` with checkout of PR code; untrusted event data
   passed via `env:` not `${{ }}` in `run:`; secrets only in protected environments for deploy jobs; OIDC
   instead of long-lived cloud keys where possible. `sbs-builtin-gha-*` checks give leads.
2. **Repository protection.** Rulesets/branch protection on `main`: PR required, required status checks
   (CodeQL, Semgrep, Security audit), no force-push/deletion; secret scanning + push protection; Dependabot
   alerts and security updates — `$SBS/scripts/configure-github-security.sh OWNER/REPO --dry-run`.
3. **Docker.** Minimal pinned base images, multi-stage builds, non-root `USER`, no secrets in layers/ARGs,
   `.dockerignore` excluding `.env`/`.git`, read-only filesystem where possible, health checks, image scanning
   (Snyk container / registry scanning).
4. **Web server.** Nginx/Apache: HTTPS only with HSTS, TLS 1.2+, security headers (CSP, X-Content-Type-Options,
   frame protection, Referrer-Policy), `server_tokens off` / `ServerTokens Prod`, deny `/.git`, `/.env`,
   backups and dotfiles, no directory listing, upload dirs non-executable, request size limits, sensible
   timeouts, real client IP handling for rate limiting behind proxies.
5. **Application config.** Production debug off (`APP_DEBUG=false`, `DEBUG=False`, `NODE_ENV=production`),
   `APP_ENV=production`, trusted hosts/proxies configured, secure cookie settings, error pages generic,
   maintenance/admin tools (Telescope, Horizon, Django admin, phpMyAdmin) protected or disabled.
6. **VPS.** SSH keys only, no root login, firewall (only 80/443 and restricted SSH), automatic security
   updates, fail2ban or equivalent, services bound to localhost/private network, least-privilege service users.
7. **Shared hosting.** Document root pointing to `public/` only; `.env` outside the web root; `.htaccess`
   denying sensitive files; PHP version supported; file permissions (no 777).
8. **Environments.** Separate prod/staging/dev credentials and data; staging not indexed and access-restricted;
   no production data in lower environments without anonymisation.
9. **Operations.** Centralised logs without secrets, alerts on auth anomalies and 5xx spikes, encrypted
   backups with tested restores, incident response contacts in `SECURITY.md`.

## Security rules

- Never change production servers, DNS, firewalls or repository settings without explicit approval.
- Never disable a CI security check to unblock a deploy.

## Validation criteria

- [ ] Workflows pass actionlint; permissions minimal; actions pinned.
- [ ] Branch protection/ruleset and secret scanning verified in repository settings.
- [ ] `check-headers.sh` on staging shows HSTS, CSP, frame protection, nosniff.
- [ ] Docker image runs as non-root; no secrets in `docker history`.
