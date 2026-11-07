#!/usr/bin/env bash
# saas-blind-security - report which tools and credentials are available (read-only).
# Created and maintained by IbrahimCodeur - https://github.com/IbrahimCodeur
# SPDX-License-Identifier: MIT
#
# Usage: validate-environment.sh [--strict]
#   --strict  exit 1 when a required tool (bash>=3.2, git, jq) is missing.
# Secret values are never printed: only "set" / "not set".

set -uo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
STRICT=0; [ "${1:-}" = "--strict" ] && STRICT=1
MISSING_REQUIRED=0

row() { printf '  %-14s %-12s %s\n' "$1" "$2" "$3"; }
check() { # name required(0/1) install-hint version-cmd...
  local name="$1" req="$2" hint="$3"; shift 3
  if have "$name"; then row "$name" "found" "$("$@" 2>/dev/null | head -n1)"
  elif [ "$req" -eq 1 ]; then row "$name" "MISSING" "required — $hint"; MISSING_REQUIRED=1
  else row "$name" "not found" "optional — $hint"; fi
}

echo "saas-blind-security v$SBS_VERSION — environment check"
echo
echo "Required:"
row bash "found" "$BASH_VERSION"
check git 1 "https://git-scm.com/downloads" git --version
check jq 1 "https://jqlang.github.io/jq/download/" jq --version
echo
echo "Scanners (optional, each one adds coverage):"
check semgrep 0 "pipx install semgrep  (https://semgrep.dev/docs/getting-started/)" semgrep --version
check snyk 0 "npm install -g snyk  (https://docs.snyk.io/snyk-cli/install-or-update-the-snyk-cli)" snyk --version
check codeql 0 "https://docs.github.com/code-security/codeql-cli — or rely on the codeql.yml workflow" codeql version --format=terse
check docker 0 "needed for local OWASP ZAP scans (https://docs.docker.com/get-docker/)" docker --version
check npm 0 "enables npm audit for Node.js projects" npm --version
check composer 0 "enables composer audit for PHP projects" composer --version
check fabric 0 "https://github.com/danielmiessler/Fabric — AI analysis of reports" fabric --version
check gh 0 "https://cli.github.com — needed by configure-github-security.sh" gh --version
check curl 0 "needed by check-headers.sh" curl --version
echo
echo "Credentials (values are never displayed):"
if [ -n "${SNYK_TOKEN:-}" ]; then row SNYK_TOKEN "set" "environment variable"
elif have snyk && [ -n "$(snyk config get api 2>/dev/null || true)" ]; then row SNYK_TOKEN "set" "via snyk auth"
else row SNYK_TOKEN "not set" "Snyk checks will be skipped (other checks still run)"; fi
if [ -n "${SEMGREP_APP_TOKEN:-}" ]; then row SEMGREP_APP_TOKEN "set" "optional, Semgrep AppSec Platform"
else row SEMGREP_APP_TOKEN "not set" "optional — not needed for local rules"; fi
echo
if [ "$MISSING_REQUIRED" -eq 1 ]; then log_error "Required tools are missing."; [ "$STRICT" -eq 1 ] && exit 1; fi
log_info "Only installed tools run. Missing tools mean missing coverage, never a passed check."
exit 0
