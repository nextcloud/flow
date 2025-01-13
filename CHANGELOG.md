<!--
  - SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: MIT
-->
# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [1.1.0 - 2025-01-14]

### Added

- Initialization of the `baseUrl` value in the Nextcloud Auth resource. #35
- Synchronization of `AA_VERSION` and `APP_VERSION` values in the Nextcloud Auth resource. #32

### Changed

- Python version updated from `3.10` to `3.12`. #33

### Fixed

- The PgSQL database now comes preinstalled in the Docker image instead of being installed during ExApp startup. #30

## [1.0.1 - 2024-10-10]

### Added

- More logging for faster problem diagnosis. [commit](https://github.com/nextcloud/flow/commit/e52c501144761e73b81b156423af034c191797aa)

### Fixed

- Warning "sudo: unable to resolve host" during container startup. #11
- Incorrect handling Windmill scripts with no modules in it. [commit](https://github.com/nextcloud/flow/commit/c8bf8309e85b14c2b36913469a38291f2c480b53)
- Unregister webhooks from the Nextcloud instance during ExApp disabling. #10
- Error when username(userid) contained a space. #13
- Updated NPM packages. #12

## [1.0.0 - 2024-09-13]

### Added

- First release
