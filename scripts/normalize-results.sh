#!/usr/bin/env bash
# saas-blind-security - convert scanner output into the common finding format.
# Created and maintained by IbrahimCodeur - https://github.com/IbrahimCodeur
# SPDX-License-Identifier: MIT
#
# Usage: normalize-results.sh <semgrep|snyk-test|sarif|npm-audit|composer-audit|zap|builtin> <file> [tool-label]
#
# Output: a JSON array on stdout. Every finding has the fields
#   tool, rule, severity (CRITICAL|HIGH|MEDIUM|LOW|INFO), title, file, line, detail, status
# "status" is always "unverified": a scanner result is a lead, not a confirmed vulnerability.

set -uo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
have jq || die "jq is required"

KIND="${1:-}"; FILE="${2:-}"; LABEL="${3:-$KIND}"
[ -n "$KIND" ] && [ -n "$FILE" ] || die "Usage: normalize-results.sh <kind> <file> [label]"
[ -s "$FILE" ] || { echo '[]'; exit 0; }
jq empty "$FILE" 2>/dev/null || die "Not valid JSON: $FILE"

case "$KIND" in
  semgrep)
    jq --arg tool "$LABEL" '[.results[]? | {
        tool: $tool,
        rule: (.check_id | (capture("(?<id>sbs-[a-z0-9-]+)$").id // .)),
        severity: ((.extra.metadata["sbs-severity"] // .extra.severity // "INFO") | ascii_upcase
                   | if . == "ERROR" then "HIGH" elif . == "WARNING" then "MEDIUM"
                     elif . == "INFO" then "LOW" else . end),
        title: (.extra.message | split("\n")[0] | split(". ")[0]),
        file: .path,
        line: .start.line,
        detail: (((.extra.metadata.cwe // []) | if type=="array" then join(", ") else tostring end) + " — " + .extra.message),
        status: "unverified" }] | unique_by(.rule, .file, .line)' "$FILE" ;;
  snyk-test)
    jq --arg tool "$LABEL" '[ (if type=="array" then .[] else . end)
        | . as $p | .vulnerabilities[]? | {
        tool: $tool,
        rule: .id,
        severity: (.severity | ascii_upcase),
        title: "\(.title) in \(.packageName)@\(.version)",
        file: ($p.displayTargetFile // $p.targetFile // "dependency manifest"),
        line: null,
        detail: ("Introduced through: " + ((.from // []) | join(" > ")) + (if .isUpgradable then " (upgradable)" else "" end)),
        status: "unverified" }] | unique_by(.rule, .file, .title)' "$FILE" ;;
  sarif)
    jq --arg tool "$LABEL" '[.runs[]? | . as $run | .results[]? | . as $r | {
        tool: $tool,
        rule: .ruleId,
        severity: (
          ( ($run.tool.driver.rules // []) | map(select(.id == $r.ruleId)) | .[0].properties["security-severity"] // null ) as $ss
          | if $ss != null then ($ss | tonumber
                | if . >= 9 then "CRITICAL" elif . >= 7 then "HIGH" elif . >= 4 then "MEDIUM" elif . > 0 then "LOW" else "INFO" end)
            else (.level // "warning" | if . == "error" then "HIGH" elif . == "warning" then "MEDIUM" elif . == "note" then "LOW" else "INFO" end)
            end),
        title: (.message.text | split("\n")[0]),
        file: (.locations[0].physicalLocation.artifactLocation.uri // null),
        line: (.locations[0].physicalLocation.region.startLine // null),
        detail: "",
        status: "unverified" }]' "$FILE" ;;
  npm-audit)
    jq --arg tool "$LABEL" '[.vulnerabilities // {} | to_entries[] | .value | . as $v | {
        tool: $tool,
        rule: ([.via[]? | objects | (.url // .source // empty) | tostring] | first // ("npm:" + $v.name)),
        severity: (.severity | ascii_upcase | if . == "MODERATE" then "MEDIUM" else . end),
        title: ("Vulnerable dependency " + .name + " " + (.range // "")),
        file: "package-lock.json",
        line: null,
        detail: ([.via[]? | objects | .title] | unique | join("; ")),
        status: "unverified" }]' "$FILE" ;;
  composer-audit)
    jq --arg tool "$LABEL" '[.advisories // {} | to_entries[] | .key as $pkg | .value
        | (if type=="object" then [.[]] else . end)[] | {
        tool: $tool,
        rule: (.cve // .advisoryId // "composer-advisory"),
        severity: ((.severity // "medium") | ascii_upcase | if . == "MODERATE" then "MEDIUM" else . end),
        title: ("\($pkg): " + (.title // "security advisory")),
        file: "composer.lock",
        line: null,
        detail: (.link // ""),
        status: "unverified" }]' "$FILE" ;;
  zap)
    jq --arg tool "$LABEL" '[.site[]? | . as $s | .alerts[]? | {
        tool: $tool,
        rule: ("zap-" + (.pluginid // "0")),
        severity: (.riskcode | tostring | if . == "3" then "HIGH" elif . == "2" then "MEDIUM" elif . == "1" then "LOW" else "INFO" end),
        title: (.alert // .name),
        file: ((.instances[0].uri // $s["@name"]) // null),
        line: null,
        detail: ("confidence=" + (.confidence // "?") + "; instances=" + ((.instances // []) | length | tostring)),
        status: "unverified" }]' "$FILE" ;;
  builtin)
    jq --arg tool "$LABEL" '[.[] | . + {tool: $tool, status: "unverified"}]' "$FILE" ;;
  *) die "Unknown kind: $KIND" ;;
esac
