---
name: authentication-security
description: Review and harden authentication in a SaaS application — login, registration, password storage, sessions and cookies, JWT/API tokens, MFA, OAuth/SSO and account recovery. Use when touching auth code or auditing identity flows.
---

# Authentication security

Part of saas-blind-security — created and maintained by IbrahimCodeur.

## Objectives

- Only legitimate users obtain sessions or tokens, and those credentials cannot be forged, stolen easily or reused.
- Account recovery and MFA cannot be used to bypass authentication.
- Align with OWASP ASVS V2 (Authentication) and V3 (Session Management).

## Steps

1. **Map the flows.** Registration, login, logout, password change, password reset, email change, MFA
   enrolment/verification/recovery codes, OAuth/SSO callbacks, API keys, "remember me", impersonation.
2. **Password storage.** Must use a slow adaptive hash: Laravel `Hash::make` (bcrypt/argon2id), Django
   `make_password` (PBKDF2/argon2), Node `bcrypt`/`argon2`. Flag md5/sha1/sha256 of passwords
   (Semgrep: `sbs-*-weak-password-hash`). Check minimum length (≥ 8, ASVS recommends 12+ for new
   systems), breached-password checks if available, no maximum length below 64.
3. **Brute force & enumeration.** Rate limit login, reset and MFA endpoints per account and per IP
   (Laravel `RateLimiter`/`throttle`, `express-rate-limit`, Django-axes / DRF throttling). Same response and
   timing for "unknown user" and "wrong password"; reset endpoints must not reveal whether an email exists.
4. **Sessions.** Regenerate session ID on login and privilege change (`$request->session()->regenerate()`,
   Django does this on `login()`, `req.session.regenerate` in express-session). Invalidate other sessions on
   password change. Server-side logout. Idle and absolute timeouts.
5. **Cookies.** `HttpOnly`, `Secure`, `SameSite=Lax` (or `Strict`), narrow `Domain`/`Path`.
   Laravel `config/session.php`, Django `SESSION_COOKIE_*`/`CSRF_COOKIE_*`, express-session `cookie: {}`.
6. **Tokens/JWT.** Verify signature with a pinned algorithm list (`jwt.verify(t, key, {algorithms:[...]})`,
   PyJWT `algorithms=[...]`); never `jwt.decode` for authentication; validate `exp`, `nbf`, `iss`, `aud`.
   Short-lived access tokens, rotating refresh tokens stored hashed, revocation on logout/password change.
   API keys: random ≥ 128 bits, stored hashed, scoped, revocable, shown once.
7. **Password reset.** Single-use, random (CSPRNG) token stored hashed, expires ≤ 60 min, invalidated after
   use and after password change, sent only to the verified address, no token in referrer/logs.
8. **MFA.** TOTP/WebAuthn verification server-side, rate-limited; recovery codes hashed and single-use; MFA
   required again for disabling MFA or changing email; no "MFA required" flag the client can skip.
9. **OAuth/SSO.** `state` parameter (CSRF), PKCE for public clients, exact redirect-URI matching, verify ID
   token signature/audience, link accounts only on verified email, no account takeover via unverified
   provider emails.
10. **Email change / account linking.** Confirm via the old and new address; re-authenticate.

## Security rules

- Never log passwords, tokens, reset links, MFA secrets or session IDs.
- Never weaken a check to fix a login bug (e.g. skipping MFA, accepting unsigned tokens, widening CORS).
- Do not test credentials found in the code against real services.
- Changes to auth flows require user approval and tests for both success and failure paths.

## Validation criteria

- [ ] Tests prove: wrong password fails, locked/rate-limited after N attempts, reset token single-use and expiring,
      forged/expired/`alg:none` JWT rejected, session ID changes after login, sessions invalidated after password change.
- [ ] Password hashing uses an adaptive algorithm.
- [ ] Cookie flags verified (code + `scripts/check-headers.sh` on a local instance).
- [ ] No user-enumeration difference in responses.
