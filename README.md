# Craft CMS Deployment

A bash script for zero-downtime Craft CMS deployment to run on production servers. Inspired by the  Capistrano routine. **This script is still beta! Please use it very carefully!**

## Usage

- Copy the files to your project folder on the server.
- Run `chmod +x deploy.sh setup.sh` to set execution permissions.
- Run `./setup.sh` to create the initial folders and files.
- Upload `.env` into `shared/`.
- Upload `storage` folder into `shared/`.
- Upload `web/.htaccess` into `shared/web/`.
- Upload `web/cpresources` folder into `shared/web/`.
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

This script is still beta. Please use it carefully and not on large and heavy projects. Or do, whatever, your call.

## What does it do?

### setup.sh

Creates the necessary `releases`, `shared` and `shared/web` folders on the server. Run this script first.

### deploy.sh

- Runs `./craft backup/db` to create a database backup first.
- Creates a release folder in `releases` named by the current timestamp, i.e. `20190623170859`.
- Clones your git repo into this folder.
- Runs `composer install` to install Craft CMS.
- Creates symlinks for shared folders and files.
- Runs `./craft migrate/all` and `./craft project-config/sync`.
- Creates a symlink from the `current` folder to the newest release.
- Deletes old releases and keeps max. `[DEPLOY_KEEP_RELEASES]` releases.
- Deletes oldest backup and keeps max. `[DEPLOY_KEEP_BACKUPS]` backups.
- Restarts PHP to delete symlink cache (optional)

### rollback.sh

Creates a symlink from `current/` to the second newest release folder (i.e. the former release), deletes the current release folder afterwards and runs `composer install`, `./craft migrate/all` and `./craft project-config/sync`. That's all. No further database actions.

**If you run a major update with significant database migrations you do it on your own responsibility!**

### gitlab-webhook-push.php

Optional webhook script to run the bash scripts and creates a logfile. You can use your own scripts of course.

## Why should I use it?

When you don't want to spend money on deployment services and tools like Capistrano are just too much to set up for smaller projects.

## Roadmap

- ~~Add `.env` for better config handling.~~
- ~~Delete releases folder if an error occurs during deployment.~~
- ~~Delete not only the oldest release folder, but multiple release folders if there's more than 5 folders (occurs if an deployment fails).~~ (Corrupt folders will be removed if installation fails)
- ~~Integrate `update.sh` scripts into `deploy.sh` and/or create flags.~~

## License

Itsa [MIT](LICENSE.md)!
