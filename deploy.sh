#!/bin/bash
#
# Craft CMS deployment script for staging/production servers.
# @see https://github.com/elfacht/craft-deploy
#
# - Backs up the database (optional).
# - Creates a timestamped release folder and clones the git repo/ref.
# - Runs composer install.
# - Creates symlinks to shared files and folders (configurable).
# - Runs Craft migrations and project-config apply (optional).
# - Atomically switches the `current` symlink to the new release.
# - Prunes old releases and backups.
# - Clears opcache / restarts PHP (optional).
#
# @author  Martin Szymanski <martin@elfacht.com>
# @license MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<EOF
craft-deploy ${CRAFT_DEPLOY_VERSION}

Usage: ./deploy.sh [options]

Options:
  --env <path>      Path to the config file (default: ./.env next to deploy.sh)
  --branch <name>   Override DEPLOY_BRANCH for this run
  --ref <ref>       Deploy a specific tag/commit/branch (overrides branch)
  --no-backup       Skip the database backup for this run
  --dry-run         Validate config and print the planned actions, change nothing
  --verbose         Enable shell tracing (set -x)
  --version         Print version and exit
  -h, --help        Show this help and exit

Configuration is read from the .env file. See .env.example for all options.
EOF
}

#######################################
# CLI flags. CLI values override .env.
#######################################
ENV_FILE="$SCRIPT_DIR/.env"
CLI_BRANCH=""
CLI_REF=""
NO_BACKUP=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --env)        ENV_FILE="${2:-}"; shift 2 ;;
    --branch)     CLI_BRANCH="${2:-}"; shift 2 ;;
    --ref)        CLI_REF="${2:-}"; shift 2 ;;
    --no-backup)  NO_BACKUP=1; shift ;;
    --dry-run)    DRY_RUN=1; shift ;;
    --verbose)    set -x; shift ;;
    --version)    echo "$CRAFT_DEPLOY_VERSION"; exit 0 ;;
    -h|--help)    usage; exit 0 ;;
    *)            err "Unknown option: $1"; usage; exit 1 ;;
  esac
done

#######################################
# Configuration.
#######################################
load_config "$ENV_FILE"

GIT_REPO="${DEPLOY_REPO:-}"
GIT_BRANCH="${CLI_BRANCH:-${DEPLOY_BRANCH:-}}"
GIT_REF="${CLI_REF:-${DEPLOY_REF:-}}"
ROOT_URL="${DEPLOY_URL:-}"
CLEAR_OPCACHE="${DEPLOY_CLEAR_OPCACHE:-0}"
KEEP_RELEASES="${DEPLOY_KEEP_RELEASES:-5}"
KEEP_BACKUPS="${DEPLOY_KEEP_BACKUPS:-5}"
ASSETS_DIR="${DEPLOY_ASSETS_DIR:-uploads}"
LINKED_FILES="${DEPLOY_LINKED_FILES:-.env web/.htaccess}"
LINKED_DIRS="${DEPLOY_LINKED_DIRS:-storage web/${ASSETS_DIR} web/cpresources}"
RUN_BACKUP="${DEPLOY_RUN_BACKUP:-1}"
EXTRA_CRAFT_COMMANDS="${DEPLOY_CRAFT_COMMANDS:-}"
SHALLOW="${DEPLOY_SHALLOW:-0}"
SUBMODULES="${DEPLOY_SUBMODULES:-0}"
HOOK_BEFORE="${DEPLOY_HOOK_BEFORE:-}"
HOOK_AFTER="${DEPLOY_HOOK_AFTER:-}"
[ "$NO_BACKUP" = "1" ] && RUN_BACKUP=0

[ -n "$GIT_REPO" ] || die "Required config 'DEPLOY_REPO' is empty. Set it in your config file."
if [ "$CLEAR_OPCACHE" = "1" ] && [ -z "$ROOT_URL" ]; then
  die "DEPLOY_CLEAR_OPCACHE is enabled but DEPLOY_URL is empty."
fi

CURRENT_RELEASE="$(date +'%Y%m%d%H%M%S')"
RELEASE_PATH="$ROOT_PATH/releases/$CURRENT_RELEASE"
RELEASE_CRAFT="$RELEASE_PATH${CRAFT_DIR:+/$CRAFT_DIR}"
LIVE_CRAFT="$ROOT_PATH/current${CRAFT_DIR:+/$CRAFT_DIR}"
export ROOT_PATH RELEASE_PATH

#######################################
# Dry run: show the resolved plan and exit without changing anything.
#######################################
if [ "$DRY_RUN" = "1" ]; then
  log "=== DRY RUN — no changes will be made ==="
  log "Repo:           $GIT_REPO"
  log "Branch/Ref:     ${GIT_REF:-${GIT_BRANCH:-<default>}}"
  log "Release:        $RELEASE_PATH"
  log "Craft dir:      ${CRAFT_DIR:-<root>}"
  log "Linked:         $LINKED_FILES $LINKED_DIRS"
  log "DB backup:      $RUN_BACKUP / Migrate: $RUN_MIGRATE / Project config: $RUN_PROJECT_CONFIG"
  log "Extra commands: ${EXTRA_CRAFT_COMMANDS:-<none>}"
  log "Keep releases:  $KEEP_RELEASES / Keep backups: $KEEP_BACKUPS"
  log "Clear opcache:  $CLEAR_OPCACHE / Restart PHP: ${RESTART_PHP:-<none>}"
  exit 0
fi

trap 'err "Deployment failed at line $LINENO."' ERR
log "=== Deploying release $CURRENT_RELEASE ==="

#######################################
# 1. Back up the database from the live release (if there is one).
#######################################
if [ "$RUN_BACKUP" = "1" ] && [ -d "$ROOT_PATH/current" ]; then
  if [ -f "$LIVE_CRAFT/craft" ]; then
    log "- Back up database"
    "$PHP_BIN" "$LIVE_CRAFT/craft" db/backup
  else
    warn "Skipping DB backup: craft not found at $LIVE_CRAFT/craft (check DEPLOY_CRAFT_DIR)"
  fi
fi

#######################################
# 2. Clone the repo/ref into a new release folder.
#######################################
[ -e "$RELEASE_PATH" ] && die "Release $CURRENT_RELEASE already exists — wait a second and retry."

clone_args=()
[ "$SUBMODULES" = "1" ] && clone_args+=(--recurse-submodules)
if [ -z "$GIT_REF" ]; then
  [ "$SHALLOW" = "1" ] && clone_args+=(--depth 1)
  [ -n "$GIT_BRANCH" ] && clone_args+=(--branch "$GIT_BRANCH")
fi
log "- Clone $GIT_REPO @ ${GIT_REF:-${GIT_BRANCH:-<default>}}"
git clone ${clone_args[@]+"${clone_args[@]}"} "$GIT_REPO" "$RELEASE_PATH"
if [ -n "$GIT_REF" ]; then
  git -C "$RELEASE_PATH" checkout --quiet "$GIT_REF"
fi

#######################################
# 3. Composer install. On failure, remove the broken release and abort.
#######################################
if ! composer_install "$RELEASE_CRAFT"; then
  err "Composer install failed — removing release $CURRENT_RELEASE"
  rm -rf "$RELEASE_PATH"
  exit 1
fi

#######################################
# 4. Symlink shared files and folders: <release>/<craft>/X -> <root>/shared/X.
#######################################
log "- Create shared symlinks"
for rel in $LINKED_FILES $LINKED_DIRS; do
  mkdir -p "$(dirname "$RELEASE_CRAFT/$rel")"
  ln -sfn "$ROOT_PATH/shared/$rel" "$RELEASE_CRAFT/$rel"
done

#######################################
# 5. Optional before hook (e.g. asset build), then Craft commands.
#######################################
if [ -n "$HOOK_BEFORE" ]; then
  log "- Run before hook: $HOOK_BEFORE"
  bash "$HOOK_BEFORE"
fi

[ -f "$RELEASE_CRAFT/craft" ] || die "Craft not found at $RELEASE_CRAFT/craft. Check DEPLOY_CRAFT_DIR — leave it empty if Craft lives in the repo root."
craft_update "$RELEASE_CRAFT"

IFS=';' read -ra extra_cmds <<< "$EXTRA_CRAFT_COMMANDS"
for cmd in ${extra_cmds[@]+"${extra_cmds[@]}"}; do
  [ -n "${cmd//[[:space:]]/}" ] || continue
  log "- Craft: $cmd"
  # shellcheck disable=SC2086
  "$PHP_BIN" "$RELEASE_CRAFT/craft" $cmd
done

#######################################
# 6. Switch `current` to the new release, then run the after hook.
#######################################
switch_current "$RELEASE_PATH"

if [ -n "$HOOK_AFTER" ]; then
  log "- Run after hook: $HOOK_AFTER"
  bash "$HOOK_AFTER"
fi

#######################################
# 7. Prune old releases and backups. Names are timestamps, so the glob's
#    alphabetical order is chronological; the oldest come first.
#######################################
prune() {
  local entries=("$1"/*) i
  for (( i = 0; i < ${#entries[@]} - $2; i++ )); do
    log "- Delete old $3 '$(basename "${entries[$i]}")'"
    rm -rf "${entries[$i]}"
  done
}
prune "$ROOT_PATH/releases" "$KEEP_RELEASES" "release"
prune "$ROOT_PATH/shared/storage/backups" "$KEEP_BACKUPS" "backup"

#######################################
# 8. Clear opcache (resets the symlink cache without restarting PHP)
#    via a one-shot script in the webroot.
#######################################
if [ "$CLEAR_OPCACHE" = "1" ]; then
  log "- Clear opcache"
  name="opcache-reset-$(date +%s)-${RANDOM}.php"
  file="$LIVE_CRAFT/web/$name"
  printf '<?php opcache_reset();\n' > "$file"
  curl -fsS "$ROOT_URL/$name" >/dev/null || warn "opcache reset request failed"
  rm -f "$file"
fi

#######################################
# 9. Restart PHP (optional; may cause a brief downtime).
#######################################
restart_php

log "=== Release $CURRENT_RELEASE deployed successfully ==="
