#!/usr/bin/env bash
# saas-blind-security - dependency-free baseline checks (read-only).
# Created and maintained by IbrahimCodeur - https://github.com/IbrahimCodeur
# SPDX-License-Identifier: MIT
#
# Usage: builtin-checks.sh [PROJECT_DIR]
# Prints a JSON array of findings. Secret values are NEVER printed: only file and line.
#
# These are heuristics meant to catch obvious mistakes when no scanner is installed.
# They do not replace Semgrep, CodeQL, Snyk, GitHub secret scanning or a manual review.

set -uo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
have jq || die "jq is required"

TARGET="${1:-.}"
[ -d "$TARGET" ] || die "Not a directory: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"
sbs_load_config "$TARGET/.saas-blind-security/sbs.conf"
sbs_load_config "$TARGET/config/sbs.conf"
EXCLUDES="${SBS_EXCLUDE_PATHS:-}"

OUT="$(mktemp)"; trap 'rm -f "$OUT"' EXIT
emit() { # rule severity title file line detail
  jq -nc --arg rule "$1" --arg sev "$2" --arg title "$3" --arg file "$4" --arg line "$5" --arg detail "$6" \
    '{rule:$rule, severity:$sev, title:$title, file:$file, line:(if $line=="" then null else ($line|tonumber) end), detail:$detail}' >> "$OUT"
}

excluded() {
  local f="$1" ex
  case "$f" in .saas-blind-security/*|node_modules/*|*/node_modules/*|vendor/*|*/vendor/*|.git/*|.sbs-results/*|dist/*|build/*|.venv/*|venv/*) return 0 ;; esac
  for ex in $EXCLUDES; do case "$f" in "$ex"|"$ex"/*) return 0 ;; esac; done
  return 1
}

# File inventory: tracked files when in a git repository, otherwise a bounded find.
FILES="$(mktemp)"; trap 'rm -f "$OUT" "$FILES"' EXIT
if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$TARGET" ls-files --cached --others --exclude-standard 2>/dev/null > "$FILES.all"
  IN_GIT=1
else
  ( cd "$TARGET" && find . -type f -size -1024k 2>/dev/null | sed 's#^\./##' ) > "$FILES.all"
  IN_GIT=0
fi
while IFS= read -r f; do excluded "$f" || printf '%s\n' "$f"; done < "$FILES.all" > "$FILES"
rm -f "$FILES.all"

# 1. Environment files committed / present outside examples
while IFS= read -r f; do
  base="$(basename "$f")"
  case "$base" in
    .env|.env.local|.env.production|.env.prod|.env.staging|.env.development|.env.dev|.env.test|*.env)
      if [ "$IN_GIT" -eq 1 ] && git -C "$TARGET" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
        emit "sbs-builtin-env-file-committed" HIGH "Environment file is tracked by git" "$f" "" \
          "Real environment files usually contain secrets. Remove from git history, rotate the secrets, add to .gitignore."
      fi ;;
  esac
done < "$FILES"

# 2. Secrets / key material. Patterns are documented token formats; values are never printed.
SECRET_RE='-----BEGIN ((RSA|EC|DSA|OPENSSH|PGP) )?PRIVATE KEY|AKIA[0-9A-Z]{16}|sk_live_[0-9A-Za-z]{20,}|rk_live_[0-9A-Za-z]{20,}|ghp_[0-9A-Za-z]{36}|github_pat_[0-9A-Za-z_]{40,}|xox[abprs]-[0-9A-Za-z-]{10,}|AIza[0-9A-Za-z_-]{35}|SG\.[0-9A-Za-z_-]{22}\.[0-9A-Za-z_-]{43}'
while IFS= read -r f; do
  [ -f "$TARGET/$f" ] || continue
  case "$f" in *.png|*.jpg|*.jpeg|*.gif|*.ico|*.pdf|*.zip|*.gz|*.woff|*.woff2|*.ttf|*.lock|package-lock.json) continue ;; esac
  grep -IEno -- "$SECRET_RE" "$TARGET/$f" 2>/dev/null | while IFS=: read -r ln match; do
    kind="secret"
    case "$match" in
      -----BEGIN*) kind="private key" ;;
      AKIA*) kind="AWS access key id" ;;
      sk_live_*|rk_live_*) kind="Stripe live key" ;;
      ghp_*|github_pat_*) kind="GitHub token" ;;
      xox*) kind="Slack token" ;;
      AIza*) kind="Google API key" ;;
      SG.*) kind="SendGrid API key" ;;
    esac
    emit "sbs-builtin-hardcoded-secret" CRITICAL "Possible hardcoded $kind" "$f" "$ln" \
      "Value redacted. If real: revoke and rotate it now, then remove it from git history. Use environment variables or a secret manager."
  done
done < "$FILES"

# 3. .gitignore hygiene
if [ "$IN_GIT" -eq 1 ]; then
  if ! git -C "$TARGET" check-ignore -q .env 2>/dev/null; then
    emit "sbs-builtin-gitignore-env" LOW ".env is not ignored by git" ".gitignore" "" \
      "Add .env and .env.* (except examples) to .gitignore to prevent accidental secret commits."
  fi
fi

# 4. Debug mode enabled in production-like configuration
while IFS= read -r f; do
  case "$(basename "$f")" in
    .env.production|.env.prod|production.env)
      ln="$(grep -nE '^[[:space:]]*(APP_DEBUG|DEBUG)[[:space:]]*=[[:space:]]*"?(true|1|True)' "$TARGET/$f" 2>/dev/null | head -n1 | cut -d: -f1)"
      [ -n "$ln" ] && emit "sbs-builtin-debug-production" HIGH "Debug mode enabled in production configuration" "$f" "$ln" \
        "Debug pages leak stack traces, environment variables and secrets." ;;
    settings.py|production.py|prod.py)
      ln="$(grep -nE '^[[:space:]]*DEBUG[[:space:]]*=[[:space:]]*True' "$TARGET/$f" 2>/dev/null | head -n1 | cut -d: -f1)"
      [ -n "$ln" ] && emit "sbs-builtin-django-debug" MEDIUM "Django DEBUG = True hardcoded" "$f" "$ln" \
        "Read DEBUG from the environment and default to False." ;;
  esac
done < "$FILES"

# 5. Lockfiles (needed for reproducible builds and accurate dependency scanning)
while IFS= read -r f; do
  d="$(dirname "$f")"
  case "$(basename "$f")" in
    package.json)
      if ! ls "$TARGET/$d"/package-lock.json "$TARGET/$d"/yarn.lock "$TARGET/$d"/pnpm-lock.yaml "$TARGET/$d"/npm-shrinkwrap.json >/dev/null 2>&1; then
        emit "sbs-builtin-missing-lockfile" LOW "package.json without a lockfile" "$f" "" \
          "Commit a lockfile so dependency versions are pinned and scannable."
      fi ;;
    composer.json)
      [ -f "$TARGET/$d/composer.lock" ] || emit "sbs-builtin-missing-lockfile" LOW "composer.json without composer.lock" "$f" "" \
        "Commit composer.lock for applications so dependency versions are pinned and scannable." ;;
  esac
done < "$FILES"

# 6. Dockerfiles
while IFS= read -r f; do
  case "$(basename "$f")" in
    Dockerfile|Dockerfile.*|*.Dockerfile)
      if ! grep -qE '^[[:space:]]*USER[[:space:]]+' "$TARGET/$f" 2>/dev/null; then
        emit "sbs-builtin-docker-root" LOW "Container runs as root (no USER instruction)" "$f" "" "Add a non-root USER for the runtime stage."
      fi
      ln="$(grep -nE '^[[:space:]]*FROM[[:space:]]+[^[:space:]]+:latest([[:space:]]|$)' "$TARGET/$f" 2>/dev/null | head -n1 | cut -d: -f1)"
      [ -n "$ln" ] && emit "sbs-builtin-docker-latest" LOW "Base image uses the mutable :latest tag" "$f" "$ln" "Pin a version tag or digest." ;;
  esac
done < "$FILES"

# 7. GitHub Actions risky patterns
while IFS= read -r f; do
  case "$f" in .github/workflows/*.yml|.github/workflows/*.yaml) ;; *) continue ;; esac
  if grep -qE '(^|[^a-z_])pull_request_target([^a-z_]|$)' "$TARGET/$f" && grep -qE 'github\.event\.pull_request\.head\.(sha|ref)' "$TARGET/$f"; then
    ln="$(grep -nE 'github\.event\.pull_request\.head\.(sha|ref)' "$TARGET/$f" | head -n1 | cut -d: -f1)"
    emit "sbs-builtin-gha-pwn-request" HIGH "pull_request_target workflow checks out untrusted PR code" "$f" "$ln" \
      "Untrusted code runs with a privileged token and secrets. Use pull_request, or never execute PR code in this workflow."
  fi
  grep -nE '\$\{\{[[:space:]]*github\.event\.(issue|pull_request|comment|review|head_commit)\.(title|body|head\.ref|message)' "$TARGET/$f" 2>/dev/null | while IFS=: read -r ln _; do
    emit "sbs-builtin-gha-script-injection" MEDIUM "Untrusted event data interpolated in workflow" "$f" "$ln" \
      "Pass it through an env: variable instead of \${{ }} inside run: scripts."
  done
  grep -nE '^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*[^.][^@[:space:]]+@[^[:space:]#]+' "$TARGET/$f" 2>/dev/null | grep -vE '@[0-9a-f]{40}' | while IFS=: read -r ln _; do
    emit "sbs-builtin-gha-unpinned-action" INFO "Third-party action not pinned to a commit SHA" "$f" "$ln" "Pin actions to a full commit SHA and let Dependabot update them."
  done
done < "$FILES"

if [ -s "$OUT" ]; then jq -s '.' "$OUT"; else echo '[]'; fi
