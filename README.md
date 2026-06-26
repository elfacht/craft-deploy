# Craft CMS Deployment

A bash script for zero-downtime Craft CMS deployment on production/staging
servers. Inspired by the Capistrano routine. **Still beta — use it carefully!**

## Usage

- Copy the files into your project folder on the server.
- Run `chmod +x deploy.sh rollback.sh setup.sh` to set execution permissions.
- Run `./setup.sh` to create the initial folders and the `.env` file.
- Edit `.env` (at minimum set `DEPLOY_REPO` and `DEPLOY_ROOT`).
- Upload your shared files into `shared/` (see below).
- Deploy with `./deploy.sh`.

### Shared files

These live outside the releases and are symlinked into every release. Upload
them into `shared/` mirroring their path in the project:

- `.env` → `shared/.env`
- `storage/` → `shared/storage/`
- `web/.htaccess` → `shared/web/.htaccess`
- `web/[ASSETS_DIR]/` → `shared/web/[ASSETS_DIR]/`
- `web/cpresources/` → `shared/web/cpresources/`

Which files/folders get linked is configurable via `DEPLOY_LINKED_FILES` and
`DEPLOY_LINKED_DIRS` — the defaults reproduce the list above.

### .gitignore (in your Craft project)

These must be git-ignored so the symlinks work:

```
.env
storage
web/[ASSETS_DIR]
web/cpresources
web/.htaccess
```

## CLI options

`deploy.sh` accepts:

```
--env <path>     Config file path (default: ./.env next to deploy.sh)
--branch <name>  Override DEPLOY_BRANCH for this run
--ref <ref>      Deploy a specific tag/commit/branch
--no-backup      Skip the database backup for this run
--dry-run        Validate config and print the plan, change nothing
--verbose        Shell tracing (set -x)
--version        Print version
-h, --help       Show help
```

Start with `./deploy.sh --dry-run` to verify your configuration safely.

## What does it do?

### setup.sh

Creates the `releases`, `shared`, `shared/web`, `shared/storage/backups`
folders and the `deploy.log` file, and copies `.env.example` to `.env`
(without overwriting an existing one). Run this first.

### deploy.sh

1. Backs up the database (`craft db/backup`) — optional.
2. Creates a timestamped release folder in `releases/` and clones the repo/ref.
3. Runs `composer install`; on failure the broken release is removed.
4. Creates the configured shared symlinks.
5. Runs an optional `before` hook, then `craft migrate/all`,
   `craft project-config/apply`, and any extra commands — each toggleable.
6. Atomically switches the `current` symlink to the new release.
7. Runs an optional `after` hook.
8. Prunes releases/backups down to `DEPLOY_KEEP_RELEASES` / `DEPLOY_KEEP_BACKUPS`.
9. Clears opcache and/or restarts PHP — optional.

All steps are timestamped and logged to `deploy.log`.

### rollback.sh

Switches `current` back to the previous release, deletes the rolled-back
release, then re-runs `composer install`, `craft migrate/all` and
`craft project-config/apply`. **No database restore happens** — major
migrations are rolled back at your own risk.

### lib.sh

Shared functions (config loading, logging, pruning, hooks) and the single
source of truth for the version. Sourced by the other scripts.

## Configuration

All options live in `.env`; see [.env.example](.env.example) for the full,
documented list. Only `DEPLOY_REPO` and `DEPLOY_ROOT` are required.

## Why should I use it?

When you don't want to pay for a deployment service and Capistrano is too
much to set up for smaller projects.

## Roadmap

- [ ] Add DB rollback script
- [ ] Optional smoke test + auto-rollback after switching `current`
- [ ] Deploy notifications (webhook)
- [ ] Concurrency lock against parallel deploys
- [x] Configurable shared symlinks, binaries and Craft commands
- [x] CLI flags (`--dry-run`, `--branch`, `--ref`, `--no-backup`)
- [x] Robust `.env` parsing, central logging and shared library
- [x] Set project folder name in `.env`
- [x] Delete release folder if an error occurs during deployment

## License

Itsa [MIT](LICENSE.md)!
