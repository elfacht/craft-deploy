#!/bin/bash
#
# Rollback script for the Craft CMS deployment.
# @see https://github.com/elfacht/craft-deploy
#
# - Switches the `current` symlink back to the previous release.
# - Deletes the rolled-back (newest) release folder.
# - Runs composer install, migrations and project-config apply.
# - This script does NOT touch the database beyond migrations!
#
# @author  Martin Szymanski <martin@elfacht.com>
# @license MIT

set -euo pipefail

#######################################
# Resolve script directory and load shared library.
#######################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

#######################################
# Parse flags.
#######################################
ENV_FILE="$SCRIPT_DIR/.env"
while [ $# -gt 0 ]; do
  case "$1" in
    --env)      ENV_FILE="${2:-}"; shift 2 ;;
    --dry-run)  DRY_RUN=1; shift ;;
    --verbose)  set -x; shift ;;
    --version)  echo "$CRAFT_DEPLOY_VERSION"; exit 0 ;;
    -h|--help)
      echo "Usage: ./rollback.sh [--env <path>] [--dry-run]"; exit 0 ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

#######################################
# Load configuration.
#######################################
load_env "$ENV_FILE"

ROOT_PATH="${DEPLOY_ROOT:-}"
CRAFT_DIR="$(normalize_subdir "${DEPLOY_CRAFT_DIR:-}")"
RESTART_PHP="${DEPLOY_RESTART_PHP:-}"
PHP_BIN="${DEPLOY_PHP_BIN:-php}"
COMPOSER_BIN="${DEPLOY_COMPOSER_BIN:-composer}"
COMPOSER_FLAGS="${DEPLOY_COMPOSER_FLAGS:---no-interaction --prefer-dist --optimize-autoloader}"
COMPOSER_VIA_PHP="${DEPLOY_COMPOSER_VIA_PHP:-0}"
RUN_MIGRATE="${DEPLOY_RUN_MIGRATE:-1}"
RUN_PROJECT_CONFIG="${DEPLOY_RUN_PROJECT_CONFIG:-1}"

require_var DEPLOY_ROOT
[ -d "$ROOT_PATH/releases" ] || die "Missing releases directory: $ROOT_PATH/releases"

LOG_FILE="$ROOT_PATH/deploy.log"
trap 'err "Rollback failed at line $LINENO."' ERR

#######################################
# Determine the current (newest) and previous releases by name (timestamp).
# list_entries returns children sorted ascending, so the newest are last.
#######################################
list_entries "$ROOT_PATH/releases"
releases=()
for r in ${LIST_ENTRIES[@]+"${LIST_ENTRIES[@]}"}; do
  [ -d "$r" ] && releases+=("$r")
done

count=${#releases[@]}
if [ "$count" -lt 2 ]; then
  die "Need at least two releases to roll back (found $count)."
fi

CURRENT_RELEASE="${releases[$((count - 1))]}"
LAST_STABLE="${releases[$((count - 2))]}"

log "=== Rolling back to $(basename "$LAST_STABLE") ==="

if [ "$DRY_RUN" = "1" ]; then
  log "[dry-run] Would switch current -> $LAST_STABLE"
  log "[dry-run] Would delete $CURRENT_RELEASE"
  exit 0
fi

#######################################
# Switch `current` to the previous release.
#######################################
log "- Switch current -> $(basename "$LAST_STABLE")"
run ln -sfn "$LAST_STABLE" "$ROOT_PATH/current"

#######################################
# Delete the rolled-back release folder.
#######################################
log "- Delete release $(basename "$CURRENT_RELEASE")"
run rm -rf "$CURRENT_RELEASE"

#######################################
# Re-run composer and Craft commands on the now-current release.
#######################################
CURRENT_CRAFT="$ROOT_PATH/current${CRAFT_DIR:+/$CRAFT_DIR}"
log "- Composer install"
if [ "$COMPOSER_VIA_PHP" = "1" ]; then
  composer_cmd=("$PHP_BIN" "$COMPOSER_BIN")
else
  composer_cmd=("$COMPOSER_BIN")
fi
# COMPOSER_FLAGS is intentionally word-split into separate arguments.
# shellcheck disable=SC2086
if ! ( cd "$CURRENT_CRAFT" && run "${composer_cmd[@]}" install $COMPOSER_FLAGS ); then
  die "Composer install failed during rollback."
fi
if [ "$RUN_MIGRATE" = "1" ]; then
  log "- Run migrations"
  run "$PHP_BIN" "$CURRENT_CRAFT/craft" migrate/all
fi
if [ "$RUN_PROJECT_CONFIG" = "1" ]; then
  log "- Apply project config"
  run "$PHP_BIN" "$CURRENT_CRAFT/craft" project-config/apply
fi

#######################################
# Restart PHP (optional).
#######################################
if [ -n "$RESTART_PHP" ]; then
  log "- Restart PHP"
  # RESTART_PHP is a command line and is intentionally word-split.
  # shellcheck disable=SC2086
  run $RESTART_PHP
fi

log "=== Rolled back to $(basename "$LAST_STABLE") ==="
