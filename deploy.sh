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

#######################################
# Resolve script directory and load shared library.
#######################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

#######################################
# Usage / help.
#######################################
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
# Parse CLI flags. CLI values override .env where applicable.
#######################################
ENV_FILE="$SCRIPT_DIR/.env"
CLI_BRANCH=""
CLI_REF=""
CLI_NO_BACKUP=0

while [ $# -gt 0 ]; do
  case "$1" in
    --env)        ENV_FILE="${2:-}"; shift 2 ;;
    --branch)     CLI_BRANCH="${2:-}"; shift 2 ;;
    --ref)        CLI_REF="${2:-}"; shift 2 ;;
    --no-backup)  CLI_NO_BACKUP=1; shift ;;
    --dry-run)    DRY_RUN=1; shift ;;
    --verbose)    set -x; shift ;;
    --version)    echo "$CRAFT_DEPLOY_VERSION"; exit 0 ;;
    -h|--help)    usage; exit 0 ;;
    *)            err "Unknown option: $1"; usage; exit 1 ;;
  esac
done

#######################################
# Load configuration.
#######################################
load_env "$ENV_FILE"

# Required.
GIT_REPO="${DEPLOY_REPO:-}"
ROOT_PATH="${DEPLOY_ROOT:-}"

# Optional with sensible, backward-compatible defaults.
GIT_BRANCH="${CLI_BRANCH:-${DEPLOY_BRANCH:-}}"
GIT_REF="${CLI_REF:-${DEPLOY_REF:-}}"
CRAFT_DIR="${DEPLOY_CRAFT_DIR:-}"
ASSETS_DIR="${DEPLOY_ASSETS_DIR:-uploads}"
ROOT_URL="${DEPLOY_URL:-}"
CLEAR_OPCACHE="${DEPLOY_CLEAR_OPCACHE:-0}"
RESTART_PHP="${DEPLOY_RESTART_PHP:-}"
KEEP_RELEASES="${DEPLOY_KEEP_RELEASES:-5}"
KEEP_BACKUPS="${DEPLOY_KEEP_BACKUPS:-5}"

# Flexibility options (all additive).
PHP_BIN="${DEPLOY_PHP_BIN:-php}"
COMPOSER_BIN="${DEPLOY_COMPOSER_BIN:-composer}"
COMPOSER_FLAGS="${DEPLOY_COMPOSER_FLAGS:---no-interaction --prefer-dist --optimize-autoloader}"
LINKED_FILES="${DEPLOY_LINKED_FILES:-.env web/.htaccess}"
LINKED_DIRS="${DEPLOY_LINKED_DIRS:-storage web/${ASSETS_DIR} web/cpresources}"
RUN_BACKUP="${DEPLOY_RUN_BACKUP:-1}"
RUN_MIGRATE="${DEPLOY_RUN_MIGRATE:-1}"
RUN_PROJECT_CONFIG="${DEPLOY_RUN_PROJECT_CONFIG:-1}"
EXTRA_CRAFT_COMMANDS="${DEPLOY_CRAFT_COMMANDS:-}"
SHALLOW="${DEPLOY_SHALLOW:-0}"
SUBMODULES="${DEPLOY_SUBMODULES:-0}"
HOOK_BEFORE="${DEPLOY_HOOK_BEFORE:-}"
HOOK_AFTER="${DEPLOY_HOOK_AFTER:-}"

[ "$CLI_NO_BACKUP" = "1" ] && RUN_BACKUP=0

#######################################
# Validate required configuration before touching anything.
#######################################
require_var DEPLOY_REPO DEPLOY_ROOT
[ -d "$ROOT_PATH" ] || die "DEPLOY_ROOT does not exist: $ROOT_PATH"
if [ "$CLEAR_OPCACHE" = "1" ] && [ -z "$ROOT_URL" ]; then
  die "DEPLOY_CLEAR_OPCACHE is enabled but DEPLOY_URL is empty."
fi

#######################################
# Logging + error trap. Now that ROOT_PATH is known, log into it.
#######################################
LOG_FILE="$ROOT_PATH/deploy.log"
trap 'err "Deployment failed at line $LINENO."' ERR

#######################################
# Derived paths.
#######################################
CURRENT_RELEASE="$(date +'%Y%m%d%H%M%S')"
RELEASE_PATH="$ROOT_PATH/releases/$CURRENT_RELEASE"
RELEASE_CRAFT="$RELEASE_PATH${CRAFT_DIR:+/$CRAFT_DIR}"
BACKUPS_DIR="$ROOT_PATH/shared/storage/backups"
export ROOT_PATH RELEASE_PATH

#######################################
# Dry run: show the resolved plan and exit without changing anything.
#######################################
if [ "$DRY_RUN" = "1" ]; then
  log "=== DRY RUN — no changes will be made ==="
  log "Repo:           $GIT_REPO"
  log "Branch/Ref:     ${GIT_REF:-${GIT_BRANCH:-<default>}}"
  log "Root:           $ROOT_PATH"
  log "Release:        $RELEASE_PATH"
  log "Craft dir:      ${CRAFT_DIR:-<root>}"
  log "Linked files:   $LINKED_FILES"
  log "Linked dirs:    $LINKED_DIRS"
  log "DB backup:      $([ "$RUN_BACKUP" = 1 ] && echo yes || echo no)"
  log "Migrate:        $([ "$RUN_MIGRATE" = 1 ] && echo yes || echo no)"
  log "Project config: $([ "$RUN_PROJECT_CONFIG" = 1 ] && echo yes || echo no)"
  log "Extra commands: ${EXTRA_CRAFT_COMMANDS:-<none>}"
  log "Keep releases:  $KEEP_RELEASES / Keep backups: $KEEP_BACKUPS"
  log "Clear opcache:  $CLEAR_OPCACHE / Restart PHP: ${RESTART_PHP:-<none>}"
  exit 0
fi

log "=== Deploying release $CURRENT_RELEASE ==="

#######################################
# 1. Back up the database from the live release (if there is one).
#######################################
if [ "$RUN_BACKUP" = "1" ] && [ -d "$ROOT_PATH/current" ]; then
  log "- Back up database"
  run "$PHP_BIN" "$ROOT_PATH/current${CRAFT_DIR:+/$CRAFT_DIR}/craft" db/backup
fi

#######################################
# 2. Create the release directory and clone the repo/ref.
#######################################
[ -d "$ROOT_PATH/releases" ] || die "Missing releases directory. Run ./setup.sh first."
[ -e "$RELEASE_PATH" ] && die "Release $CURRENT_RELEASE already exists — wait a second and retry."
run mkdir -p "$RELEASE_PATH"
log "- Created release folder $CURRENT_RELEASE"

clone_args=()
[ "$SUBMODULES" = "1" ] && clone_args+=(--recurse-submodules)
if [ -n "$GIT_REF" ]; then
  # Tag/commit/branch: full clone, then checkout the ref.
  log "- Clone $GIT_REPO @ $GIT_REF"
  run git clone ${clone_args[@]+"${clone_args[@]}"} "$GIT_REPO" "$RELEASE_PATH"
  run git -C "$RELEASE_PATH" checkout --quiet "$GIT_REF"
else
  [ "$SHALLOW" = "1" ] && clone_args+=(--depth 1)
  [ -n "$GIT_BRANCH" ] && clone_args+=(--branch "$GIT_BRANCH")
  log "- Clone $GIT_REPO ${GIT_BRANCH:+(branch $GIT_BRANCH)}"
  run git clone ${clone_args[@]+"${clone_args[@]}"} "$GIT_REPO" "$RELEASE_PATH"
fi

#######################################
# 3. Composer install. On failure, remove the broken release and abort.
#######################################
log "- Composer install"
# COMPOSER_FLAGS is intentionally word-split into separate arguments.
# shellcheck disable=SC2086
if ! ( cd "$RELEASE_CRAFT" && run "$COMPOSER_BIN" install $COMPOSER_FLAGS ); then
  err "Composer install failed — removing release $CURRENT_RELEASE"
  rm -rf "$RELEASE_PATH"
  exit 1
fi

#######################################
# 4. Create symlinks to shared files and folders.
#    Each entry X is linked at <release>/<craft>/X -> <root>/shared/X.
#######################################
log "- Create shared symlinks"
link_shared() {
  local rel="$1"
  local target="$RELEASE_CRAFT/$rel"
  run mkdir -p "$(dirname "$target")"
  run ln -sfn "$ROOT_PATH/shared/$rel" "$target"
}
read -ra _files <<< "$LINKED_FILES"
read -ra _dirs  <<< "$LINKED_DIRS"
for f in ${_files[@]+"${_files[@]}"}; do [ -n "$f" ] && link_shared "$f"; done
for d in ${_dirs[@]+"${_dirs[@]}"};  do [ -n "$d" ] && link_shared "$d"; done

#######################################
# 5. Optional pre-switch hook (e.g. asset build) and Craft commands.
#######################################
run_hook "$HOOK_BEFORE" "before"

CRAFT_BIN="$RELEASE_CRAFT/craft"
if [ "$RUN_MIGRATE" = "1" ]; then
  log "- Run migrations"
  run "$PHP_BIN" "$CRAFT_BIN" migrate/all
fi
if [ "$RUN_PROJECT_CONFIG" = "1" ]; then
  log "- Apply project config"
  run "$PHP_BIN" "$CRAFT_BIN" project-config/apply
fi
if [ -n "$EXTRA_CRAFT_COMMANDS" ]; then
  IFS=';' read -ra _cmds <<< "$EXTRA_CRAFT_COMMANDS"
  for cmd in ${_cmds[@]+"${_cmds[@]}"}; do
    cmd="$(echo "$cmd" | xargs)"   # trim
    [ -n "$cmd" ] || continue
    log "- Craft: $cmd"
    # shellcheck disable=SC2086
    run "$PHP_BIN" "$CRAFT_BIN" $cmd
  done
fi

#######################################
# 6. Atomically switch `current` to the new release.
#######################################
log "- Switch current -> $CURRENT_RELEASE"
run ln -sfn "$RELEASE_PATH" "$ROOT_PATH/current"

#######################################
# 7. Post-switch hook (e.g. cache warmup, notifications).
#######################################
run_hook "$HOOK_AFTER" "after"

#######################################
# 8. Prune old releases and backups.
#######################################
prune_old "$ROOT_PATH/releases" "$KEEP_RELEASES" "release"
prune_old "$BACKUPS_DIR" "$KEEP_BACKUPS" "backup"

#######################################
# 9. Clear opcache (resets the symlink cache without restarting PHP).
#    Writes a one-shot script into the webroot and guarantees its removal.
#######################################
if [ "$CLEAR_OPCACHE" = "1" ]; then
  log "- Clear opcache"
  webdir="$ROOT_PATH/current${CRAFT_DIR:+/$CRAFT_DIR}/web"
  name="opcache-reset-$(date +%s)-${RANDOM}.php"
  file="$webdir/$name"
  printf '<?php opcache_reset();\n' > "$file"
  # Guarantee the one-shot script is removed even if the script dies here.
  trap 'rm -f "$file" 2>/dev/null' EXIT
  curl -fsS "$ROOT_URL/$name" >/dev/null || warn "opcache reset request failed"
  rm -f "$file"
  trap - EXIT
fi

#######################################
# 10. Restart PHP (optional; may cause a brief downtime).
#######################################
if [ -n "$RESTART_PHP" ]; then
  log "- Restart PHP"
  # RESTART_PHP is a command line and is intentionally word-split.
  # shellcheck disable=SC2086
  run $RESTART_PHP
fi

log "=== Release $CURRENT_RELEASE deployed successfully ==="
