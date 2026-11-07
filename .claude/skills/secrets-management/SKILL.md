---
name: secrets-management
description: Find, contain and prevent exposed secrets — API keys, tokens, passwords, private keys and environment files — and set up proper storage, rotation and GitHub secret scanning with push protection. Use when secrets are found, when configuring environments or CI, or during audits.
---

# Secrets management

Part of saas-blind-security — created and maintained by IbrahimCodeur.

## Objectives

- No secret in source code, git history, logs, images, client bundles or reports.
- Secrets are stored in the environment / secret manager, scoped, rotated and revocable.

## Steps

1. **Detect.** `$SBS/scripts/security-check.sh --only builtin,semgrep` (rules `sbs-builtin-hardcoded-secret`,
   `sbs-known-token-format`, `sbs-hardcoded-credential-assignment`), GitHub secret scanning alerts, review of
   `.env*`, config files, Docker build args, CI files, frontend bundles (`NEXT_PUBLIC_*`, `VITE_*`,
   `NUXT_PUBLIC_*` are public by design — they must not contain secrets).
2. **History.** If git history is available, check whether the secret was ever committed
   (`git log -p -S '<prefix>'` with a non-secret prefix only). Removing it from HEAD is not enough.
3. **Contain (with the user).** A committed secret must be considered compromised: revoke/rotate it at the
   provider first, then remove it from the code, then optionally purge history (`git filter-repo`) — history
   rewriting requires the user's explicit approval and coordination.
4. **Store properly.** Environment variables loaded at runtime, `.env` git-ignored with a `.env.example`
   containing placeholders only; GitHub Actions secrets / environments for CI; a secret manager (cloud provider
   or Vault) for production; least-privilege, per-environment keys; separate test and live keys.
5. **Prevent.** Enable GitHub secret scanning + push protection (`$SBS/scripts/configure-github-security.sh`),
   `.gitignore` for `.env*`, no secrets in Docker images (use runtime env or BuildKit secrets), no secrets
   in logs/error trackers (scrub), CI uses `${{ secrets.X }}` and never echoes them.
6. **Application secrets.** Laravel `APP_KEY`, Django `SECRET_KEY`, JWT signing keys, session secrets: unique
   per environment, long and random, rotated with a plan (rotation invalidates sessions/tokens).

## Security rules

- Never display, copy, test or transmit a discovered secret. Report file:line and `[REDACTED]`.
- Never commit realistic fake secrets in tests; generate them at runtime.
- Do not rewrite git history or rotate production keys yourself without explicit approval.

## Validation criteria

- [ ] Secret scanners clean, or every finding classified (rotated + removed, or false positive).
- [ ] `.env` ignored; `.env.example` contains placeholders only.
- [ ] Push protection enabled (or documented as unavailable for the plan).
- [ ] Rotation performed or explicitly handed over to the owner for each exposed secret.
