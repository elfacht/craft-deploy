#!/bin/bash
#
# Shared library for the Craft CMS deployment scripts.
# Sourced by deploy.sh, rollback.sh and setup.sh.
# @see https://github.com/elfacht/craft-deploy
#
# @author  Martin Szymanski <martin@elfacht.com>
# @license MIT

# shellcheck disable=SC2034
CRAFT_DEPLOY_VERSION="1.0.0"

# Empty globs expand to nothing (used for listing releases/backups).
shopt -s nullglob

LOG_FILE=""

#######################################
# Logging. Timestamped; mirrored into LOG_FILE once it is set.
#######################################
log() {
  local line
  line="[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"
  printf '%s\n' "$line"
  if [ -n "$LOG_FILE" ]; then printf '%s\n' "$line" >> "$LOG_FILE" || true; fi
}
warn() { log "WARN: $*" >&2; }
err()  { log "ERROR: $*" >&2; }
die()  { err "$@"; exit 1; }

#######################################
# Load a .env-style file without sourcing it (never executes config code).
# Skips blank/comment lines, keeps '=' in values, strips surrounding quotes,
# tolerates CRLF. Variables are exported so hooks inherit them.
# Arguments:
#   $1 - path to the env file
#######################################
load_env() {
  local file="$1" line key val
  [ -f "$file" ] || die "Config file not found: $file"

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    key="${line%%=*}"
    key="${key%"${key##*[![:space:]]}"}"
    [[ "$line" == *=* && "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    val="${line#*=}"
    case "$val" in
      \"*\") val="${val:1:${#val}-2}" ;;
      \'*\') val="${val:1:${#val}-2}" ;;
    esac
    export "$key=$val"
  done < "$file"
}

#######################################
# Load the config shared by deploy.sh and rollback.sh.
# Arguments:
#   $1 - path to the env file
#######################################
load_config() {
  load_env "$1"

  ROOT_PATH="${DEPLOY_ROOT:-}"
  [ -n "$ROOT_PATH" ] || die "Required config 'DEPLOY_ROOT' is empty. Set it in your config file."
  [ -d "$ROOT_PATH/releases" ] || die "Missing $ROOT_PATH/releases. Run ./setup.sh first."
  LOG_FILE="$ROOT_PATH/deploy.log"

  # Craft subfolder; "", ".", "./" and "cms/" are all accepted.
  CRAFT_DIR="${DEPLOY_CRAFT_DIR:-}"
  CRAFT_DIR="${CRAFT_DIR#./}"
  CRAFT_DIR="${CRAFT_DIR%/}"
  [ "$CRAFT_DIR" = "." ] && CRAFT_DIR=""

  PHP_BIN="${DEPLOY_PHP_BIN:-php}"
  COMPOSER_BIN="${DEPLOY_COMPOSER_BIN:-composer}"
  COMPOSER_FLAGS="${DEPLOY_COMPOSER_FLAGS:---no-interaction --prefer-dist --optimize-autoloader}"
  RUN_MIGRATE="${DEPLOY_RUN_MIGRATE:-1}"
  RUN_PROJECT_CONFIG="${DEPLOY_RUN_PROJECT_CONFIG:-1}"
  RESTART_PHP="${DEPLOY_RESTART_PHP:-}"
}

#######################################
# Run composer install in a directory.
# COMPOSER_BIN and COMPOSER_FLAGS are word-split on purpose, so
# COMPOSER_BIN may be e.g. "php8.4 /usr/local/bin/composer".
# Arguments:
#   $1 - Craft directory
#######################################
composer_install() {
  log "- Composer install"
  # shellcheck disable=SC2086
  $COMPOSER_BIN install --working-dir="$1" $COMPOSER_FLAGS
}

#######################################
# Run migrations and project-config apply, as configured.
# Arguments:
#   $1 - Craft directory
#######################################
craft_update() {
  if [ "$RUN_MIGRATE" = "1" ]; then
    log "- Run migrations"
    "$PHP_BIN" "$1/craft" migrate/all
  fi
  if [ "$RUN_PROJECT_CONFIG" = "1" ]; then
    log "- Apply project config"
    "$PHP_BIN" "$1/craft" project-config/apply
  fi
}

#######################################
# Point $ROOT_PATH/current at a release.
# `ln -sfn` would nest the link inside a real directory, so refuse that.
# Arguments:
#   $1 - target release path
#######################################
switch_current() {
  local link="$ROOT_PATH/current"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    die "'$link' is a real file/directory, not a symlink. Remove it and re-run."
  fi
  log "- Switch current -> $(basename "$1")"
  ln -sfn "$1" "$link"
}

#######################################
# Restart PHP if DEPLOY_RESTART_PHP is set (word-split, no shell).
#######################################
restart_php() {
  [ -n "$RESTART_PHP" ] || return 0
  log "- Restart PHP"
  # shellcheck disable=SC2086
  $RESTART_PHP
}
