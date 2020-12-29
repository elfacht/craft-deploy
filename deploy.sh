#!/bin/bash
#
# Craft CMS deployment script on staging/production servers.
# @see https://github.com/elfacht/craft-deploy
#
# v0.6.4
#
# - Creating a release folder
# - Cloning the git repo.
# - Creating symlinks to shared folders and files.
# - Symlink on current folder to newest release.
# - Deleting old releases and backups
#
# @author
#   Martin Szymanski <martin@elfacht.com>
#   https://www.elfacht.com
#   https://github.com/elfacht
#
# @license MIT

#######################################
# Get constants from .env file:
# - Git repo URL
# - Git repo branch
# - Server root path to project
# - Assets directory name (web/[ASSETS_DIR])
# - Restart PHP task (if symlinks are cached)
# - Releases to keep
# - Backups to keep
#######################################
read_var() {
    VAR=$(grep $1 $2 | xargs)
    IFS="=" read -ra VAR <<< "$VAR"
    echo ${VAR[1]}
}

GIT_REPO=$(read_var DEPLOY_REPO .env)
GIT_BRANCH=$(read_var DEPLOY_BRANCH .env)
ROOT_PATH=$(read_var DEPLOY_ROOT .env)
ROOT_URL=$(read_var DEPLOY_URL .env)
ASSETS_DIR=$(read_var DEPLOY_ASSETS_DIR .env)
CLEAR_OPCACHE=$(read_var DEPLOY_CLEAR_OPCACHE .env)
RESTART_PHP=$(read_var DEPLOY_RESTART_PHP .env)
KEEP_RELEASES=$(read_var DEPLOY_KEEP_RELEASES .env)
KEEP_BACKUPS=$(read_var DEPLOY_KEEP_BACKUPS .env)

#######################################
# Set git branch variable
#######################################
if [ -z "$GIT_BRANCH" ]; then
  BRANCH=""
else
  BRANCH="--branch $GIT_BRANCH"
fi

#######################################
# Exit if any command fails
#######################################
set -e

#######################################
# Set timestamp as realease folder name.
# Example:
#   201903271201
# Arguments:
#   None
# Returns:
#   Sting
#######################################
timestamp() {
  date +"%Y%m%d%H%M%S"
}

#######################################
# Error timestamp
#######################################
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

#######################################
# Current release number
#######################################
CURRENT_RELEASE=$(timestamp)

#######################################
# Backup database
#######################################
if [ -d "./current/" ]; then
  php current/craft backup/db
fi

#######################################
# Create release directory and
# clone git repo
#######################################
if [ -d "./releases/" ]; then
  ### Make current release dir
  cd "./releases"
  mkdir $CURRENT_RELEASE && cd "$_"
  echo "Created release $CURRENT_RELEASE folder."

  ### Clone repo
  git clone $GIT_REPO $BRANCH .
else
  exit 1
fi

#######################################
# Run composer install and
# create symlinks
#######################################
if composer install --no-interaction --prefer-dist --optimize-autoloader; then
  #######################################
  # Create symlinks of shared files
  # and folders.
  #######################################
  printf -- "- Create symlinks .."
  DONE=0;
  while [ $DONE -eq 0 ]; do
    ln -sfn "$ROOT_PATH/shared/.env"
    ln -sfn "$ROOT_PATH/shared/storage" .
    cd web && ln -sfn "$ROOT_PATH/shared/web/.htaccess"
    ln -sfn "$ROOT_PATH/shared/web/$ASSETS_DIR"
    ln -sfn "$ROOT_PATH/shared/web/cpresources"

    if [ "$?" = "0" ]; then DONE=1; fi;
    printf -- '.';
    sleep 1;
  done
  printf -- ' DONE!\n';

  #######################################
  # Run Craft CMS migration and project
  # sync command.
  #######################################
  php ../craft migrate/all
  php ../craft project-config/apply

  #######################################
  # Symlink current release
  #######################################
  cd $ROOT_PATH
  printf -- "- Create release $CURRENT_RELEASE .."
  DONE=0;
  while [ $DONE -eq 0 ]; do
    ln -sfn "$ROOT_PATH/releases/$CURRENT_RELEASE/" current

    if [ "$?" = "0" ]; then DONE=1; fi;
    printf -- '.';
    sleep 1;
  done
  printf -- ' DONE!\n';

  #######################################
  # Kepp max. 5 releases,
  # delete old release directories
  #######################################
  COUNT=`/bin/ls -l $ROOT_PATH/releases | /usr/bin/wc -l`
  MINDIRS=$KEEP_RELEASES+1 # Keep XX releases

  if [[ $COUNT -gt $MINDIRS ]]; then
    OLDEST_RELEASE=$(ls -tr releases/* | head -1)
    printf -- "- Delete oldest release '$OLDEST_RELEASE' .."

    DONE=0;
    while [ $DONE -eq 0 ]; do
      rm -rf $(find releases/*/ -maxdepth 1 -type d | sort -r | tail -n 1 | sed 's/[0-9]*\.[0-9]*\t//')

      if [ "$?" = "0" ]; then DONE=1; fi;
      printf -- '.';
      sleep 1;
    done

    printf -- ' DONE!\n';
  fi

  #######################################
  # Kepp max. X backups,
  # delete oldest backup
  #######################################
  COUNT=`/bin/ls -l $ROOT_PATH/shared/storage/backups | /usr/bin/wc -l`
  MINBACKUPS=$KEEP_BACKUPS+1 # Keep X releases

  if [[ $COUNT -gt $MINBACKUPS ]]; then
    OLDEST_BACKUP=$(ls -tr $ROOT_PATH/shared/storage/backups/* | head -1)
    printf -- "- Delete oldest backup '$OLDEST_BACKUP' .."

    DONE=0;
    while [ $DONE -eq 0 ]; do
      rm -rf $OLDEST_BACKUP

      if [ "$?" = "0" ]; then DONE=1; fi;
      printf -- '.';
      sleep 1;
    done

    printf -- ' DONE!\n';
  fi

  #######################################
  # Clear opcache
  #######################################
  if [[ $CLEAR_OPCACHE -eq 1 ]]; then
    printf -- "- Clear opcache .."

    DONE=0;
    while [ $DONE -eq 0 ]; do
      WEBDIR=${ROOT_PATH}/current/web/
      RANDOM_NAME=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13)
      echo "<?php opcache_reset(); ?>" > ${WEBDIR}${RANDOM_NAME}.php
      curl ${ROOT_URL}/${RANDOM_NAME}.php
      rm ${WEBDIR}${RANDOM_NAME}.php

      if [ "$?" = "0" ]; then DONE=1; fi;
      printf -- '.';
      sleep 1;
    done

    printf -- ' DONE!\n';
  fi

  #######################################
  # Restart PHP
  #######################################
  if [[ -z $RESTART_PHP ]]; then
    echo ""
  else
    printf -- "- Restart PHP .."

    DONE=0;
    while [ $DONE -eq 0 ]; do
      ${RESTART_PHP}

      if [ "$?" = "0" ]; then DONE=1; fi;
      printf -- '.';
      sleep 1;
    done

    printf -- ' DONE!\n';
  fi
else

  #######################################
  # Delete release folder if composer fails.
  #######################################
  cd "../"
  rm -rf $CURRENT_RELEASE
fi
