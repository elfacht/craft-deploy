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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ENV_FILE="$SCRIPT_DIR/.env"
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --env)      ENV_FILE="${2:-}"; shift 2 ;;
    --dry-run)  DRY_RUN=1; shift ;;
    --verbose)  set -x; shift ;;
    --version)  echo "$CRAFT_DEPLOY_VERSION"; exit 0 ;;
    -h|--help)  echo "Usage: ./rollback.sh [--env <path>] [--dry-run]"; exit 0 ;;
    *)          err "Unknown option: $1"; exit 1 ;;
  esac
done

load_config "$ENV_FILE"

#######################################
# Newest release is the current one, the one before it is the target.
# Names are timestamps, so the glob's alphabetical order is chronological.
#######################################
releases=("$ROOT_PATH"/releases/*/)
count=${#releases[@]}
[ "$count" -ge 2 ] || die "Need at least two releases to roll back (found $count)."
CURRENT_RELEASE="${releases[$((count - 1))]%/}"
LAST_STABLE="${releases[$((count - 2))]%/}"

if [ "$DRY_RUN" = "1" ]; then
  log "[dry-run] Would switch current -> $LAST_STABLE"
  log "[dry-run] Would delete $CURRENT_RELEASE"
  exit 0
fi

trap 'err "Rollback failed at line $LINENO."' ERR
log "=== Rolling back to $(basename "$LAST_STABLE") ==="

switch_current "$LAST_STABLE"

log "- Delete release $(basename "$CURRENT_RELEASE")"
rm -rf "$CURRENT_RELEASE"

CURRENT_CRAFT="$ROOT_PATH/current${CRAFT_DIR:+/$CRAFT_DIR}"
composer_install "$CURRENT_CRAFT" || die "Composer install failed during rollback."
craft_update "$CURRENT_CRAFT"
restart_php

log "=== Rolled back to $(basename "$LAST_STABLE") ==="
