#!/usr/bin/env bash
# saas-blind-security - detect the technology stack of a project (read-only).
# Created and maintained by IbrahimCodeur - https://github.com/IbrahimCodeur
# SPDX-License-Identifier: MIT
#
# Usage:
#   detect-stack.sh [--json | --codeql-languages | --dependabot-ecosystems] [PROJECT_DIR]
#
# This script never modifies the audited project.

set -uo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

MODE="text"
TARGET="."
while [ $# -gt 0 ]; do
  case "$1" in
    --json) MODE="json" ;;
    --codeql-languages) MODE="codeql" ;;
    --dependabot-ecosystems) MODE="dependabot" ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    -*) die "Unknown option: $1" ;;
    *) TARGET="$1" ;;
  esac
  shift
done
[ -d "$TARGET" ] || die "Not a directory: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"
sbs_load_config "$TARGET/.saas-blind-security/sbs.conf"
sbs_load_config "$TARGET/config/sbs.conf"

# Directories never scanned for detection.
# .claude and .saas-blind-security hold agent tooling (skills, scripts), not application code.
PRUNE_DIRS="node_modules vendor .git dist build .next .nuxt .venv venv __pycache__ coverage .sbs-results .claude .saas-blind-security"
EXTRA_EXCLUDES="${SBS_EXCLUDE_PATHS:-}"

# exclude_filter : drop paths matching SBS_EXCLUDE_PATHS entries
exclude_filter() {
  local f skip ex
  while IFS= read -r f; do
    skip=0
    for ex in $EXTRA_EXCLUDES; do
      case "$f" in "$ex"|"$ex"/*) skip=1 ;; esac
    done
    [ "$skip" -eq 0 ] && printf '%s\n' "$f"
  done
  return 0
}

# list_files <find -name expression...> : prints relative paths
list_files() {
  local prune=() d
  for d in $PRUNE_DIRS; do prune+=( -name "$d" -o ); done
  ( cd "$TARGET" && find . -maxdepth "${SBS_DETECT_DEPTH:-5}" \( "${prune[@]}" -false \) -prune -o -type f \( "$@" \) -print 2>/dev/null ) \
    | sed 's#^\./##' | exclude_filter
}

DETECTED=""   # newline separated "category|name|evidence"
add() { DETECTED="${DETECTED}$1|$2|$3"$'\n'; }
has_item() { printf '%s' "$DETECTED" | grep -q "^[^|]*|$1|"; }

# grep_in <pattern> <files...> : 0 if pattern found in any existing file
grep_in() {
  local pat="$1"; shift
  local f
  for f in "$@"; do
    [ -f "$TARGET/$f" ] && grep -Eqi -- "$pat" "$TARGET/$f" && return 0
  done
  return 1
}
first_match() {
  local pat="$1"; shift
  local f
  for f in "$@"; do
    [ -f "$TARGET/$f" ] && grep -Eqi -- "$pat" "$TARGET/$f" && { printf '%s' "$f"; return 0; }
  done
  return 1
}

# ---------------------------------------------------------------- manifests
PKG_JSON=(); while IFS= read -r f; do PKG_JSON+=("$f"); done < <(list_files -name package.json)
COMPOSER=(); while IFS= read -r f; do COMPOSER+=("$f"); done < <(list_files -name composer.json)
PYREQ=();    while IFS= read -r f; do PYREQ+=("$f"); done < <(list_files -name 'requirements*.txt' -o -name pyproject.toml -o -name Pipfile -o -name setup.py -o -name setup.cfg)
DOCKER=();   while IFS= read -r f; do DOCKER+=("$f"); done < <(list_files -name Dockerfile -o -name 'Dockerfile.*' -o -name '*.Dockerfile' -o -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' -o -name 'compose.yml' -o -name 'compose.yaml')
ENVF=();     while IFS= read -r f; do ENVF+=("$f"); done < <(list_files -name '.env*' -o -name '*.env')
ALL_MANIFESTS=( ${PKG_JSON[@]+"${PKG_JSON[@]}"} ${COMPOSER[@]+"${COMPOSER[@]}"} ${PYREQ[@]+"${PYREQ[@]}"} ${DOCKER[@]+"${DOCKER[@]}"} ${ENVF[@]+"${ENVF[@]}"} )

# ---------------------------------------------------------------- languages
if [ ${#COMPOSER[@]} -gt 0 ] || [ -n "$(list_files -name '*.php' | head -n1)" ]; then
  add language php "$( [ ${#COMPOSER[@]} -gt 0 ] && echo "${COMPOSER[0]}" || list_files -name '*.php' | head -n1)"
fi
if [ ${#PKG_JSON[@]} -gt 0 ]; then add language nodejs "${PKG_JSON[0]}"; fi
JSF="$(list_files -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.vue' | head -n1)"
TSF="$(list_files -name '*.ts' -o -name '*.tsx' | head -n1)"
[ -n "$JSF" ] && add language javascript "$JSF"
[ -n "$TSF" ] && add language typescript "$TSF"
PYF="$(list_files -name '*.py' | head -n1)"
if [ ${#PYREQ[@]} -gt 0 ] || [ -n "$PYF" ]; then
  add language python "$( [ ${#PYREQ[@]} -gt 0 ] && echo "${PYREQ[0]}" || echo "$PYF")"
fi

# ---------------------------------------------------------------- backend frameworks
if [ -f "$TARGET/artisan" ] || grep_in '"laravel/framework"' ${COMPOSER[@]+"${COMPOSER[@]}"}; then
  add backend laravel "$( [ -f "$TARGET/artisan" ] && echo artisan || first_match '"laravel/framework"' "${COMPOSER[@]}")"
fi
m="$(first_match '"express"[[:space:]]*:' ${PKG_JSON[@]+"${PKG_JSON[@]}"})" && add backend express "$m"
m="$(first_match '"@nestjs/core"' ${PKG_JSON[@]+"${PKG_JSON[@]}"})" && add backend nestjs "$m"
m="$(first_match '(^|[^a-z-])django([^a-z-]|$)' ${PYREQ[@]+"${PYREQ[@]}"})" && add backend django "$m"
[ -z "$m" ] && [ -f "$TARGET/manage.py" ] && grep -q django "$TARGET/manage.py" 2>/dev/null && add backend django manage.py
m="$(first_match '(^|[^a-z-])fastapi([^a-z-]|$)' ${PYREQ[@]+"${PYREQ[@]}"})" && add backend fastapi "$m"

# ---------------------------------------------------------------- frontend frameworks
m="$(first_match '"next"[[:space:]]*:' ${PKG_JSON[@]+"${PKG_JSON[@]}"})" && add frontend nextjs "$m"
m="$(first_match '"nuxt"[[:space:]]*:|"nuxt3"[[:space:]]*:' ${PKG_JSON[@]+"${PKG_JSON[@]}"})" && add frontend nuxt "$m"
m="$(first_match '"react"[[:space:]]*:' ${PKG_JSON[@]+"${PKG_JSON[@]}"})" && add frontend react "$m"
m="$(first_match '"vue"[[:space:]]*:' ${PKG_JSON[@]+"${PKG_JSON[@]}"})" && add frontend vue "$m"
m="$(first_match '"@angular/core"' ${PKG_JSON[@]+"${PKG_JSON[@]}"})" && add frontend angular "$m"

# ---------------------------------------------------------------- databases
DBFILES=( ${ALL_MANIFESTS[@]+"${ALL_MANIFESTS[@]}"} )
for f in config/database.php settings.py */settings.py prisma/schema.prisma; do [ -f "$TARGET/$f" ] && DBFILES+=("$f"); done
m="$(first_match 'mariadb' ${DBFILES[@]+"${DBFILES[@]}"})" && add database mariadb "$m"
m="$(first_match 'mysql|pdo_mysql|"mysql2"|mysqlclient|pymysql' ${DBFILES[@]+"${DBFILES[@]}"})" && add database mysql "$m"
m="$(first_match 'postgres|pgsql|"pg"[[:space:]]*:|psycopg|asyncpg' ${DBFILES[@]+"${DBFILES[@]}"})" && add database postgresql "$m"
m="$(first_match 'mongodb|mongoose|pymongo|motor' ${DBFILES[@]+"${DBFILES[@]}"})" && add database mongodb "$m"
m="$(first_match 'redis|ioredis|predis' ${DBFILES[@]+"${DBFILES[@]}"})" && add database redis "$m"

# ---------------------------------------------------------------- infrastructure
[ ${#DOCKER[@]} -gt 0 ] && add infrastructure docker "${DOCKER[0]}"
WF="$(cd "$TARGET" && find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sed 's#^\./##' | sort | head -n1)"
[ -n "$WF" ] && add infrastructure github-actions "$WF"
NG="$(list_files -name 'nginx*.conf' -o -path '*nginx*' -name '*.conf' | head -n1)"
[ -n "$NG" ] && add infrastructure nginx "$NG"
AP="$(list_files -name .htaccess -o -name 'httpd*.conf' -o -name 'apache*.conf' | head -n1)"
[ -n "$AP" ] && add infrastructure apache "$AP"
IAC="$(list_files -name '*.tf' -o -name 'serverless.yml' -o -name 'Chart.yaml' | head -n1)"
[ -n "$IAC" ] && add infrastructure iac "$IAC"

# ---------------------------------------------------------------- SaaS features (heuristics)
SRC_GREP() { # pattern [ignored-path-regex] -> first file containing it (bounded search)
  ( cd "$TARGET" && grep -rIlE --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=.git \
      --exclude-dir=.sbs-results --exclude-dir=dist --exclude-dir=build --exclude-dir=.venv \
      --exclude-dir=.saas-blind-security --exclude-dir=.claude \
      -- "$1" . 2>/dev/null | sed 's#^\./##' | grep -vE "${2:-^$}" | exclude_filter | head -n1 )
}
m="$(SRC_GREP 'stripe|paypal|braintree|mollie|paddle|lemonsqueezy|cashier')" && [ -n "$m" ] && add feature payments "$m"
m="$(SRC_GREP 'graphql|apollo-server|graphene|strawberry|lighthouse-php')" && [ -n "$m" ] && add feature graphql "$m"
# config/permission.php is spatie/laravel-permission: its optional team_id column is not a tenancy model.
m="$(SRC_GREP 'tenant_id|tenantId|organization_id|team_id|workspace_id|stancl/tenancy|spatie/laravel-multitenancy' '^config/permission\.php$')" && [ -n "$m" ] && add feature multi-tenancy "$m"
m="$(SRC_GREP 'jsonwebtoken|firebase/php-jwt|PyJWT|python-jose|passport|sanctum|next-auth|@auth/|socialite|oauth')" && [ -n "$m" ] && add feature token-auth "$m"
m="$(SRC_GREP 'webhook')" && [ -n "$m" ] && add feature webhooks "$m"
m="$(SRC_GREP 'multer|move_uploaded_file|UploadedFile|FileField|ImageField|storeAs\(|formidable|busboy')" && [ -n "$m" ] && add feature file-upload "$m"

# ---------------------------------------------------------------- output
codeql_languages() {
  local langs=()
  # CodeQL scans GitHub Actions workflows.
  has_item github-actions && langs+=("actions")
  { has_item javascript || has_item typescript; } && langs+=("javascript-typescript")
  has_item python && langs+=("python")
  # PHP is NOT supported by CodeQL: Semgrep and Snyk cover it.
  if [ ${#langs[@]} -eq 0 ]; then echo '[]'; return; fi
  printf '%s\n' "${langs[@]}" | jq -R . | jq -sc .
}

dependabot_ecosystems() {
  # Prints "ecosystem directory" lines for manifests that actually exist.
  local f d
  for f in ${PKG_JSON[@]+"${PKG_JSON[@]}"}; do d="/$(dirname "$f")"; echo "npm ${d%/.}"; done
  for f in ${COMPOSER[@]+"${COMPOSER[@]}"}; do d="/$(dirname "$f")"; echo "composer ${d%/.}"; done
  for f in ${PYREQ[@]+"${PYREQ[@]}"}; do d="/$(dirname "$f")"; echo "pip ${d%/.}"; done
  for f in ${DOCKER[@]+"${DOCKER[@]}"}; do
    case "$(basename "$f")" in
      Dockerfile|Dockerfile.*|*.Dockerfile) d="/$(dirname "$f")"; echo "docker ${d%/.}" ;;
      *) d="/$(dirname "$f")"; echo "docker-compose ${d%/.}" ;;
    esac
  done
  [ -d "$TARGET/.github/workflows" ] && echo "github-actions /"
  return 0
}

case "$MODE" in
  codeql) codeql_languages ;;
  dependabot) dependabot_ecosystems | sed 's#  *$##; s# $# /#' | awk '{ if ($2=="") $2="/"; print $1" "$2 }' | sort -u ;;
  json)
    printf '%s' "$DETECTED" | jq -R -s --arg target "$TARGET" --argjson codeql "$(codeql_languages)" '
      split("\n") | map(select(length>0) | split("|") | {category: .[0], name: .[1], evidence: .[2]})
      | {target: $target, detected: ., codeql_languages: $codeql,
         note: "Detection is heuristic (file and dependency names). Confirm manually before relying on it."}'
    ;;
  text)
    echo "Stack detected in: $TARGET"
    if [ -z "$DETECTED" ]; then echo "  (nothing recognised)"; exit 0; fi
    for cat in language backend frontend database infrastructure feature; do
      lines="$(printf '%s' "$DETECTED" | awk -F'|' -v c="$cat" '$1==c {printf "    - %-16s (evidence: %s)\n", $2, $3}')"
      [ -n "$lines" ] && { echo "  $cat:"; printf '%s\n' "$lines"; }
    done
    echo "  codeql languages: $(codeql_languages)"
    echo "Note: detection is heuristic. Confirm it before relying on it."
    ;;
esac
