#!/usr/bin/env bash
# saas-blind-security - enable GitHub native security features on a repository you administer.
# Created and maintained by IbrahimCodeur - https://github.com/IbrahimCodeur
# SPDX-License-Identifier: MIT
#
# Usage: configure-github-security.sh OWNER/REPO [--dry-run] [--branch main] [--required-checks "a,b"] [--reviews N]
#
# Uses the GitHub CLI (gh) with YOUR credentials. Enables:
#   - Dependabot alerts and Dependabot security updates
#   - Secret scanning and push protection (public repos, or GitHub Advanced Security / Secret Protection)
#   - A branch ruleset on the default branch: no deletion, no force-push, pull request required,
#     optional required status checks
# CodeQL is configured through .github/workflows/codeql.yml ("advanced setup"); do not also enable
# CodeQL "default setup", the two conflict.

set -uo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
REPO=""; DRY=0; BRANCH=""; CHECKS=""; REVIEWS="${SBS_REQUIRED_REVIEWS:-1}"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --branch) BRANCH="${2:-}"; shift ;;
    --required-checks) CHECKS="${2:-}"; shift ;;
    --reviews) REVIEWS="${2:-1}"; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) REPO="$1" ;;
  esac
  shift
done
printf '%s' "$REPO" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' || die "Usage: configure-github-security.sh OWNER/REPO [--dry-run]"
have gh || die "GitHub CLI (gh) is required: https://cli.github.com"
have jq || die "jq is required"

api() { # method path [json-body]
  if [ "$DRY" -eq 1 ]; then echo "  would: gh api -X $1 $2${3:+ with body $3}"; return 0; fi
  if [ -n "${3:-}" ]; then printf '%s' "$3" | gh api -X "$1" "$2" -H "Accept: application/vnd.github+json" --input - >/dev/null
  else gh api -X "$1" "$2" -H "Accept: application/vnd.github+json" >/dev/null; fi
}
step() { # description, command...
  local d="$1"; shift
  if "$@"; then log_ok "$d"; else log_warn "$d — failed (permissions or plan may not allow it)"; fi
}

gh auth status >/dev/null 2>&1 || die "gh is not authenticated: run 'gh auth login'"
INFO="$(gh api "repos/$REPO")" || die "Cannot read $REPO (does it exist? do you have admin rights?)"
[ "$(printf '%s' "$INFO" | jq -r '.permissions.admin')" = "true" ] || die "You need admin rights on $REPO"
BRANCH="${BRANCH:-$(printf '%s' "$INFO" | jq -r '.default_branch')}"
VIS="$(printf '%s' "$INFO" | jq -r '.visibility')"
log_info "$REPO (visibility: $VIS, default branch: $BRANCH)${DRY:+}"; [ "$DRY" -eq 1 ] && log_info "dry run: nothing will change"

step "Dependabot alerts" api PUT "repos/$REPO/vulnerability-alerts"
step "Dependabot security updates" api PUT "repos/$REPO/automated-security-fixes"
step "Secret scanning + push protection" api PATCH "repos/$REPO" \
  '{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}'

RULES="$(jq -nc --argjson reviews "$REVIEWS" --arg checks "$CHECKS" '
  [ {type:"deletion"}, {type:"non_fast_forward"},
    {type:"pull_request", parameters:{required_approving_review_count:$reviews, dismiss_stale_reviews_on_push:true,
      require_code_owner_review:false, require_last_push_approval:false, required_review_thread_resolution:true}} ]
  + (if $checks == "" then [] else [{type:"required_status_checks", parameters:{strict_required_status_checks_policy:true,
      required_status_checks: ($checks | split(",") | map(select(length>0) | {context: .}))}}] end)')"
BODY="$(jq -nc --arg branch "$BRANCH" --argjson rules "$RULES" '{
  name:"saas-blind-security: protect default branch", target:"branch", enforcement:"active",
  conditions:{ref_name:{include:["refs/heads/" + $branch], exclude:[]}}, rules:$rules}')"
EXISTING=""
[ "$DRY" -eq 0 ] && EXISTING="$(gh api "repos/$REPO/rulesets" 2>/dev/null | jq -r '.[] | select(.name=="saas-blind-security: protect default branch") | .id' | head -n1)"
if [ -n "$EXISTING" ]; then step "Branch ruleset (updated #$EXISTING)" api PUT "repos/$REPO/rulesets/$EXISTING" "$BODY"
else step "Branch ruleset on $BRANCH" api POST "repos/$REPO/rulesets" "$BODY"; fi

echo
log_info "Verify in the browser: https://github.com/$REPO/settings/security_analysis and /settings/rules"
log_info "Repository owners with a sole maintainer: set --reviews 0, or you cannot merge your own PRs."
