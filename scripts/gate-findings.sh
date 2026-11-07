#!/usr/bin/env bash
# saas-blind-security - fail when normalised findings reach a severity threshold.
# Created and maintained by IbrahimCodeur - https://github.com/IbrahimCodeur
# SPDX-License-Identifier: MIT
#
# Usage: gate-findings.sh FINDINGS_JSON [LEVEL]
# Exit 0 below threshold, 1 at/above threshold. LEVEL defaults to $SBS_FAIL_ON_SEVERITY or HIGH; NONE never fails.

set -uo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
F="${1:-}"; LEVEL="$(printf '%s' "${2:-${SBS_FAIL_ON_SEVERITY:-HIGH}}" | tr '[:lower:]' '[:upper:]')"
[ -f "$F" ] || die "Usage: gate-findings.sh FINDINGS_JSON [LEVEL]"
R="$(severity_rank "$LEVEL")"; [ "$R" -gt 0 ] || die "Invalid level: $LEVEL"
N="$(jq --argjson r "$R" '[.[] | select(({"CRITICAL":5,"HIGH":4,"MEDIUM":3,"LOW":2,"INFO":1}[.severity] // 0) >= $r)] | length' "$F")"
for s in CRITICAL HIGH MEDIUM LOW INFO; do printf '%s=%s ' "$s" "$(jq --arg s "$s" '[.[]|select(.severity==$s)]|length' "$F")"; done; echo
if [ "$N" -gt 0 ]; then log_error "$N finding(s) at or above $LEVEL"; exit 1; fi
log_ok "No finding at or above $LEVEL"
