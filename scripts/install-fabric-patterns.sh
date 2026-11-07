#!/usr/bin/env bash
# saas-blind-security - copy the security patterns into a Fabric patterns directory.
# Created and maintained by IbrahimCodeur - https://github.com/IbrahimCodeur
# SPDX-License-Identifier: MIT
#
# Usage: install-fabric-patterns.sh [DEST_DIR]
# DEST_DIR defaults to $SBS_FABRIC_PATTERNS_DIR, then ~/.config/fabric/patterns.
# Recommended: configure a Fabric "Custom Patterns" directory with `fabric --setup`
# and pass it here, so Fabric updates never overwrite these patterns.
# Existing patterns with the same name are NOT overwritten unless --force is given.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
FORCE=0; DEST=""
for a in "$@"; do case "$a" in --force) FORCE=1 ;; -h|--help) sed -n '2,11p' "$0"; exit 0 ;; *) DEST="$a" ;; esac; done
DEST="${DEST:-${SBS_FABRIC_PATTERNS_DIR:-$HOME/.config/fabric/patterns}}"
SRC="$SCRIPT_DIR/../fabric/patterns"
mkdir -p "$DEST" || die "Cannot create $DEST"
n=0
for p in "$SRC"/*/; do
  name="$(basename "$p")"
  if [ -e "$DEST/$name" ] && [ "$FORCE" -eq 0 ]; then log_skip "$name exists in $DEST (use --force)"; continue; fi
  mkdir -p "$DEST/$name" && cp "$p"system.md "$DEST/$name/system.md" && n=$((n+1)) && log_ok "$name"
done
log_info "$n pattern(s) installed in $DEST"
have fabric || log_warn "fabric is not installed: https://github.com/danielmiessler/Fabric"
echo "Example: cat .sbs-results/<run>/findings.json | fabric --pattern sbs_interpret_semgrep_results"
