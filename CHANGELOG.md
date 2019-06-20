# Changelog

Things change, people change, everything changes.

## Unreleased
### Changed
- Changed path in instructions step (README).

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