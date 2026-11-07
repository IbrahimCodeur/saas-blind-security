#!/usr/bin/env bash
# saas-blind-security - main entry point.
# Created and maintained by IbrahimCodeur - https://github.com/IbrahimCodeur
# SPDX-License-Identifier: MIT
#
# Usage: security-check.sh [options] [PROJECT_DIR]
#
#   (no mode)          Detect the stack, run every available compatible scanner, print a summary.
#   --report           Same, and write a Markdown report (report.md) next to the raw results.
#   --check-only       Preflight only: detect the stack and list which checks CAN run. Runs no scanner, writes nothing.
#
#   --fail-on LEVEL    Exit 1 when a finding of LEVEL or above exists (CRITICAL|HIGH|MEDIUM|LOW|INFO|NONE). Default: HIGH
#   --output DIR       Where to store results. Default: PROJECT_DIR/.sbs-results/<timestamp>
#   --skip LIST        Comma separated tools to skip (builtin,semgrep,snyk,npm-audit,composer-audit,codeql,zap)
#   --only LIST        Comma separated tools to run (same names)
#   --zap-target URL   Run an OWASP ZAP *baseline* (passive) scan against URL. Local URLs only, unless the
#                      host is listed in SBS_ZAP_ALLOWED_HOSTS (you must be authorised to test it).
#   --offline          Do not use network-only rule sources (Semgrep registry, Snyk).
#   -h, --help         Show this help.
#
# Exit codes: 0 = no finding at/above threshold, 1 = threshold exceeded, 2 = usage error or a scanner failed.
# A clean run does NOT prove the application is secure: it only means these tools found nothing.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
SBS_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="scan"; TARGET="."; FAIL_ON=""; OUT_DIR=""; SKIP=""; ONLY=""; ZAP_TARGET=""; OFFLINE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --report) MODE="report" ;;
    --check-only) MODE="check" ;;
    --fail-on) FAIL_ON="${2:-}"; shift ;;
    --output) OUT_DIR="${2:-}"; shift ;;
    --skip) SKIP="${2:-}"; shift ;;
    --only) ONLY="${2:-}"; shift ;;
    --zap-target) ZAP_TARGET="${2:-}"; shift ;;
    --offline) OFFLINE=1 ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) log_error "Unknown option: $1"; exit 2 ;;
    *) TARGET="$1" ;;
  esac
  shift
done

have jq || die "jq is required (https://jqlang.github.io/jq/)."
[ -d "$TARGET" ] || die "Not a directory: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"
sbs_load_config "$TARGET/.saas-blind-security/sbs.conf"
sbs_load_config "$TARGET/config/sbs.conf"
sbs_load_config "$SBS_HOME/config/sbs.conf"

FAIL_ON="$(printf '%s' "${FAIL_ON:-${SBS_FAIL_ON_SEVERITY:-HIGH}}" | tr '[:lower:]' '[:upper:]')"
[ "$(severity_rank "$FAIL_ON")" -gt 0 ] || die "Invalid --fail-on level: $FAIL_ON"
ZAP_TARGET="${ZAP_TARGET:-${SBS_ZAP_TARGET:-}}"

wanted() { # tool -> 0 if it should run
  local t="$1"
  if [ -n "$ONLY" ]; then case ",$ONLY," in *",$t,"*) ;; *) return 1 ;; esac; fi
  case ",$SKIP,${SBS_SKIP_TOOLS:-}," in *",$t,"*) return 1 ;; esac
  return 0
}

exclude_args() { # semgrep --exclude flags
  local ex
  printf '%s\n' "--exclude=.sbs-results" "--exclude=.saas-blind-security"
  for ex in ${SBS_EXCLUDE_PATHS:-}; do printf '%s\n' "--exclude=$ex"; done
}

snyk_authenticated() {
  [ -n "${SNYK_TOKEN:-}" ] && return 0
  local v; v="$(snyk config get api 2>/dev/null || true)"
  [ -n "$v" ]
}

zap_target_allowed() {
  local url="$1" host allowed
  is_local_url "$url" && return 0
  host="$(url_host "$url")"
  for allowed in ${SBS_ZAP_ALLOWED_HOSTS:-}; do [ "$host" = "$allowed" ] && return 0; done
  return 1
}

# ---------------------------------------------------------------- plan
plan_tool() { # tool -> prints "available|reason"
  case "$1" in
    builtin) echo "available|dependency-free baseline heuristics" ;;
    semgrep) if have semgrep; then echo "available|$(semgrep --version 2>/dev/null | head -n1)"; else echo "missing|semgrep not installed (pipx install semgrep)"; fi ;;
    snyk)
      if [ "$OFFLINE" -eq 1 ]; then echo "skipped|--offline"
      elif ! have snyk; then echo "missing|snyk CLI not installed (npm install -g snyk)"
      elif ! snyk_authenticated; then echo "skipped|no SNYK_TOKEN and snyk CLI not authenticated"
      else echo "available|snyk CLI authenticated"; fi ;;
    npm-audit)
      if [ ! -f "$TARGET/package-lock.json" ] && [ ! -f "$TARGET/npm-shrinkwrap.json" ]; then echo "n/a|no package-lock.json at project root"
      elif [ "$OFFLINE" -eq 1 ]; then echo "skipped|--offline"
      elif ! have npm; then echo "missing|npm not installed"
      else echo "available|npm $(npm --version 2>/dev/null)"; fi ;;
    composer-audit)
      if [ ! -f "$TARGET/composer.lock" ]; then echo "n/a|no composer.lock at project root"
      elif [ "$OFFLINE" -eq 1 ]; then echo "skipped|--offline"
      elif ! have composer; then echo "missing|composer not installed"
      else echo "available|$(composer --version 2>/dev/null | head -n1)"; fi ;;
    codeql)
      local langs; langs="$("$SCRIPT_DIR/detect-stack.sh" --codeql-languages "$TARGET" 2>/dev/null | jq -r '[.[] | select(. != "actions")] | join(",")')"
      if [ -z "$langs" ]; then echo "n/a|no language for the local CodeQL CLI (PHP is unsupported; workflows are analysed by codeql.yml)"
      elif ! have codeql; then echo "missing|codeql CLI not installed (CodeQL runs in GitHub Actions: codeql.yml)"
      else echo "available|languages: $langs"; fi ;;
    zap)
      if [ -z "$ZAP_TARGET" ]; then echo "n/a|no --zap-target given"
      elif ! zap_target_allowed "$ZAP_TARGET"; then echo "refused|$(url_host "$ZAP_TARGET") is not local and not in SBS_ZAP_ALLOWED_HOSTS"
      elif ! have docker; then echo "missing|docker not installed (ZAP runs in ghcr.io/zaproxy/zaproxy:stable)"
      else echo "available|baseline (passive) scan of $ZAP_TARGET"; fi ;;
  esac
}

TOOLS="builtin semgrep snyk npm-audit composer-audit codeql zap"

echo "saas-blind-security v$SBS_VERSION" >&2
"$SCRIPT_DIR/detect-stack.sh" "$TARGET" >&2 || true
echo >&2
echo "Check plan (fail-on: $FAIL_ON):" >&2
RUNNABLE=""
for t in $TOOLS; do
  if ! wanted "$t"; then printf '  %-15s %-10s %s\n' "$t" "skipped" "excluded by --skip/--only/SBS_SKIP_TOOLS" >&2; continue; fi
  p="$(plan_tool "$t")"; st="${p%%|*}"; why="${p#*|}"
  printf '  %-15s %-10s %s\n' "$t" "$st" "$why" >&2
  [ "$st" = "available" ] && RUNNABLE="$RUNNABLE $t"
done

if [ "$MODE" = "check" ]; then
  echo >&2
  log_info "--check-only: no scanner was executed and nothing was written."
  exit 0
fi

# ---------------------------------------------------------------- run
if [ -z "$OUT_DIR" ]; then OUT_DIR="$TARGET/.sbs-results/$(date -u +%Y%m%dT%H%M%SZ)"; fi
mkdir -p "$OUT_DIR/raw" || die "Cannot create $OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
STATUS="$OUT_DIR/tools.jsonl"; : > "$STATUS"
FINDINGS_PARTS="$OUT_DIR/raw/.parts"; mkdir -p "$FINDINGS_PARTS"
SCANNER_ERROR=0

record() { # tool status detail [findings-file]
  local n=null
  [ -n "${4:-}" ] && [ -f "$4" ] && n="$(jq length "$4")"
  jq -nc --arg tool "$1" --arg status "$2" --arg detail "$3" --argjson n "$n" \
    '{tool:$tool, status:$status, detail:$detail, findings:$n}' >> "$STATUS"
  case "$2" in
    ran) log_ok "$1: $3${4:+ ($n findings)}" ;;
    error) log_error "$1: $3"; SCANNER_ERROR=1 ;;
    *) log_skip "$1: $3" ;;
  esac
}

for t in $TOOLS; do
  case " $RUNNABLE " in *" $t "*) ;; *)
    if wanted "$t"; then p="$(plan_tool "$t")"; record "$t" "${p%%|*}" "${p#*|}"; else record "$t" skipped "excluded"; fi
    continue ;;
  esac
  log_info "running $t ..."
  case "$t" in
    builtin)
      if "$SCRIPT_DIR/builtin-checks.sh" "$TARGET" > "$OUT_DIR/raw/builtin.json" 2> "$OUT_DIR/raw/builtin.log"; then
        "$SCRIPT_DIR/normalize-results.sh" builtin "$OUT_DIR/raw/builtin.json" builtin > "$FINDINGS_PARTS/builtin.json"
        record builtin ran "baseline heuristics" "$FINDINGS_PARTS/builtin.json"
      else record builtin error "see raw/builtin.log"; fi ;;

    semgrep)
      args=(scan --metrics=off --config "$SBS_HOME/config/semgrep/rules")
      registry=""
      if [ "$OFFLINE" -eq 0 ]; then
        for c in ${SBS_SEMGREP_CONFIGS-p/owasp-top-ten}; do args+=(--config "$c"); registry="$registry $c"; done
      fi
      while IFS= read -r e; do args+=("$e"); done < <(exclude_args)
      args+=(--json-output "$OUT_DIR/raw/semgrep.json" --sarif-output "$OUT_DIR/raw/semgrep.sarif" --quiet .)
      if ( cd "$TARGET" && semgrep "${args[@]}" ) > /dev/null 2> "$OUT_DIR/raw/semgrep.log"; then note="local SaaS rules${registry:+ +$registry}"
      elif [ -n "$registry" ]; then
        log_warn "semgrep failed with registry rules ($registry), retrying with local rules only"
        args=(scan --metrics=off --config "$SBS_HOME/config/semgrep/rules")
        while IFS= read -r e; do args+=("$e"); done < <(exclude_args)
        args+=(--json-output "$OUT_DIR/raw/semgrep.json" --sarif-output "$OUT_DIR/raw/semgrep.sarif" --quiet .)
        if ( cd "$TARGET" && semgrep "${args[@]}" ) > /dev/null 2>> "$OUT_DIR/raw/semgrep.log"; then note="local SaaS rules only (registry unavailable)"; else note=""; fi
      else note=""; fi
      if [ -n "$note" ]; then
        "$SCRIPT_DIR/normalize-results.sh" semgrep "$OUT_DIR/raw/semgrep.json" semgrep > "$FINDINGS_PARTS/semgrep.json"
        record semgrep ran "$note" "$FINDINGS_PARTS/semgrep.json"
      else record semgrep error "see raw/semgrep.log"; fi ;;

    snyk)
      ( cd "$TARGET" && snyk test --all-projects --json-file-output="$OUT_DIR/raw/snyk-test.json" --sarif-file-output="$OUT_DIR/raw/snyk-test.sarif" > /dev/null 2> "$OUT_DIR/raw/snyk-test.log" ); rc=$?
      # snyk exit codes: 0 no issues, 1 issues found, 2 error, 3 no supported projects
      case "$rc" in
        0|1) "$SCRIPT_DIR/normalize-results.sh" snyk-test "$OUT_DIR/raw/snyk-test.json" snyk-open-source > "$FINDINGS_PARTS/snyk-test.json"
             record snyk-open-source ran "snyk test --all-projects" "$FINDINGS_PARTS/snyk-test.json" ;;
        3) record snyk-open-source n/a "no supported manifest found by Snyk" ;;
        *) record snyk-open-source error "exit $rc, see raw/snyk-test.log" ;;
      esac
      ( cd "$TARGET" && snyk code test --sarif-file-output="$OUT_DIR/raw/snyk-code.sarif" > /dev/null 2> "$OUT_DIR/raw/snyk-code.log" ); rc=$?
      case "$rc" in
        0|1) "$SCRIPT_DIR/normalize-results.sh" sarif "$OUT_DIR/raw/snyk-code.sarif" snyk-code > "$FINDINGS_PARTS/snyk-code.json"
             record snyk-code ran "snyk code test" "$FINDINGS_PARTS/snyk-code.json" ;;
        3) record snyk-code n/a "no supported source files for Snyk Code" ;;
        *) record snyk-code skipped "exit $rc (Snyk Code may not be enabled for this organisation), see raw/snyk-code.log" ;;
      esac
      if ls "$TARGET"/*.tf "$TARGET"/Dockerfile "$TARGET"/docker-compose*.yml "$TARGET"/k8s "$TARGET"/helm >/dev/null 2>&1; then
        ( cd "$TARGET" && snyk iac test --sarif-file-output="$OUT_DIR/raw/snyk-iac.sarif" > /dev/null 2> "$OUT_DIR/raw/snyk-iac.log" ); rc=$?
        case "$rc" in
          0|1) "$SCRIPT_DIR/normalize-results.sh" sarif "$OUT_DIR/raw/snyk-iac.sarif" snyk-iac > "$FINDINGS_PARTS/snyk-iac.json"
               record snyk-iac ran "snyk iac test" "$FINDINGS_PARTS/snyk-iac.json" ;;
          3) record snyk-iac n/a "no IaC files supported by Snyk" ;;
          *) record snyk-iac skipped "exit $rc, see raw/snyk-iac.log" ;;
        esac
      fi ;;

    npm-audit)
      ( cd "$TARGET" && npm audit --json > "$OUT_DIR/raw/npm-audit.json" 2> "$OUT_DIR/raw/npm-audit.log" ); rc=$?
      if jq -e '.vulnerabilities' "$OUT_DIR/raw/npm-audit.json" >/dev/null 2>&1; then
        "$SCRIPT_DIR/normalize-results.sh" npm-audit "$OUT_DIR/raw/npm-audit.json" npm-audit > "$FINDINGS_PARTS/npm-audit.json"
        record npm-audit ran "npm audit (exit $rc)" "$FINDINGS_PARTS/npm-audit.json"
      else record npm-audit error "exit $rc, see raw/npm-audit.log"; fi ;;

    composer-audit)
      ( cd "$TARGET" && composer audit --format=json --no-interaction > "$OUT_DIR/raw/composer-audit.json" 2> "$OUT_DIR/raw/composer-audit.log" ); rc=$?
      if jq -e '.advisories' "$OUT_DIR/raw/composer-audit.json" >/dev/null 2>&1; then
        "$SCRIPT_DIR/normalize-results.sh" composer-audit "$OUT_DIR/raw/composer-audit.json" composer-audit > "$FINDINGS_PARTS/composer-audit.json"
        record composer-audit ran "composer audit (exit $rc)" "$FINDINGS_PARTS/composer-audit.json"
      else record composer-audit error "exit $rc, see raw/composer-audit.log"; fi ;;

    codeql)
      langs="$("$SCRIPT_DIR/detect-stack.sh" --codeql-languages "$TARGET" | jq -r '.[] | select(. != "actions")')"
      for lang in $langs; do
        cl="$lang"; [ "$lang" = "javascript-typescript" ] && cl="javascript"
        db="$OUT_DIR/raw/codeql-db-$cl"
        if codeql database create "$db" --language="$cl" --source-root="$TARGET" --overwrite > "$OUT_DIR/raw/codeql-$cl.log" 2>&1 \
          && codeql database analyze "$db" "codeql/$cl-queries:codeql-suites/$cl-security-extended.qls" --download \
               --format=sarif-latest --output="$OUT_DIR/raw/codeql-$cl.sarif" >> "$OUT_DIR/raw/codeql-$cl.log" 2>&1; then
          "$SCRIPT_DIR/normalize-results.sh" sarif "$OUT_DIR/raw/codeql-$cl.sarif" "codeql-$cl" > "$FINDINGS_PARTS/codeql-$cl.json"
          record "codeql-$cl" ran "security-extended suite" "$FINDINGS_PARTS/codeql-$cl.json"
        else record "codeql-$cl" error "see raw/codeql-$cl.log"; fi
        rm -rf "$db"
      done ;;

    zap)
      chmod 777 "$OUT_DIR/raw" 2>/dev/null || true
      docker run --rm -v "$OUT_DIR/raw:/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:stable \
        zap-baseline.py -t "$ZAP_TARGET" -J zap.json -r zap.html -I > "$OUT_DIR/raw/zap.log" 2>&1; rc=$?
      if [ -s "$OUT_DIR/raw/zap.json" ]; then
        "$SCRIPT_DIR/normalize-results.sh" zap "$OUT_DIR/raw/zap.json" zap-baseline > "$FINDINGS_PARTS/zap.json"
        record zap-baseline ran "passive baseline of $ZAP_TARGET (exit $rc)" "$FINDINGS_PARTS/zap.json"
      else record zap-baseline error "exit $rc, see raw/zap.log"; fi ;;
  esac
done

# ---------------------------------------------------------------- merge and gate
jq -s 'add // [] | sort_by(-( {"CRITICAL":5,"HIGH":4,"MEDIUM":3,"LOW":2,"INFO":1}[.severity] // 0 ), .tool, .file)
       | to_entries | map(.value + {id: ("SBS-" + ((.key + 1) | tostring | if length < 3 then ("00" + .)[-3:] else . end))})' \
  "$FINDINGS_PARTS"/*.json 2>/dev/null > "$OUT_DIR/findings.json" || echo '[]' > "$OUT_DIR/findings.json"
jq -s '.' "$STATUS" > "$OUT_DIR/tools.json"; rm -f "$STATUS"; rm -rf "$FINDINGS_PARTS"

THRESHOLD_RANK="$(severity_rank "$FAIL_ON")"
BLOCKING="$(jq --argjson r "$THRESHOLD_RANK" '[.[] | select(({"CRITICAL":5,"HIGH":4,"MEDIUM":3,"LOW":2,"INFO":1}[.severity] // 0) >= $r)] | length' "$OUT_DIR/findings.json")"

echo >&2
echo "Findings by severity:" >&2
for s in CRITICAL HIGH MEDIUM LOW INFO; do
  printf '  %-9s %s\n' "$s" "$(jq --arg s "$s" '[.[] | select(.severity==$s)] | length' "$OUT_DIR/findings.json")" >&2
done
echo "Results: $OUT_DIR" >&2

if [ "$MODE" = "report" ]; then
  "$SCRIPT_DIR/generate-report.sh" "$OUT_DIR" --fail-on "$FAIL_ON" --project "$TARGET" > "$OUT_DIR/report.md" \
    && log_ok "Report: $OUT_DIR/report.md" || log_error "Report generation failed"
fi

NOT_RUN="$(jq -r '[.[] | select(.status != "ran") | .tool] | join(", ")' "$OUT_DIR/tools.json")"
[ -n "$NOT_RUN" ] && log_warn "Not executed: $NOT_RUN. Their checks are NOT covered by this run."
log_warn "All findings are 'unverified' until a human or agent confirms them. No finding does not mean secure."

if [ "$BLOCKING" -gt 0 ]; then log_error "$BLOCKING finding(s) at or above $FAIL_ON."; exit 1; fi
if [ "$SCANNER_ERROR" -ne 0 ]; then log_error "At least one scanner failed; results are incomplete."; exit 2; fi
log_ok "No finding at or above $FAIL_ON."
exit 0
