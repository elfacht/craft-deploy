#!/bin/bash
#
# Craft CMS deployment script on staging/production servers.
# @see https://github.com/elfacht/craft-deploy
#
# - Creating a release folder
# - Cloning the git repo.
# - Running `composer install`
# - Creating symlinks to shared folders and files.
# - Symlink on current folder to newest release.
# - Deleting old releases (keeping max. 5)
#
# @author
#   Martin Szymanski <martin@elfacht.com>
#   https://www.elfacht.com
#   https://github.com/elfacht
#
# @license MIT

#######################################
# Set constants:
# - Git repo URL
# - Assets directory name (web/[ASSETS_DIR])
#######################################
GIT_REPO="[GIT_REPO_URL]"
ASSETS_DIR="[ASSETS_DIR]"


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
# Current release number
#######################################
CURRENT_RELEASE=$(timestamp)

#######################################
# Backup database
#######################################
if [ -d "./current/" ]
then
  php current/craft backup/db
fi

#######################################
# Create release directory and
# clone git repo
#######################################
if [ -d "./releases/" ]
then
  ### Make current release dir
  cd "./releases"
  mkdir $CURRENT_RELEASE && cd "$_"
  echo "Created release $CURRENT_RELEASE folder."

  ### Clone repo
  git clone $GIT_REPO .
else
  exit 1
fi

#######################################
# Run composer install and
# create symlinks
#######################################
if composer install
then
  ### Create symlinks
  printf -- "- Create symlinks .."
  DONE=0;
  while [ $DONE -eq 0 ]; do
    ln -sfn "../../shared/.env"
    ln -sfn "../../shared/storage" .
    cd web && ln -sfn "../../../shared/web/.htaccess"
    ln -sfn "../../../shared/web/$ASSETS_DIR"
    ln -sfn "../../../shared/web/cpresources"

    if [ "$?" = "0" ]; then DONE=1; fi;
    printf -- '.';
    sleep 1;
  done
  printf -- ' DONE!\n';

  ### Symlink current release
  cd "../../../"
  printf -- "- Create release $CURRENT_RELEASE .."
  DONE=0;
  while [ $DONE -eq 0 ]; do
    ln -sfn "releases/$CURRENT_RELEASE/" current

    if [ "$?" = "0" ]; then DONE=1; fi;
    printf -- '.';
    sleep 1;
  done
  printf -- ' DONE!\n';

  #######################################
  # Kepp max. 5 releases,
  # delete old release directories
  #######################################
  COUNT=`/bin/ls -l releases | /usr/bin/wc -l`
  MINDIRS=6 # Keep 5 releases

  if [[ $COUNT -gt $MINDIRS ]]
  then
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
else

  #######################################
  # Delete release folder if composer fails.
  #######################################
  cd "../"
  rm -rf $CURRENT_RELEASE
fi








