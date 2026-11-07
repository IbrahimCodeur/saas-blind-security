#!/usr/bin/env bash
# saas-blind-security - shared helpers
# Created and maintained by IbrahimCodeur - https://github.com/IbrahimCodeur
# SPDX-License-Identifier: MIT

# Do not "set -e" here: callers decide their own error policy.

export SBS_VERSION="0.1.0"

# Resolve the framework home (directory that contains scripts/, config/, ...).
sbs_home() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s\n' "$here"
}

if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  _C_RED=$'\033[31m'; _C_YEL=$'\033[33m'; _C_GRN=$'\033[32m'; _C_BLU=$'\033[34m'; _C_DIM=$'\033[2m'; _C_RST=$'\033[0m'
else
  _C_RED=""; _C_YEL=""; _C_GRN=""; _C_BLU=""; _C_DIM=""; _C_RST=""
fi

log_info()  { printf '%s[info]%s %s\n'  "$_C_BLU" "$_C_RST" "$*" >&2; }
log_ok()    { printf '%s[ ok ]%s %s\n'  "$_C_GRN" "$_C_RST" "$*" >&2; }
log_warn()  { printf '%s[warn]%s %s\n'  "$_C_YEL" "$_C_RST" "$*" >&2; }
log_error() { printf '%s[fail]%s %s\n'  "$_C_RED" "$_C_RST" "$*" >&2; }
log_skip()  { printf '%s[skip]%s %s\n'  "$_C_DIM" "$_C_RST" "$*" >&2; }

die() { log_error "$*"; exit 2; }

have() { command -v "$1" >/dev/null 2>&1; }

# Severity helpers. Canonical levels: CRITICAL HIGH MEDIUM LOW INFO
severity_rank() {
  case "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" in
    CRITICAL) echo 5 ;;
    HIGH)     echo 4 ;;
    MEDIUM)   echo 3 ;;
    LOW)      echo 2 ;;
    INFO)     echo 1 ;;
    NONE|OFF) echo 99 ;;
    *)        echo 0 ;;
  esac
}

normalize_severity() {
  local s
  s="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
  case "$s" in
    CRITICAL) echo CRITICAL ;;
    HIGH|ERROR) echo HIGH ;;
    MEDIUM|MODERATE|WARNING) echo MEDIUM ;;
    LOW|NOTE) echo LOW ;;
    *) echo INFO ;;
  esac
}

# Load key=value configuration without executing arbitrary code.
# Only SBS_* keys made of [A-Z0-9_] are accepted; values are taken literally.
sbs_load_config() {
  local file="$1" line key val
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    key="${line%%=*}"
    val="${line#*=}"
    [ "$key" = "$line" ] && continue
    case "$key" in
      SBS_[A-Z0-9_]*) ;;
      *) continue ;;
    esac
    printf '%s' "$key" | grep -Eq '^SBS_[A-Z0-9_]+$' || continue
    val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
    # Environment variables win over the file.
    if [ -z "${!key+x}" ]; then
      export "$key=$val"
    fi
  done < "$file"
}

# Returns 0 when the URL host is a local development host.
is_local_url() {
  local host
  host="$(printf '%s' "$1" | sed -E 's#^[a-zA-Z]+://##; s#^[^@/]*@##; s#[/?].*$##; s#:[0-9]+$##')"
  case "$host" in
    localhost|127.0.0.1|0.0.0.0|'[::1]'|host.docker.internal|*.localhost|*.test) return 0 ;;
    *) return 1 ;;
  esac
}

url_host() {
  printf '%s' "$1" | sed -E 's#^[a-zA-Z]+://##; s#^[^@/]*@##; s#[/?].*$##; s#:[0-9]+$##'
}
