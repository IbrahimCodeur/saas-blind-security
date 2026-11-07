#!/usr/bin/env bash
# saas-blind-security - check HTTP security headers of a URL you are authorised to test.
# Created and maintained by IbrahimCodeur - https://github.com/IbrahimCodeur
# SPDX-License-Identifier: MIT
#
# Usage: check-headers.sh URL [--json] [--admin-paths "/admin /login"] [--listing-paths "/uploads/ /storage/"]
# Sends ONE GET request to URL (no crawling, no attack payloads). Exit 1 if a required header is missing.
# --admin-paths (or SBS_ADMIN_PATHS) adds one GET per listed path on the same origin, following at most
# 3 same-origin redirects, and fails if the final page can be indexed by search engines (no
# X-Robots-Tag: noindex header and no <meta name="robots" content="noindex">). Admin pages, their login
# page and anything that shows account data must never appear in search results.
# For admin paths (names containing admin, backoffice or manage) it also warns when an anonymous visitor
# can tell the area exists: a redirect to a login page, 401 or 403 instead of the site's normal 404.
# --listing-paths (or SBS_LISTING_PATHS) adds one GET per directory and fails on an auto-generated
# directory listing ("Index of /..."). For an https:// URL, one extra GET on http:// checks that plain
# HTTP is redirected to HTTPS.

set -uo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# Project configuration, read from the directory the check is run from (environment variables win).
sbs_load_config "$PWD/.saas-blind-security/sbs.conf"
sbs_load_config "$PWD/config/sbs.conf"
URL=""; FORMAT="text"; ADMIN_PATHS="${SBS_ADMIN_PATHS:-}"; LISTING_PATHS="${SBS_LISTING_PATHS:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --json) FORMAT="--json" ;;
    --admin-paths) shift; ADMIN_PATHS="${1:-}" ;;
    --listing-paths) shift; LISTING_PATHS="${1:-}" ;;
    -*) die "Unknown option: $1" ;;
    *) URL="$1" ;;
  esac
  shift
done
[ -n "$URL" ] || die "Usage: check-headers.sh URL [--json] [--admin-paths \"/admin /login\"]"
case "$URL" in http://*|https://*) ;; *) die "URL must start with http:// or https://" ;; esac
have curl || die "curl is required"

HDRS="$(curl -sS -o /dev/null -D - --max-time 20 -A "saas-blind-security-header-check" "$URL" 2>/dev/null | tr -d '\r')" \
  || die "Request failed: $URL"
[ -n "$HDRS" ] || die "No response from $URL"
get() { printf '%s\n' "$HDRS" | grep -i "^$1:" | tail -n1 | cut -d: -f2- | sed 's/^ *//'; }

RESULTS=""; FAIL=0
res() { RESULTS="${RESULTS}$1|$2|$3|$4"$'\n'; [ "$2" = "FAIL" ] && FAIL=1; return 0; }

hsts="$(get Strict-Transport-Security)"
case "$URL" in
  https://*) if [ -z "$hsts" ]; then res Strict-Transport-Security FAIL MEDIUM "missing"
             elif printf '%s' "$hsts" | grep -Eq 'max-age=([0-9]{7,}|[3-9][0-9]{6})'; then res Strict-Transport-Security PASS - "$hsts"
             else res Strict-Transport-Security WARN LOW "max-age below ~1 year: $hsts"; fi ;;
  *) res Strict-Transport-Security WARN MEDIUM "site served over plain HTTP" ;;
esac
csp="$(get Content-Security-Policy)"
if [ -z "$csp" ]; then res Content-Security-Policy FAIL MEDIUM "missing"
elif printf '%s' "$csp" | grep -Eq "'unsafe-inline'|'unsafe-eval'"; then res Content-Security-Policy WARN LOW "contains unsafe-inline/unsafe-eval"
else res Content-Security-Policy PASS - "present"; fi
xcto="$(get X-Content-Type-Options)"
[ "$(printf '%s' "$xcto" | tr '[:upper:]' '[:lower:]')" = "nosniff" ] && res X-Content-Type-Options PASS - nosniff || res X-Content-Type-Options FAIL LOW "missing or not nosniff"
xfo="$(get X-Frame-Options)"
if [ -n "$xfo" ] || printf '%s' "$csp" | grep -q 'frame-ancestors'; then res Clickjacking-protection PASS - "${xfo:-CSP frame-ancestors}"
else res Clickjacking-protection FAIL MEDIUM "no X-Frame-Options and no CSP frame-ancestors"; fi
rp="$(get Referrer-Policy)"; [ -n "$rp" ] && res Referrer-Policy PASS - "$rp" || res Referrer-Policy WARN LOW missing
pp="$(get Permissions-Policy)"; [ -n "$pp" ] && res Permissions-Policy PASS - present || res Permissions-Policy WARN INFO missing
srv="$(get Server)"; xpb="$(get X-Powered-By)"
if printf '%s %s' "$srv" "$xpb" | grep -Eq '[0-9]+\.[0-9]+'; then res Version-disclosure WARN LOW "Server/X-Powered-By reveals a version"
else res Version-disclosure PASS - "no version disclosed"; fi
acao="$(get Access-Control-Allow-Origin)"; acac="$(get Access-Control-Allow-Credentials)"
if [ "$acao" = "*" ] && [ "$(printf '%s' "$acac" | tr '[:upper:]' '[:lower:]')" = "true" ]; then res CORS FAIL HIGH "wildcard origin with credentials"
else res CORS PASS - "${acao:-not set}"; fi
while IFS= read -r c; do
  [ -z "$c" ] && continue
  name="$(printf '%s' "$c" | cut -d= -f1)"; low="$(printf '%s' "$c" | tr '[:upper:]' '[:lower:]')"
  miss=""
  # CSRF double-submit cookies are read by JavaScript on purpose: HttpOnly would break them.
  case "$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')" in
    xsrf-token|csrftoken|csrf-token|_csrf) ;;
    *) printf '%s' "$low" | grep -q 'httponly' || miss="$miss HttpOnly" ;;
  esac
  case "$URL" in https://*) printf '%s' "$low" | grep -q 'secure' || miss="$miss Secure" ;; esac
  printf '%s' "$low" | grep -q 'samesite' || miss="$miss SameSite"
  [ -n "$miss" ] && res "Cookie:$name" WARN LOW "missing:$miss" || res "Cookie:$name" PASS - "flags ok"
done < <(printf '%s\n' "$HDRS" | grep -i '^set-cookie:' | cut -d: -f2- | sed 's/^ *//')

# Admin pages must never be indexable. Same origin only, GET only, no credentials sent.
ORIGIN="$(printf '%s' "$URL" | sed -E 's#^(https?://[^/]+).*#\1#')"
for path in $ADMIN_PATHS; do
  case "$path" in /*) ;; *) path="/$path" ;; esac
  page="$(curl -sS -L --max-redirs 3 --proto =http,https --max-time 20 -A "saas-blind-security-header-check" \
    -D - -w '\n%{http_code} %{url_effective}' "$ORIGIN$path" 2>/dev/null | tr -d '\r')" || { res "Admin-noindex:$path" WARN INFO "request failed"; continue; }
  last="$(printf '%s\n' "$page" | tail -n1)"; code="${last%% *}"; final="${last#* }"
  case "$final" in "$ORIGIN"|"$ORIGIN"/*) ;; *) res "Admin-noindex:$path" WARN INFO "redirects to another origin ($final): check that site separately"; continue ;; esac
  if [ "$code" = "404" ] || [ "$code" = "410" ]; then res "Admin-noindex:$path" PASS - "HTTP $code (no page)"; continue; fi
  # Headers of the final response: the last block of HTTP/ headers before the body.
  hdrs="$(printf '%s\n' "$page" | awk '/^HTTP\//{blk=""} /^HTTP\//,/^$/{blk=blk $0 "\n"} END{printf "%s", blk}')"
  xrt="$(printf '%s' "$hdrs" | grep -i '^x-robots-tag:' | tr '[:upper:]' '[:lower:]')"
  meta="$(printf '%s' "$page" | head -c 200000 | tr '[:upper:]' '[:lower:]' | grep -oE '<meta[^>]+name=["'"'"']?robots["'"'"']?[^>]*>' | grep -c 'noindex')"
  if printf '%s' "$xrt" | grep -q 'noindex' || [ "${meta:-0}" -gt 0 ]; then
    res "Admin-noindex:$path" PASS - "HTTP $code, noindex ($([ -n "$xrt" ] && echo header || echo meta))"
  else
    res "Admin-noindex:$path" FAIL MEDIUM "HTTP $code at ${final#"$ORIGIN"} without X-Robots-Tag noindex or meta robots noindex"
  fi
  case "$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')" in
    *admin*|*backoffice*|*manage*)
      first="$(printf '%s\n' "$page" | grep -m1 -E '^HTTP/' | awk '{print $2}')"
      landing="$(printf '%s' "${final#"$ORIGIN"}" | tr '[:upper:]' '[:lower:]')"
      if [ "$first" = "401" ] || [ "$first" = "403" ]; then
        res "Admin-discoverable:$path" WARN LOW "anonymous visitors get HTTP $first: the admin area is confirmed to exist (answer 404 like an unknown URL)"
      elif printf '%s' "$first" | grep -qE '^30[1278]$' && printf '%s' "$landing" | grep -qE 'login|signin|sign-in|connexion|auth'; then
        res "Admin-discoverable:$path" WARN LOW "redirects anonymous visitors to $landing: the admin area is confirmed to exist (answer 404 like an unknown URL)"
      fi ;;
  esac
done

# Auto-generated directory listings expose file names (uploads, backups, exports).
for path in $LISTING_PATHS; do
  case "$path" in /*) ;; *) path="/$path" ;; esac
  body="$(curl -sS --max-time 20 --proto =http,https -A "saas-blind-security-header-check" -w '\n%{http_code}' "$ORIGIN$path" 2>/dev/null | tr -d '\r')" || { res "Directory-listing:$path" WARN INFO "request failed"; continue; }
  code="$(printf '%s\n' "$body" | tail -n1)"
  if printf '%s' "$body" | head -c 200000 | grep -qiE '<title>(index of|directory listing for) /|<h1>(index of|directory listing for) /'; then
    res "Directory-listing:$path" FAIL MEDIUM "HTTP $code returns an automatic directory listing"
  else
    res "Directory-listing:$path" PASS - "HTTP $code, no listing"
  fi
done

# Plain HTTP must redirect to HTTPS before anything is served (cookies, passwords, pages).
case "$URL" in
  https://*)
    plain="http://${URL#https://}"
    hres="$(curl -sS -o /dev/null --max-time 20 -A "saas-blind-security-header-check" -w '%{http_code} %{redirect_url}' "$plain" 2>/dev/null)"
    hcode="${hres%% *}"; hloc="${hres#* }"
    if [ -z "$hres" ] || [ "$hcode" = "000" ]; then res HTTPS-redirect PASS - "plain HTTP not reachable"
    elif printf '%s' "$hcode" | grep -qE '^30[1278]$' && [ "${hloc#https://}" != "$hloc" ]; then res HTTPS-redirect PASS - "HTTP $hcode to $hloc"
    else res HTTPS-redirect FAIL MEDIUM "plain HTTP answers $hcode without redirecting to HTTPS"; fi ;;
esac

if [ "$FORMAT" = "--json" ]; then
  printf '%s' "$RESULTS" | jq -R -s --arg url "$URL" 'split("\n") | map(select(length>0) | split("|") | {check:.[0], result:.[1], severity:.[2], detail:.[3]}) | {url:$url, checks:.}'
else
  echo "Header check for $URL"
  printf '%s' "$RESULTS" | awk -F'|' '{printf "  %-5s %-36s %-7s %s\n", $2, $1, $3, $4}'
  echo "Note: headers are one layer of defence; this check does not test the application itself."
fi
exit "$FAIL"
