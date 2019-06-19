# Craft CMS Deployment

A bash script for zero-downtime Craft CMS deployment to run on production servers. Inspired by the  Capistrano routine. **This script is still beta! Please use it very carefully!**

## Usage

- Copy the files to your project folde on the server.
- Replace `[GIT_REPO_URL]` and `[ASSETS_DIR]` in [deploy.sh](deploy.sh) with your credentials.
- Run `chmod +x deploy.sh setup.sh update.sh` to set execution permissions.
- Run `./setup.sh` to create the initial folders.
- Upload `.env` into `shared/`.
- Upload `web/.htaccess` into `shared/web/`.
- Upload `storage`folder into `shared/`.
- Upload your `[ASSETS_DIR]` folder and `web/cpresources` folder into `shared/web/`.
- Setup a [webhook](https://docs.gitlab.com/ee/user/project/integrations/webhooks.html) to call the scripts or run `./deploy.sh` manually.

## .gitignore

Following files and folders must be added to `.gitignore` to make the symlinks work:

- .env
- storage
- web/[ASSETS_DIR]
- web/cpresources
- web/.htaccess

## Important

This script is still beta. Please use it carefully and not on large and heavy prjects. Or do, whatever, your call.

## What does it do?

### setup.sh

Creates the necessary `releases`, `shared` and `shared/web` folders on the server. Run this script first.

### deploy.sh

- Runs `./craft backup/db` to create a database backup first.
- Creates a release folder in `releases` named by the current timestamp, i.e. `20190623170859`.
- Clones your git repo into this folder.
- Runs `composer install` to install Craft CMS.
- Creates symlinks for shared folders and files.
- Creates a symlink from the `current` folder to the newest release.
- Deletes old releases and keeps max. 5 releases.

### update.sh

Runs Craft CMS composer scripts `./craft migrate/all` and `./craft project-config/sync`.

### gitlab-webhook-push.php

Optional webhook script to run the bash scripts and creates a logfile. You can use your own scripts of course.

## What does it not do?

This script doesn't do rollbacks. Although it doesn't re-link the `current` folder when the script throws an error. If an error occurs the previous release will still be the current one.

## Why should I use it?

When you don't want to spend money on deployment services and tools like Capistrano are just too much to set up for smaller projects.

## Roadmap

- Delete releases folder if an error occurs during deployment.
- Delete not only the oldest release folder, but multiple release folders if there's more than 5 folders (occurs if an deployment fails).
- Integrate `update.sh` scripts into `deploy.sh` and/or create flags.


## License

Itsa [MIT](LICENSE.md)!