#!/bin/bash
#
# Shared library for the Craft CMS deployment scripts.
# Sourced by deploy.sh and rollback.sh.
# @see https://github.com/elfacht/craft-deploy
#
# @author  Martin Szymanski <martin@elfacht.com>
# @license MIT

#######################################
# Single source of truth for the version.
# Used by the scripts that source this file.
#######################################
# shellcheck disable=SC2034
CRAFT_DEPLOY_VERSION="0.7.0"

#######################################
# Runtime flags (may be overridden by callers / CLI flags).
#######################################
DRY_RUN="${DRY_RUN:-0}"
LOG_FILE="${LOG_FILE:-}"

#######################################
# Logging helpers.
# Everything is timestamped and, if LOG_FILE is set, mirrored into it.
#######################################
_log_ts() {
  date +'%Y-%m-%dT%H:%M:%S%z'
}

_log_write() {
  [ -n "$LOG_FILE" ] || return 0
  printf '%s\n' "$1" >> "$LOG_FILE" 2>/dev/null || true
}

log() {
  local line
  line="[$(_log_ts)] $*"
  printf '%s\n' "$line"
  _log_write "$line"
}

warn() {
  local line
  line="[$(_log_ts)] WARN: $*"
  printf '%s\n' "$line" >&2
  _log_write "$line"
}

err() {
  local line
  line="[$(_log_ts)] ERROR: $*"
  printf '%s\n' "$line" >&2
  _log_write "$line"
}

die() {
  err "$@"
  exit 1
}

#######################################
# Run a command, or just print it when DRY_RUN=1.
# Use for mutating/external commands (git, composer, ln, rm, curl, php).
# Builtins like `cd` must be called directly, not through this wrapper.
#######################################
run() {
  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] $*"
    return 0
  fi
  "$@"
}

#######################################
# Robustly load a .env-style file.
# Pure-bash line parser (no sourcing, no /dev/stdin, no process
# substitution) so it works in restricted server environments and never
# executes code from the config file.
#   - Blank lines and comment lines (#) are ignored.
#   - Only valid KEY=VALUE lines are taken; the value keeps any '='.
#   - Surrounding single/double quotes are stripped; CRLF is tolerated.
#   - Variables are exported so child processes inherit them.
# Arguments:
#   $1 - path to the env file
#######################################
load_env() {
  local file="$1"
  [ -f "$file" ] || die "Config file not found: $file"

  local line key val
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"                      # tolerate CRLF
    line="${line#"${line%%[![:space:]]*}"}"   # strip leading whitespace
    case "$line" in
      ''|'#'*)      continue ;;               # blank or comment
      [A-Za-z_]*=*) ;;                         # looks like KEY=VALUE
      *)            continue ;;
    esac
    key="${line%%=*}"
    val="${line#*=}"
    key="${key%"${key##*[![:space:]]}"}"      # trim trailing space from key
    case "$key" in *[!A-Za-z0-9_]*) continue ;; esac
    if [ "${#val}" -ge 2 ]; then              # strip matching surrounding quotes
      case "$val" in
        \"*\") val="${val#\"}"; val="${val%\"}" ;;
        \'*\') val="${val#\'}"; val="${val%\'}" ;;
      esac
    fi
    export "$key=$val"
  done < "$file"
}

#######################################
# Fail fast if a required variable is empty.
# Arguments:
#   $@ - one or more variable names
#######################################
require_var() {
  local name val
  for name in "$@"; do
    val="${!name:-}"
    [ -n "$val" ] || die "Required config '$name' is empty. Set it in your config file."
  done
}

#######################################
# Keep the newest N entries in a directory, delete the rest.
# Entries (files or dirs) are sorted ascending by name; release and backup
# names are timestamped, so name-sort is chronological. The oldest entries
# beyond the keep count are removed.
# Arguments:
#   $1 - parent directory
#   $2 - number of entries to keep
#   $3 - label for log output (e.g. "release", "backup")
#######################################
prune_old() {
  local parent="$1" keep="$2" label="${3:-entry}"
  [ -d "$parent" ] || return 0
  [[ "$keep" =~ ^[0-9]+$ ]] || keep=5

  local entries=() e
  while IFS= read -r e; do
    [ -n "$e" ] && entries+=("$e")
  done < <(find "$parent" -mindepth 1 -maxdepth 1 | sort)

  local total=${#entries[@]}
  local remove=$(( total - keep ))
  (( remove > 0 )) || return 0

  local i
  for (( i = 0; i < remove; i++ )); do
    log "- Delete old ${label} '$(basename "${entries[$i]}")'"
    run rm -rf "${entries[$i]}"
  done
}

#######################################
# Run an optional hook script if it is set and executable.
# The hook inherits the exported DEPLOY_* vars plus RELEASE_PATH/ROOT_PATH.
# Arguments:
#   $1 - hook script path (may be empty)
#   $2 - label for log output (e.g. "before", "after")
#######################################
run_hook() {
  local hook="$1" label="$2"
  [ -n "$hook" ] || return 0
  if [ ! -f "$hook" ]; then
    warn "Hook '$label' not found: $hook (skipping)"
    return 0
  fi
  log "- Run ${label} hook: $hook"
  run bash "$hook"
}
