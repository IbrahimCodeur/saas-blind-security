---
name: frontend-security
description: Protect SaaS frontends against XSS, CSRF, clickjacking, open redirects, token leakage and unsafe client-side data handling in React, Next.js, Vue, Nuxt, Angular and server-rendered templates (Blade, Django templates). Use when reviewing UI code, templates, CSP or browser-facing configuration.
---

# Frontend security

Part of saas-blind-security — created and maintained by IbrahimCodeur.

## Objectives

- User-controlled data can never execute as code in the browser.
- State-changing requests cannot be forged cross-site; pages cannot be framed maliciously.
- The client never holds secrets or makes security decisions.

## Steps

1. **XSS sinks.** Review: React `dangerouslySetInnerHTML`, `innerHTML`/`outerHTML`/`insertAdjacentHTML`,
   `document.write`, Vue `v-html`, Angular `bypassSecurityTrust*`, Blade `{!! !!}`, Django `|safe`/`mark_safe`,
   Jinja `Markup`, `href`/`src` bound to user data (`javascript:` URLs), Markdown renderers, rich-text editors.
   Semgrep: `sbs-js-dangerous-html-sink`, `sbs-vue-v-html`, `sbs-blade-unescaped-output`,
   `sbs-angular-bypass-security-trust`, `sbs-py-django-mark-safe-variable`. Fix: render as text, or sanitise
   with DOMPurify (client) / HTML Purifier / bleach-like allow-list (server); validate URL schemes.
2. **CSP.** Add a Content-Security-Policy (nonce- or hash-based scripts, `object-src 'none'`,
   `base-uri 'self'`, `frame-ancestors`), start in `Report-Only` if needed. Avoid `'unsafe-inline'`/`'unsafe-eval'`.
3. **CSRF.** Cookie-authenticated state changes need CSRF protection: Laravel `VerifyCsrfToken` (check the
   `$except` list), Django `CsrfViewMiddleware` (review `@csrf_exempt`), SameSite cookies, Next.js server
   actions origin checks, double-submit tokens for SPAs. Token-in-header APIs are not exposed to CSRF if they do
   not accept cookies.
4. **Clickjacking.** `X-Frame-Options: DENY` or CSP `frame-ancestors 'none'` (allow-list for embeds).
5. **Token storage.** Prefer HttpOnly cookies over `localStorage` for session tokens; never put secrets in
   `NEXT_PUBLIC_*`/`VITE_*`/`NUXT_PUBLIC_*` or the bundle; source maps not public in production.
6. **Open redirects.** `?next=`/`returnUrl` validated against relative paths or an allow-list.
7. **postMessage / third parties.** Check `event.origin`; Subresource Integrity for CDN scripts; review
   third-party scripts' access to pages with sensitive data.
8. **Client-side checks are UX only.** Every permission, price, quota and validation is repeated server-side.
9. **Headers.** Run `$SBS/scripts/check-headers.sh http://localhost:<port>` against a local build.

## Security rules

- Do not disable framework auto-escaping or CSRF middleware to fix a bug.
- Never test XSS payloads on production or on other people's systems.

## Validation criteria

- [ ] All raw-HTML sinks removed or fed only by sanitised/constant data (tests with `<img src=x onerror=alert(1)>`).
- [ ] CSRF protection active on cookie-authenticated mutations (test without token → 419/403).
- [ ] CSP and anti-framing headers present (header check output attached).
- [ ] No secret in client bundles or public env vars.
