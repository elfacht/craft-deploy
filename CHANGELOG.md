# Changelog

Things change, people change, everything changes.

## [0.7.0](https://github.com/elfacht/craft-deploy/compare/0.6.4...0.7.0) - 2026-06-26
### Added
- `lib.sh` with shared functions (config loading, logging, pruning, hooks) and a single source of truth for the version.
- Central logging: every step is timestamped and written to `deploy.log`.
- Configurable shared symlinks via `DEPLOY_LINKED_FILES` / `DEPLOY_LINKED_DIRS`.
- Configurable binaries: `DEPLOY_PHP_BIN`, `DEPLOY_COMPOSER_BIN`, `DEPLOY_COMPOSER_FLAGS`.
- Toggleable Craft steps: `DEPLOY_RUN_BACKUP`, `DEPLOY_RUN_MIGRATE`, `DEPLOY_RUN_PROJECT_CONFIG`, plus extra `DEPLOY_CRAFT_COMMANDS`.
- Deploy by ref and faster clones: `DEPLOY_REF`, `DEPLOY_SHALLOW`, `DEPLOY_SUBMODULES`.
- Before/after hooks: `DEPLOY_HOOK_BEFORE`, `DEPLOY_HOOK_AFTER`.
- CLI flags: `--dry-run`, `--branch`, `--ref`, `--no-backup`, `--env`, `--verbose`, `--version`, `--help`.
### Changed
- `rollback.sh` now uses `project-config/apply` (was the deprecated `project-config/sync`).
- Release/backup pruning rewritten to be deterministic and to remove all entries beyond the keep count.
### Fixed
- Robust `.env` parsing — no longer breaks on commented lines, partial-name matches or values containing `=`.
- Validation of required config and `set -euo pipefail` prevent dangerous `cd`/`rm` on empty paths.
- Removed the dead `while DONE` retry loops and their artificial `sleep` delays.
- Composer-failure cleanup now removes the correct release folder for subfolder installs.
- Opcache reset script is guaranteed to be removed from the webroot and uses `curl -fsS`.
- `setup.sh` now copies `.env.example` to `.env` instead of the inverted/destructive `mv`.

## [0.6.4](https://github.com/elfacht/craft-deploy/compare/0.6.3.1...0.6.4) - 2020-12-29
### Changed
- Use `project-config/apply` for Craft CMS 3.5+

## [0.6.3.1](https://github.com/elfacht/craft-deploy/compare/0.6.3...0.6.3.1) - 2019-09-30
### Added
- Added `DEPLOY_ASSETS_DIR` after deleting it accidentally.

## [0.6.3](https://github.com/elfacht/craft-deploy/compare/0.6.2...0.6.3) - 2019-09-30
### Added
- Added [rollback.sh](rollback.sh) for rollbacks.
- Added `DEPLOY_URL` option.
- Added `DEPLOY_CLEAR_OPCACHE` option.
- Added function to clear `opcache` to reset symlink cache without restarting PHP.

## [0.6.2](https://github.com/elfacht/craft-deploy/compare/0.6.1...0.6.2) - 2019-07-22
### Added
- Added `DEPLOY_KEEP_RELEASES` constant.
- Added `DEPLOY_BRANCH` constant to clone specific branch.
- `setup.sh` will now create an empty log file.
- `setup.sh` will now rename `.env.example` to `.env`.

## [0.6.1](https://github.com/elfacht/craft-deploy/compare/0.6.0...0.6.1) - 2019-07-15
### Added
- Added `DEPLOY_KEEP_BACKUPS` option and function.

## [0.6.0](https://github.com/elfacht/craft-deploy/compare/0.5.0...0.6.0) - 2019-07-08
### Added
- Added `.env` environment to separate config from code.

## [0.5.0](https://github.com/elfacht/craft-deploy/compare/0.4.1...0.5.0) - 2019-07-03
### Added
- Added `ROOT_PATH` constant for absolute server paths. **REQUIRED! PLEASE UPDATE!**
- Added `RESTART_PHP` constant for optional PHP restart command, in case symlinks are cached.

## [0.4.1](https://github.com/elfacht/craft-deploy/compare/0.4.0...0.4.1) - 2019-06-23
### Added
- Added bug warning.
- Added version in comments.

## [0.4.0](https://github.com/elfacht/craft-deploy/compare/0.3.1...0.4.0) - 2019-06-22
### Added
- Added `err` timestamp.
### Changed
- Changed path in instructions step (README).
### Fixed
- Removed duplicate code.
- Fixed bash formatting.

## [0.3.1](https://github.com/elfacht/craft-deploy/compare/0.3.0...0.3.1) - 2019-06-20
### Added
- Added missing step to usage.

## [0.3.0](https://github.com/elfacht/craft-deploy/compare/0.2.0...0.3.0) - 2019-06-20
### Added
- Added `set -e` to exit if any command fails.
### Changed
- Moved `./craft migrate/all` and `./craft project-config/sync` to `composer install` statement.

## [0.2.0](https://github.com/elfacht/craft-deploy/compare/0.1.2...0.2.0) - 2019-06-19
### Changed
- Moved `./craft migrate/all` and `./craft project-config/sync` to `deploy.sh`.
### Removed
- Removed `update.sh` as no longer needed.

## [0.1.2](https://github.com/elfacht/craft-deploy/compare/0.1.1...0.1.2) - 2019-06-19
### Added
- Added task to delete current release folder if `composer install` fails.
### Changed
- Moved function to delete old releases into `composer install` statement.

## [0.1.1](https://github.com/elfacht/craft-deploy/compare/0.1.0...0.1.1) - 2019-06-18
## Added
- Added reasons why to use this script to README.

## 0.1.0 - 2019-06-18
### Added
- Initial release
