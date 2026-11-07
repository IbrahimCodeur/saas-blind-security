#!/usr/bin/env bash
# saas-blind-security - framework test suite (bash 3.2+, needs git and jq; semgrep optional).
# Created and maintained by IbrahimCodeur - https://github.com/IbrahimCodeur
# SPDX-License-Identifier: MIT
#
# Usage: tests/run-tests.sh
# Tests that need an optional tool are reported as SKIP (never as PASS) when the tool is missing.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$ROOT/scripts"
FIX="$ROOT/tests/fixtures"
DATA="$ROOT/tests/data"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export NO_COLOR=1
PASS=0; FAIL=0; SKIP=0

pass() { PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; return 0; }
skip() { SKIP=$((SKIP+1)); printf 'SKIP  %s (%s)\n' "$1" "$2"; }
assert() { # description, command...
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d" "command: $*"; fi
}
assert_eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected [$3], got [$2]"; fi; }
# copy a fixture into an isolated git repository
mkrepo() {
  local dst="$TMP/$2"
  mkdir -p "$dst" && cp -R "$FIX/$1/." "$dst/" 2>/dev/null
  ( cd "$dst" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm init --allow-empty ) >/dev/null 2>&1
  printf '%s' "$dst"
}
detected() { "$S/detect-stack.sh" --json "$1" | jq -r '.detected[].name' | sort | tr '\n' ' '; }
has() { case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac; }

echo "== Stack detection"
d="$(detected "$FIX/laravel-saas")"
for n in php laravel mysql redis payments; do assert "laravel fixture detects $n" has "$d" "$n"; done
d="$(detected "$FIX/node-express-saas")"
for n in nodejs javascript express react postgresql redis docker payments token-auth webhooks; do assert "node fixture detects $n" has "$d" "$n"; done
d="$(detected "$FIX/python-fastapi-saas")"
for n in python fastapi postgresql redis; do assert "fastapi fixture detects $n" has "$d" "$n"; done
d="$(detected "$FIX/django-saas")"
for n in python django postgresql; do assert "django fixture detects $n" has "$d" "$n"; done
d="$(detected "$FIX/frontends")"
for n in nextjs react vue nuxt angular mongodb; do assert "frontends fixture detects $n" has "$d" "$n"; done
assert_eq "codeql languages (node)" "$("$S/detect-stack.sh" --codeql-languages "$FIX/node-express-saas")" '["javascript-typescript"]'
assert_eq "codeql languages (laravel, PHP unsupported)" "$("$S/detect-stack.sh" --codeql-languages "$FIX/laravel-saas")" '[]'
DT="$TMP/detect-tooling"; mkdir -p "$DT" && cp -R "$FIX/laravel-saas/." "$DT/"
mkdir -p "$DT/.claude/skills/x/scripts" "$DT/config"
printf 'print("agent tooling")\n' > "$DT/.claude/skills/x/scripts/search.py"
d="$(detected "$DT")"
assert "scripts under .claude/ do not make the project Python" bash -c "! case ' $d ' in *' python '*) true ;; *) false ;; esac"
# The laravel fixture has real tenant code; a project with only the spatie permission config has none.
DP="$TMP/detect-permission"; mkdir -p "$DP/config" && printf '<?php\n' > "$DP/artisan"
printf "<?php\nreturn ['column_names' => ['team_foreign_key' => 'team_id']];\n" > "$DP/config/permission.php"
d="$(detected "$DP")"
assert "spatie permission team_id is not multi-tenancy" bash -c "! case ' $d ' in *' multi-tenancy '*) true ;; *) false ;; esac"
assert_eq "codeql languages (fastapi)" "$("$S/detect-stack.sh" --codeql-languages "$FIX/python-fastapi-saas")" '["python"]'
assert_eq "dependabot ecosystems (node)" "$("$S/detect-stack.sh" --dependabot-ecosystems "$FIX/node-express-saas" | tr '\n' ';')" 'docker /;npm /;'
dep="$("$S/generate-dependabot.sh" "$FIX/frontends")"
assert "generated dependabot.yml lists 4 npm directories" test "$(printf '%s' "$dep" | grep -c 'package-ecosystem: "npm"')" -eq 4
if command -v yamllint >/dev/null 2>&1; then
  printf '%s\n' "$dep" > "$TMP/dependabot.yml"
  assert "generated dependabot.yml is valid YAML" yamllint -d relaxed "$TMP/dependabot.yml"
else skip "generated dependabot.yml is valid YAML" "yamllint not installed"; fi
h1="$(find "$FIX" -type f -exec shasum {} + | sort | shasum)"; "$S/detect-stack.sh" --json "$FIX/laravel-saas" >/dev/null
assert_eq "detect-stack does not modify the project" "$(find "$FIX" -type f -exec shasum {} + | sort | shasum)" "$h1"

echo "== Normaliser"
assert_eq "semgrep severities" "$("$S/normalize-results.sh" semgrep "$DATA/semgrep.json" | jq -c '[.[].severity] | sort')" '["CRITICAL","LOW","MEDIUM"]'
assert_eq "semgrep rule ids drop the local path prefix" "$("$S/normalize-results.sh" semgrep "$DATA/semgrep.json" | jq -r '[.[].rule] | sort | join(",")')" 'sbs-js-dangerous-html-sink,sbs-js-sqli-template-literal,x.info-rule'
jq '.results += [.results[0]]' "$DATA/semgrep.json" > "$TMP/semgrep-dup.json"
assert_eq "semgrep duplicates (same rule+file+line) are merged" "$("$S/normalize-results.sh" semgrep "$TMP/semgrep-dup.json" | jq length)" '3'
assert_eq "snyk severities (deduplicated)" "$("$S/normalize-results.sh" snyk-test "$DATA/snyk-test.json" | jq -c '[.[].severity] | sort')" '["CRITICAL","HIGH"]'
assert_eq "sarif security-severity mapping" "$("$S/normalize-results.sh" sarif "$DATA/sarif.json" | jq -c '[.[].severity]')" '["HIGH","CRITICAL","LOW"]'
assert_eq "npm audit severities" "$("$S/normalize-results.sh" npm-audit "$DATA/npm-audit.json" | jq -c '[.[].severity]')" '["CRITICAL","MEDIUM","MEDIUM"]'
assert_eq "composer audit severities" "$("$S/normalize-results.sh" composer-audit "$DATA/composer-audit.json" | jq -c '[.[].severity]')" '["HIGH","MEDIUM"]'
assert_eq "zap risk mapping" "$("$S/normalize-results.sh" zap "$DATA/zap.json" | jq -c '[.[].severity]')" '["HIGH","MEDIUM","LOW","INFO"]'
assert_eq "all findings start unverified" "$("$S/normalize-results.sh" zap "$DATA/zap.json" | jq -r '[.[].status] | unique | join(",")')" 'unverified'
assert_eq "empty input gives []" "$(: > "$TMP/empty.json"; "$S/normalize-results.sh" semgrep "$TMP/empty.json")" '[]'

echo "== Gate"
"$S/normalize-results.sh" zap "$DATA/zap.json" > "$TMP/zap-f.json"
assert "gate fails at HIGH when a HIGH exists" bash -c "! '$S/gate-findings.sh' '$TMP/zap-f.json' HIGH"
assert "gate passes at CRITICAL" "$S/gate-findings.sh" "$TMP/zap-f.json" CRITICAL
assert "gate NONE never fails" "$S/gate-findings.sh" "$TMP/zap-f.json" NONE
assert "gate rejects invalid level" bash -c "'$S/gate-findings.sh' '$TMP/zap-f.json' BOGUS; [ \$? -eq 2 ]"

echo "== Built-in checks"
R="$(mkrepo node-express-saas b1)"
# Secrets are generated at test time so that no credential-like string is ever committed.
printf 'const k = "%s%s";\n' "AKIA" "ABCDEFGHIJKLMNOP" > "$R/src/aws.js"
printf 'DB_PASSWORD=x\n' > "$R/.env"
( cd "$R" && git add -f .env src/aws.js && git -c user.name=t -c user.email=t@t commit -qm s ) >/dev/null 2>&1
mkdir -p "$R/.github/workflows"
cat > "$R/.github/workflows/bad.yml" <<'YML'
on: pull_request_target
jobs:
  x:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - run: echo "${{ github.event.pull_request.title }}"
YML
OUT="$("$S/builtin-checks.sh" "$R")"
rules="$(printf '%s' "$OUT" | jq -r '[.[].rule] | unique | join(" ")')"
for r in sbs-builtin-hardcoded-secret sbs-builtin-env-file-committed sbs-builtin-gitignore-env sbs-builtin-missing-lockfile \
         sbs-builtin-docker-root sbs-builtin-docker-latest sbs-builtin-gha-pwn-request sbs-builtin-gha-script-injection sbs-builtin-gha-unpinned-action; do
  assert "builtin detects $r" has "$rules" "$r"
done
assert "builtin output never contains the secret value" bash -c "! printf '%s' '$OUT' | grep -q 'ABCDEFGHIJKLMNOP'"
assert_eq "secret finding is CRITICAL with a line number" "$(printf '%s' "$OUT" | jq -r '.[] | select(.rule=="sbs-builtin-hardcoded-secret") | "\(.severity):\(.line)"')" 'CRITICAL:1'
R2="$(mkrepo django-saas b2)"
assert "builtin detects Django DEBUG=True" bash -c "'$S/builtin-checks.sh' '$R2' | jq -e '[.[].rule] | index(\"sbs-builtin-django-debug\")'"
assert_eq "builtin on the framework repository: no CRITICAL/HIGH" "$("$S/builtin-checks.sh" "$ROOT" | jq '[.[] | select(.severity=="CRITICAL" or .severity=="HIGH")] | length')" '0'

# Lockfile: one lockfile is enough, the others may be missing.
R3="$(mkrepo node-express-saas b3)"
printf '{}\n' > "$R3/package-lock.json"
assert "package-lock.json alone satisfies the lockfile check" bash -c "'$S/builtin-checks.sh' '$R3' | jq -e '[.[] | select(.rule==\"sbs-builtin-missing-lockfile\" and .file==\"package.json\")] | length == 0'"

# A secret in a local .env outside git is INFO, not a hardcoded CRITICAL secret.
NG="$TMP/nogit-env"; mkdir -p "$NG"
printf 'GEMINI_API_KEY=%s%s\n' "AIza" "$(printf 'x%.0s' $(seq 1 35))" > "$NG/.env"
OUTNG="$("$S/builtin-checks.sh" "$NG")"
assert_eq "local .env secret outside git is INFO" "$(printf '%s' "$OUTNG" | jq -r '[.[] | select(.file==".env") | "\(.rule):\(.severity)"] | join(",")')" 'sbs-builtin-secret-in-local-env:INFO'
assert "local .env finding never contains the value" bash -c "! printf '%s' '$OUTNG' | grep -q 'xxxxxxxxxx'"

# Admin area: indexable when the project has no noindex mechanism at all.
A1="$TMP/admin1"; mkdir -p "$A1/routes"
printf "<?php\nRoute::get('/', fn () => 'home');\nRoute::prefix('admin')->group(fn () => Route::get('/users', fn () => 'users'));\n" > "$A1/routes/web.php"
printf 'User-agent: *\nDisallow: /admin\n' > "$A1/robots.txt"
OUTA="$("$S/builtin-checks.sh" "$A1")"
assert_eq "admin area without noindex is MEDIUM" "$(printf '%s' "$OUTA" | jq -r '.[] | select(.rule=="sbs-builtin-admin-indexable") | "\(.severity):\(.file):\(.line)"')" 'MEDIUM:routes/web.php:3'
assert "robots.txt listing the admin path is reported" bash -c "printf '%s' '$OUTA' | jq -e '[.[].rule] | index(\"sbs-builtin-robots-reveals-admin\")'"
mkdir -p "$A1/app/Http/Middleware"
printf "<?php\n\$response->headers->set('X-Robots-Tag', 'noindex, nofollow');\n" > "$A1/app/Http/Middleware/NoIndex.php"
assert "admin area with a noindex mechanism is not reported" bash -c "'$S/builtin-checks.sh' '$A1' | jq -e '[.[] | select(.rule==\"sbs-builtin-admin-indexable\")] | length == 0'"

echo "== Configuration loader"
mkdir -p "$TMP/cfg"
# shellcheck disable=SC2016 # literal $(...) on purpose: it must NOT be executed
printf 'SBS_FAIL_ON_SEVERITY=LOW\nSBS_EVIL=$(touch %s/pwned)\nPATH=/nope\nnot a line\n' "$TMP" > "$TMP/cfg/sbs.conf"
val="$(bash -c ". '$S/lib/common.sh'; sbs_load_config '$TMP/cfg/sbs.conf'; printf '%s|%s|%s' \"\$SBS_FAIL_ON_SEVERITY\" \"\$SBS_EVIL\" \"\$PATH\"" 2>/dev/null)"
assert "config values are not executed" test ! -e "$TMP/pwned"
assert_eq "config reads SBS_ keys only" "${val%%|/nope*}" "LOW|\$(touch $TMP/pwned)|${PATH}"
assert_eq "environment overrides config" "$(SBS_FAIL_ON_SEVERITY=CRITICAL bash -c ". '$S/lib/common.sh'; sbs_load_config '$TMP/cfg/sbs.conf'; printf '%s' \"\$SBS_FAIL_ON_SEVERITY\"")" 'CRITICAL'
for u in http://localhost:3000 http://127.0.0.1 http://app.localhost/x 'http://[::1]:8080' https://shop.test; do
  assert "is_local_url $u" bash -c ". '$S/lib/common.sh'; is_local_url '$u'"
done
for u in https://example.com https://localhost.evil.com http://10.0.0.1 https://user@prod.example.com; do
  assert "not local: $u" bash -c ". '$S/lib/common.sh'; ! is_local_url '$u'"
done

echo "== security-check.sh"
R="$(mkrepo laravel-saas c1)"
before="$(cd "$R" && find . -type f | sort | shasum)"
"$S/security-check.sh" --check-only "$R" > "$TMP/co.out" 2>&1; rc=$?
assert_eq "--check-only exits 0" "$rc" "0"
assert_eq "--check-only writes nothing" "$(cd "$R" && find . -type f | sort | shasum)" "$before"
assert "--check-only lists the plan" grep -q 'Check plan' "$TMP/co.out"
mkdir -p "$TMP/fakebin" && printf '#!/bin/sh\necho "Composer version 9.9.9 (fake)"\n' > "$TMP/fakebin/composer.phar" && chmod +x "$TMP/fakebin/composer.phar"
RC="$TMP/composer-proj"; mkdir -p "$RC" && cp -R "$FIX/laravel-saas/." "$RC/" && printf '{"packages":[]}\n' > "$RC/composer.lock"
SBS_COMPOSER_BIN="sh $TMP/fakebin/composer.phar" "$S/security-check.sh" --check-only "$RC" > "$TMP/co2.out" 2>&1
assert "SBS_COMPOSER_BIN makes composer-audit available" grep -Eq 'composer-audit +available +Composer version 9.9.9' "$TMP/co2.out"

"$S/security-check.sh" --only builtin --fail-on NONE --output "$TMP/run0" "$R" >/dev/null 2>&1; rc=$?
assert_eq "clean builtin run with --fail-on NONE exits 0" "$rc" "0"
assert_eq "tools.json marks skipped tools honestly" "$(jq -r '[.[] | select(.tool=="semgrep") | .status] | first' "$TMP/run0/tools.json")" "skipped"
printf 'APP_DEBUG=true\n' > "$R/.env.production"
( cd "$R" && git add -f .env.production && git -c user.name=t -c user.email=t@t commit -qm d ) >/dev/null 2>&1
"$S/security-check.sh" --only builtin --fail-on HIGH --report --output "$TMP/run1" "$R" >/dev/null 2>&1; rc=$?
assert_eq "HIGH finding makes the run exit 1" "$rc" "1"
assert "findings.json is a JSON array with ids" jq -e 'type=="array" and length>0 and (.[0].id|startswith("SBS-"))' "$TMP/run1/findings.json"
assert "report.md is generated" test -s "$TMP/run1/report.md"
assert "report states findings are unverified" grep -q 'unverified' "$TMP/run1/report.md"
assert "report states absence of findings is not proof" grep -q 'does \*\*not\*\* prove' "$TMP/run1/report.md"
assert "report lists coverage" grep -q '^## Coverage' "$TMP/run1/report.md"
assert "report names the author" grep -q 'IbrahimCodeur' "$TMP/run1/report.md"
"$S/security-check.sh" --only zap --zap-target https://example.com --output "$TMP/run2" "$R" >/dev/null 2>&1
assert_eq "ZAP refuses non-authorised remote host" "$(jq -r '.[] | select(.tool=="zap") | .status' "$TMP/run2/tools.json")" "refused"
assert "invalid option exits 2" bash -c "'$S/security-check.sh' --bogus >/dev/null 2>&1; [ \$? -eq 2 ]"
assert "invalid --fail-on exits 2" bash -c "'$S/security-check.sh' --fail-on PANIC --check-only . >/dev/null 2>&1; [ \$? -eq 2 ]"

if command -v semgrep >/dev/null 2>&1; then
  for fx in node-express-saas laravel-saas python-fastapi-saas; do
    R="$(mkrepo "$fx" "sg-$fx")"
    SBS_SEMGREP_CONFIGS="" "$S/security-check.sh" --only semgrep --fail-on CRITICAL --output "$TMP/sg-$fx" "$R" >/dev/null 2>&1; rc=$?
    assert_eq "semgrep finds CRITICAL issues in $fx" "$rc" "1"
  done
  ids="$(jq -r '[.[].rule | split(".") | last] | unique | join(" ")' "$TMP/sg-node-express-saas/findings.json")"
  for r in sbs-js-sqli-template-literal sbs-js-jwt-decode-for-auth sbs-js-stripe-webhook-unverified; do assert "semgrep reports $r" has "$ids" "$r"; done
  ids="$(jq -r '[.[].rule | split(".") | last] | unique | join(" ")' "$TMP/sg-laravel-saas/findings.json")"
  for r in sbs-php-sqli-string-building sbs-laravel-mass-assignment-all sbs-blade-unescaped-output; do assert "semgrep reports $r" has "$ids" "$r"; done
  assert "semgrep SARIF produced" jq -e '.runs[0].results | length > 0' "$TMP/sg-laravel-saas/raw/semgrep.sarif"
else
  skip "semgrep end-to-end tests" "semgrep not installed"
fi

echo "== check-headers.sh"
if command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  PORT=$(( (RANDOM % 20000) + 30000 ))
  mkdir -p "$TMP/www/admin" "$TMP/www/private" && echo ok > "$TMP/www/index.html"
  echo '<html><head><title>Admin</title></head><body>users</body></html>' > "$TMP/www/admin/index.html"
  echo '<html><head><meta name="robots" content="noindex, nofollow"></head><body>x</body></html>' > "$TMP/www/private/index.html"
  ( cd "$TMP/www" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 ) >/dev/null 2>&1 &
  SRV=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do curl -s "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && break; sleep 0.3; done
  "$S/check-headers.sh" "http://127.0.0.1:$PORT/" --json > "$TMP/h.json" 2>/dev/null; rc=$?
  "$S/check-headers.sh" "http://127.0.0.1:$PORT/" --json --admin-paths "/admin/ /private/ /missing" > "$TMP/ha.json" 2>/dev/null
  mkdir -p "$TMP/cfgproj/.saas-blind-security" && printf 'SBS_ADMIN_PATHS=/admin/\n' > "$TMP/cfgproj/.saas-blind-security/sbs.conf"
  ( cd "$TMP/cfgproj" && "$S/check-headers.sh" "http://127.0.0.1:$PORT/" --json > "$TMP/hc.json" 2>/dev/null )
  kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null
  assert_eq "missing headers make check-headers exit 1" "$rc" "1"
  assert_eq "CSP reported missing" "$(jq -r '.checks[] | select(.check=="Content-Security-Policy") | .result' "$TMP/h.json")" "FAIL"
  assert_eq "version disclosure detected" "$(jq -r '.checks[] | select(.check=="Version-disclosure") | .result' "$TMP/h.json")" "WARN"
  assert_eq "indexable admin page fails" "$(jq -r '.checks[] | select(.check=="Admin-noindex:/admin/") | "\(.result):\(.severity)"' "$TMP/ha.json")" "FAIL:MEDIUM"
  assert_eq "meta robots noindex passes" "$(jq -r '.checks[] | select(.check=="Admin-noindex:/private/") | .result' "$TMP/ha.json")" "PASS"
  assert_eq "missing admin path passes" "$(jq -r '.checks[] | select(.check=="Admin-noindex:/missing") | .result' "$TMP/ha.json")" "PASS"
  assert_eq "SBS_ADMIN_PATHS is read from the project sbs.conf" "$(jq -r '.checks[] | select(.check=="Admin-noindex:/admin/") | .result' "$TMP/hc.json")" "FAIL"
else skip "check-headers.sh" "python3 or curl missing"; fi

echo "== install.sh"
P="$TMP/project"; mkdir -p "$P" && cp -R "$FIX/node-express-saas/." "$P/"
printf '# My project rules\n' > "$P/CLAUDE.md"
"$S/install.sh" --dry-run "$P" >/dev/null 2>&1
assert "--dry-run installs nothing" test ! -e "$P/.saas-blind-security"
"$S/install.sh" "$P" >/dev/null 2>&1; rc=$?
assert_eq "install exits 0" "$rc" "0"
for f in .saas-blind-security/scripts/security-check.sh .saas-blind-security/config/semgrep/rules/javascript-saas.yaml \
         .saas-blind-security/sbs.conf .saas-blind-security/CLAUDE.security.md .github/workflows/codeql.yml \
         .github/workflows/zap-full-scan.yml .github/dependabot.yml .claude/skills/multi-tenant-security/SKILL.md; do
  assert "installed $f" test -e "$P/$f"
done
assert "framework CI workflow is not installed" test ! -e "$P/.github/workflows/ci.yml"
assert_eq "existing CLAUDE.md is preserved" "$(cat "$P/CLAUDE.md")" "# My project rules"
assert "self-test config is not installed" bash -c "! grep -q 'tests/fixtures' '$P/.saas-blind-security/sbs.conf'"
"$S/install.sh" "$P" >/dev/null 2>&1
assert_eq ".gitignore entry added once" "$(grep -c '^.sbs-results/$' "$P/.gitignore")" "1"
"$P/.saas-blind-security/scripts/security-check.sh" --check-only "$P" >/dev/null 2>&1; rc=$?
assert_eq "installed copy runs" "$rc" "0"
assert "installed workflows locate .saas-blind-security" grep -q '.saas-blind-security' "$P/.github/workflows/semgrep.yml"

echo "== Repository content"
for d in "$ROOT"/.claude/skills/*/; do
  n="$(basename "$d")"; f="$d/SKILL.md"
  assert "skill $n has SKILL.md" test -s "$f"
  assert_eq "skill $n frontmatter name" "$(sed -n '2,5p' "$f" | grep '^name:' | sed 's/^name:[[:space:]]*//')" "$n"
  assert "skill $n has a description" bash -c "sed -n '2,8p' '$f' | grep -q '^description: .\{40,\}'"
  for sec in '## Objectives' '## Steps' '## Security rules' '## Validation criteria'; do
    assert "skill $n has section '$sec'" grep -q "^$sec" "$f"
  done
done
assert_eq "12 required skills present" "$(find "$ROOT/.claude/skills" -name SKILL.md | wc -l | tr -d ' ')" "12"
for d in "$ROOT"/fabric/patterns/*/; do
  n="$(basename "$d")"
  assert "fabric pattern $n has system.md" test -s "$d/system.md"
  for sec in '# IDENTITY and PURPOSE' '# STEPS' '# OUTPUT INSTRUCTIONS' '# INPUT'; do
    assert "fabric pattern $n has '$sec'" grep -q "^$sec" "$d/system.md"
  done
done
unpinned="$(grep -hE '^\s*-?\s*uses:\s' "$ROOT"/.github/workflows/*.yml | grep -vE '@[0-9a-f]{40}' || true)"
assert_eq "every workflow action is pinned to a commit SHA" "$unpinned" ""
assert "every workflow declares top-level permissions" bash -c "for f in '$ROOT'/.github/workflows/*.yml; do grep -q '^permissions:' \"\$f\" || exit 1; done"
missing=""
while IFS= read -r md; do
  dir="$(dirname "$md")"
  # shellcheck disable=SC2013 # links never contain spaces (the regex excludes them)
  for link in $(grep -oE '\]\([^)#[:space:]]+' "$md" | sed 's/^](//' | grep -vE '^(https?:|mailto:)'); do
    [ -e "$dir/$link" ] || missing="$missing $md->$link"
  done
done < <(find "$ROOT" -name '*.md' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/tests/fixtures/*')
assert_eq "all relative Markdown links resolve" "$missing" ""
assert "no AI tool is credited as author" bash -c "! grep -rniE '(co-?authored|author(ed)? by|created by|written by|maintained by)[^\\n]{0,40}(claude|anthropic|chatgpt|openai|copilot|gemini)' '$ROOT' --include='*.md' --include='*.sh' --include='*.yml' --include='LICENSE'"

echo
echo "Result: $PASS passed, $FAIL failed, $SKIP skipped"
[ "$FAIL" -eq 0 ]
