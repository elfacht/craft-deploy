# Changelog

Things change, people change, everything changes.

## Unreleased
### Added
- Added `DEPLOY_KEEP_RELEASES` constant.
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
