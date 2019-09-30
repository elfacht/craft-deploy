#!/bin/bash
#
# Rollback script for the Craft CMS deployment script on
# staging/production servers.
# @see https://github.com/elfacht/craft-deploy
#
# v0.6.3.1
#
# - Rollback to second newest release folder.
# - This script Will not to any database work!
#
# @author
#   Martin Szymanski <martin@elfacht.com>
#   https://www.elfacht.com
#   https://github.com/elfacht
#
# @license MIT

#######################################
# Exit if any command fails
#######################################
set -e

#######################################
# Get constants from .env file:
# - Server root path to project
# - Restart PHP task (if symlinks are cached)
#######################################
read_var() {
    VAR=$(grep $1 $2 | xargs)
    IFS="=" read -ra VAR <<< "$VAR"
    echo ${VAR[1]}
}

ROOT_PATH=$(read_var DEPLOY_ROOT .env)
RESTART_PHP=$(read_var DEPLOY_RESTART_PHP .env)

#######################################
# Get the current release folder
#######################################
CURRENT_RELEASE=$(ls -td $ROOT_PATH/releases/* | head -1 | tail -n 1)

#######################################
# Get the second newest folder
#######################################
LAST_STABLE=$(ls -td $ROOT_PATH/releases/* | head -2 | tail -n 1)

#######################################
# Symlink current release
#######################################
cd $ROOT_PATH
printf -- "Symlink current release to $LAST_STABLE .."
DONE=0;
while [ $DONE -eq 0 ]; do
  ln -sfn $LAST_STABLE current

  if [ "$?" = "0" ]; then DONE=1; fi;
  printf -- '.';
  sleep 1;
done
printf -- ' DONE!\n';

#######################################
# Delete former release folder
#######################################
cd $ROOT_PATH
printf -- "Delete former release folder $CURRENT_RELEASE .."
DONE=0;
while [ $DONE -eq 0 ]; do
  rm -rf  $CURRENT_RELEASE

  if [ "$?" = "0" ]; then DONE=1; fi;
  printf -- '.';
  sleep 1;
done
printf -- ' DONE!\n';

#######################################
# Run composer and Craft scripts
#######################################
cd $ROOT_PATH/current
if composer install --no-interaction --prefer-dist --optimize-autoloader; then
  php craft migrate/all
  php craft project-config/sync
  cd $ROOT_PATH
fi

#######################################
# Restart PHP
#######################################
if ${RESTART_PHP}; then
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
