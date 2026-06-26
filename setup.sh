#!/bin/bash
#
# Initial setup for craft-deploy.
# Creates the directory structure and the config file on the server.
# @see https://github.com/elfacht/craft-deploy
#
# @author  Martin Szymanski <martin@elfacht.com>
# @license MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

cd "$SCRIPT_DIR"

#######################################
# Releases directory.
#######################################
if [ ! -d "./releases" ]; then
  log "Create releases folder."
  mkdir -p releases
fi

#######################################
# Shared directory structure.
#######################################
if [ ! -d "./shared" ]; then
  log "Create shared folder."
  mkdir -p shared/web shared/storage/backups
fi

#######################################
# Empty log file.
#######################################
if [ ! -f "./deploy.log" ]; then
  log "Create empty log file."
  touch deploy.log
fi

#######################################
# Config file. Copy the example without destroying it,
# and only when no .env exists yet.
#######################################
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
  log "Create .env from .env.example — edit it before deploying."
  cp .env.example .env
fi

log "Setup complete. Next: edit .env, then upload your shared files into ./shared."
