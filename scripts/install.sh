#!/usr/bin/env bash
# saas-blind-security - install the framework into an existing project.
# Created and maintained by IbrahimCodeur - https://github.com/IbrahimCodeur
# SPDX-License-Identifier: MIT
#
# Usage: install.sh [--dry-run] [--force] [--no-workflows] [--no-skills] TARGET_PROJECT_DIR
#
# Copies:
#   scripts/, config/, fabric/, templates/  -> TARGET/.saas-blind-security/
#   .github/workflows/*.yml (security ones) -> TARGET/.github/workflows/
#   .claude/skills/*                        -> TARGET/.claude/skills/
#   CLAUDE.md                               -> TARGET/CLAUDE.md, or TARGET/.saas-blind-security/CLAUDE.security.md
#                                              when the project already has a CLAUDE.md (an import line is suggested)
#   generated .github/dependabot.yml        -> only if the project has none
# Existing files are never overwritten unless --force is given.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
SRC="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY=0; FORCE=0; WORKFLOWS=1; SKILLS=1; TARGET=""
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;; --force) FORCE=1 ;; --no-workflows) WORKFLOWS=0 ;; --no-skills) SKILLS=0 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    -*) die "Unknown option: $a" ;;
    *) TARGET="$a" ;;
  esac
done
[ -n "$TARGET" ] || die "Usage: install.sh [--dry-run] [--force] TARGET_PROJECT_DIR"
[ -d "$TARGET" ] || die "Target does not exist: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"
[ "$TARGET" = "$SRC" ] && die "Target is the framework repository itself."

run() { if [ "$DRY" -eq 1 ]; then echo "  would: $*"; else "$@"; fi; }
copy_file() { # src dst
  if [ -e "$2" ] && [ "$FORCE" -eq 0 ]; then log_skip "exists: ${2#"$TARGET"/}"; return 0; fi
  run mkdir -p "$(dirname "$2")" && run cp "$1" "$2" && log_ok "${2#"$TARGET"/}"
}
copy_tree() { # srcdir dstdir
  local f rel
  while IFS= read -r f; do rel="${f#"$1"/}"; copy_file "$f" "$2/$rel"; done < <(find "$1" -type f ! -name '.DS_Store' | sort)
}

HOME_DIR="$TARGET/.saas-blind-security"
log_info "Installing saas-blind-security v$SBS_VERSION into $TARGET"
for d in scripts fabric templates; do copy_tree "$SRC/$d" "$HOME_DIR/$d"; done
for d in codeql semgrep snyk zap; do copy_tree "$SRC/config/$d" "$HOME_DIR/config/$d"; done
copy_file "$SRC/config/sbs.conf.example" "$HOME_DIR/sbs.conf"
copy_file "$SRC/docs/security-checklist.md" "$HOME_DIR/docs/security-checklist.md"
copy_file "$SRC/docs/threat-modeling.md" "$HOME_DIR/docs/threat-modeling.md"
[ "$DRY" -eq 0 ] && chmod +x "$HOME_DIR"/scripts/*.sh 2>/dev/null

if [ "$WORKFLOWS" -eq 1 ]; then
  for w in codeql semgrep snyk zap-baseline zap-full-scan security-audit dependabot-auto-review; do
    copy_file "$SRC/.github/workflows/$w.yml" "$TARGET/.github/workflows/$w.yml"
  done
  if [ ! -f "$TARGET/.github/dependabot.yml" ] && [ ! -f "$TARGET/.github/dependabot.yaml" ]; then
    if [ "$DRY" -eq 1 ]; then echo "  would: generate .github/dependabot.yml"
    else mkdir -p "$TARGET/.github" && "$SCRIPT_DIR/generate-dependabot.sh" "$TARGET" > "$TARGET/.github/dependabot.yml" && log_ok ".github/dependabot.yml (generated)"; fi
  else log_skip "exists: .github/dependabot.yml (compare with: $SCRIPT_DIR/generate-dependabot.sh $TARGET)"; fi
fi

if [ "$SKILLS" -eq 1 ]; then copy_tree "$SRC/.claude/skills" "$TARGET/.claude/skills"; fi

if [ -f "$TARGET/CLAUDE.md" ]; then
  copy_file "$SRC/CLAUDE.md" "$HOME_DIR/CLAUDE.security.md"
  if ! grep -q 'CLAUDE.security.md' "$TARGET/CLAUDE.md"; then
    log_warn "The project already has a CLAUDE.md. Add this line to it so Claude Code loads the security instructions:"
    echo "    @.saas-blind-security/CLAUDE.security.md"
  fi
else
  copy_file "$SRC/CLAUDE.md" "$TARGET/CLAUDE.md"
fi

if [ "$DRY" -eq 0 ]; then
  touch "$TARGET/.gitignore"
  grep -qxF '.sbs-results/' "$TARGET/.gitignore" || { printf '\n# saas-blind-security results (may contain sensitive data)\n.sbs-results/\n' >> "$TARGET/.gitignore"; log_ok ".gitignore: .sbs-results/"; }
fi

echo
log_info "Next steps:"
echo "  1. cd \"$TARGET\" && ./.saas-blind-security/scripts/security-check.sh --check-only"
echo "  2. Review .saas-blind-security/sbs.conf (thresholds, ZAP allowed hosts)."
echo "  3. Optional secrets in GitHub: SNYK_TOKEN. Optional variables: SBS_FAIL_ON_SEVERITY, SBS_ZAP_TARGET, SBS_ZAP_ALLOWED_HOSTS."
echo "  4. Commit, push, then run .saas-blind-security/scripts/configure-github-security.sh OWNER/REPO --dry-run"
echo "  5. ./.saas-blind-security/scripts/security-check.sh --report"
