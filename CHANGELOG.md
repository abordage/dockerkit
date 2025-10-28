# [2.13.0](https://github.com/abordage/dockerkit/compare/v2.12.0...v2.13.0) (2025-10-28)


### Features

* **tools:** improve dk.sh with DockerKit root detection and nested directory support ([505e74a](https://github.com/abordage/dockerkit/commit/505e74ad04d2d274545eeb9e0eee2c28d9050ace))

# [2.12.0](https://github.com/abordage/dockerkit/compare/v2.11.1...v2.12.0) (2025-10-21)


### Features

* **docker:** add Elasticsearch setting to disable name requirement for destructive actions ([088bb84](https://github.com/abordage/dockerkit/commit/088bb84984e96fc5b51af1c9cf9573d83fedde27))
* **docker:** add support for custom Debian mirrors in builds ([a96cce9](https://github.com/abordage/dockerkit/commit/a96cce97128863762a0d11f1d50836a7e52c6bf3))
* **docker:** enhance rebuild process for workspace and php-fpm images ([21cbaf7](https://github.com/abordage/dockerkit/commit/21cbaf744b580001c16fa171f9afb72aeba67848))
* **workspace:** add terminal width configuration support ([86b0eb9](https://github.com/abordage/dockerkit/commit/86b0eb9847c6e3f8eadd7ff94d3f4bb96e4da884))

## [2.11.1](https://github.com/abordage/dockerkit/compare/v2.11.0...v2.11.1) (2025-09-27)


### Bug Fixes

* **tools:** resolve mkcert download redirects and add version verification ([b0fcd06](https://github.com/abordage/dockerkit/commit/b0fcd063652f18dfd168196a3c1b8841062316d7))

# [2.11.0](https://github.com/abordage/dockerkit/compare/v2.10.0...v2.11.0) (2025-09-26)


### Features

* **workspace:** preload composer public keys for signature verification ([58b91cb](https://github.com/abordage/dockerkit/commit/58b91cb20174d5945ca7b5d0877c56e0aa9e47e1))

# [2.10.0](https://github.com/abordage/dockerkit/compare/v2.9.1...v2.10.0) (2025-09-25)


### Features

* **tools:** enhance automated tool installation during setup ([694d3a5](https://github.com/abordage/dockerkit/commit/694d3a5d0e98788b46d74616b428cb7b0922e2e8))

## [2.9.1](https://github.com/abordage/dockerkit/compare/v2.9.0...v2.9.1) (2025-09-25)


### Bug Fixes

* **tools:** remove redundant 'v' from update message output ([378d5a5](https://github.com/abordage/dockerkit/commit/378d5a59b784548ba0e16bc08c84dca6da560266))

# [2.9.0](https://github.com/abordage/dockerkit/compare/v2.8.1...v2.9.0) (2025-09-25)


### Bug Fixes

* **tools:** add interactive flag for docker exec ([38224f2](https://github.com/abordage/dockerkit/commit/38224f28a82d32e776eaaa25cef2510df36c03ba))


### Features

* **tools:** add daily update check for DockerKit ([fd9461d](https://github.com/abordage/dockerkit/commit/fd9461d9cd8ea763731c27d550ac51538f11fc22))
* **tools:** add update manager and integrate `make update` workflow ([e79e81b](https://github.com/abordage/dockerkit/commit/e79e81bab2fddfd4d4d898c755665b5803221453))
* **workspace:** add xterm and terminal auto-resize support ([4bffef1](https://github.com/abordage/dockerkit/commit/4bffef1f454a410ed12097920a9b660e5dad3da0))

## [2.8.1](https://github.com/abordage/dockerkit/compare/v2.8.0...v2.8.1) (2025-09-24)


### Bug Fixes

* **workspace:** add ARG for PostgreSQL version in Dockerfile ([ac3e3b8](https://github.com/abordage/dockerkit/commit/ac3e3b8bba871fb39c76bbacb18ca89fbe383fac))

# [2.8.0](https://github.com/abordage/dockerkit/compare/v2.7.0...v2.8.0) (2025-09-23)


### Features

* **workspace:** add support for configurable PostgreSQL client version ([28cefa6](https://github.com/abordage/dockerkit/commit/28cefa6a1d6d400991c8b97493f98f3369e30820))

# [2.7.0](https://github.com/abordage/dockerkit/compare/v2.6.0...v2.7.0) (2025-09-22)


### Features

* **docker:** adjust elasticsearch java opts for simplified configuration ([a2238cc](https://github.com/abordage/dockerkit/commit/a2238cccfc81e1cd821f8fb0c0d7df1a25424412))
* **docker:** enforce lf line endings for entrypoint scripts ([24f7469](https://github.com/abordage/dockerkit/commit/24f74699741b23b6c3cd58b2f219900b70faa0df))
* **tools:** add automatic mkcert installation support ([f1f2dd3](https://github.com/abordage/dockerkit/commit/f1f2dd3653accdd7f2607d13c7d70f5e847e3a16))
* **tools:** add support for colors library in manager script ([bf3392e](https://github.com/abordage/dockerkit/commit/bf3392e1a1ef26f675e60448ffefa4f0888bbf42))
* **tools:** add user permissions setup for better development experience ([48b7f42](https://github.com/abordage/dockerkit/commit/48b7f42caaec4d8716d9081ab2f1b836999f5d12))
* **tools:** enhance windows integration and update wsl2 support ([ece032f](https://github.com/abordage/dockerkit/commit/ece032fb7728071ae9117b44f5ceeb4a440f59ac))

# [2.6.0](https://github.com/abordage/dockerkit/compare/v2.5.0...v2.6.0) (2025-09-21)


### Features

* **tools:** add support for wsl2 in package management script ([8cbe095](https://github.com/abordage/dockerkit/commit/8cbe095c134f26b59ed3cc495c8f90218e340c6c))

# [2.5.0](https://github.com/abordage/dockerkit/compare/v2.4.0...v2.5.0) (2025-09-15)


### Features

* **postgres:** increase max_connections to 300 ([367ec12](https://github.com/abordage/dockerkit/commit/367ec124c8376d9776721cf5536db5f0bb069833))
* **workspace:** add xsl to default PHP extensions list ([24f3bf5](https://github.com/abordage/dockerkit/commit/24f3bf54fa543438ffb1ddba652c52056c7444e7))

# [2.4.0](https://github.com/abordage/dockerkit/compare/v2.3.0...v2.4.0) (2025-09-10)


### Features

* add rebuild target for workspace and php-fpm images ([faae410](https://github.com/abordage/dockerkit/commit/faae41069fd38661734bf4b783c2f79ccaeac6dd))
* **php-fpm:** build custom cURL to disable RFC 6761 .localhost hardcoding ([efeddfd](https://github.com/abordage/dockerkit/commit/efeddfd1578b1c392e45cb15e913200601d050e4))
* **workspace:** build custom cURL to disable RFC 6761 .localhost hardcoding ([8dfb365](https://github.com/abordage/dockerkit/commit/8dfb365e291206734a1bb10836902db4ff6a3b90))

# [2.3.0](https://github.com/abordage/dockerkit/compare/v2.2.0...v2.3.0) (2025-09-09)


### Features

* **workspace:** add tmp-clean target to Makefile for clearing /tmp directory ([9a88f36](https://github.com/abordage/dockerkit/commit/9a88f3682a56ba66cc3f0b6021e8621e17d301be))
* **workspace:** ensure proper permissions for /opt directory ([89d0adb](https://github.com/abordage/dockerkit/commit/89d0adb016f9631f25473c3e7ce890d048816acf))

# [2.2.0](https://github.com/abordage/dockerkit/compare/v2.1.0...v2.2.0) (2025-09-09)


### Features

* **docker:** enable id field data in Elasticsearch configuration ([1151e99](https://github.com/abordage/dockerkit/commit/1151e99d12f23109337fe76faa176a903d0a55fd))
* **workspace:** add global full-access policy for MinIO users ([ca4b043](https://github.com/abordage/dockerkit/commit/ca4b043412b49b375a1682e86cadd59d6ada8b51))

# [2.1.0](https://github.com/abordage/dockerkit/compare/v2.0.0...v2.1.0) (2025-07-19)


### Features

* **project:** add smart document root detection for PHP projects ([c800d87](https://github.com/abordage/dockerkit/commit/c800d876e6301b79055ec7a65c185f73042e9444))

# [2.0.0](https://github.com/abordage/dockerkit/compare/v1.13.0...v2.0.0) (2025-07-19)


### Code Refactoring

* **project:** replace `.local` domain usage with `.localhost` across tools and configs ([c1488e3](https://github.com/abordage/dockerkit/commit/c1488e33dee62f7055ee5738a20200b78faafe95))


### BREAKING CHANGES

* **project:** *.local domains are no longer supported.

# [1.13.0](https://github.com/abordage/dockerkit/compare/v1.12.0...v1.13.0) (2025-07-11)


### Bug Fixes

* **tools:** improve host entry management and error handling ([0171753](https://github.com/abordage/dockerkit/commit/01717531f4fb2d5205e26e4905369ab657731ced))


### Features

* **docs:** update README for project management enhancements ([c8f1e8f](https://github.com/abordage/dockerkit/commit/c8f1e8f1fed59eb0544806e78c3a2e741cc9b519))
* **tools:** add container management utilities and setup integration ([cca2c31](https://github.com/abordage/dockerkit/commit/cca2c315a74f5f60c432b4b5d63919222422b802))
* **tools:** add git configuration generation script ([bb1d550](https://github.com/abordage/dockerkit/commit/bb1d5505b584e6b8cb68f32de6b376c39186e310))
* **tools:** add nginx configuration cleanup for obsolete projects ([0a38f67](https://github.com/abordage/dockerkit/commit/0a38f6731a83d6f2cd26c4e61520bacb0b4aa8a0))
* **tools:** add SSL certificate cleanup for obsolete projects ([f0d0cdf](https://github.com/abordage/dockerkit/commit/f0d0cdf86550d0dd5d79ecc0dcc738f17e9d3e51))
* **tools:** improve cleanup scripts with additional existence checks ([ace3d43](https://github.com/abordage/dockerkit/commit/ace3d436ed0dea96face2cfeb4fbe652608ab942))
* **tools:** introduce project creation tool with Laravel and Symfony support ([26baf3c](https://github.com/abordage/dockerkit/commit/26baf3cb73d5a051bbcf8dec971d1d6a6cfb6009))
* **tools:** refactor workspace_exec and add a project creation target ([de71a82](https://github.com/abordage/dockerkit/commit/de71a823f6c811da809cc258eff5a3bba47e5df4))
* **workspace:** add apcu to default PHP extensions ([f1ff839](https://github.com/abordage/dockerkit/commit/f1ff839b9065373fb6b14b5bd5db2a0dac763588))
* **workspace:** add Laravel installer to global composer packages ([b776d50](https://github.com/abordage/dockerkit/commit/b776d5053aecb7c1867d9e77ca0d8ca256ac1012))
* **workspace:** add Symfony CLI and git configuration support ([5ff7f30](https://github.com/abordage/dockerkit/commit/5ff7f309406f648fa426d1e62f01ace9a89f89d9))

# [1.12.0](https://github.com/abordage/dockerkit/compare/v1.11.1...v1.12.0) (2025-07-10)


### Features

* **nginx:** add configuration templates for satis support ([4836266](https://github.com/abordage/dockerkit/commit/483626634a08a3f29f3e0dba60b5233c7dea68e7))

## [1.11.1](https://github.com/abordage/dockerkit/compare/v1.11.0...v1.11.1) (2025-07-08)


### Bug Fixes

* **workspace:** add SSH keys setup script for secure deployment ([e28fd25](https://github.com/abordage/dockerkit/commit/e28fd25fe037c11f8878541d166db00bc960b7d6))

# [1.11.0](https://github.com/abordage/dockerkit/compare/v1.10.0...v1.11.0) (2025-07-07)


### Features

* **workspace:** add SSH support for deployment configuration ([866bf34](https://github.com/abordage/dockerkit/commit/866bf34a03d0dfa07408838f7022a144a6181c0e))

# [1.10.0](https://github.com/abordage/dockerkit/compare/v1.9.0...v1.10.0) (2025-07-07)


### Features

* **workspace:** add deployer CLI and bash completion to global tools ([31b2183](https://github.com/abordage/dockerkit/commit/31b2183e67c153569b0855b34e1e2d4fe1e84358))

# [1.9.0](https://github.com/abordage/dockerkit/compare/v1.8.0...v1.9.0) (2025-07-04)


### Features

* **tools:** implement unified database dump management system ([40e88ce](https://github.com/abordage/dockerkit/commit/40e88ce81dad6a90ca9c23b842deec60c9d1a4ba))
* **workspace:** update PostgreSQL and MySQL clients to latest versions ([a86468d](https://github.com/abordage/dockerkit/commit/a86468dcecfd75d071738e9865c350affd117304))

# [1.8.0](https://github.com/abordage/dockerkit/compare/v1.7.0...v1.8.0) (2025-07-02)


### Features

* **workspace:** add RabbitMQ automation script ([d6c8c52](https://github.com/abordage/dockerkit/commit/d6c8c52b3281d577354e2d5cb2025df32a6e3672))
* **workspace:** add Redis ACL automation script ([873d180](https://github.com/abordage/dockerkit/commit/873d1807c2289ecb3dde62c85110401982ce81f5))

# [1.7.0](https://github.com/abordage/dockerkit/compare/v1.6.0...v1.7.0) (2025-07-01)


### Bug Fixes

* **workspace:** improve artisan completion logic in .bashrc ([1bc2e60](https://github.com/abordage/dockerkit/commit/1bc2e60eb100fc989ce5df1a6a93b2f08f342de6))


### Features

* **rabbitmq:** enhance entrypoint script with modular functions and logging ([73f53e9](https://github.com/abordage/dockerkit/commit/73f53e93f96f7c24c2df229233c5d8ca45dcf81c))
* **workspace:** add caching for PHP extensions and downloads ([2b61f87](https://github.com/abordage/dockerkit/commit/2b61f87f2bfc3f70d299e961194f26824c462e9f))
* **workspace:** add Redis ACL setup script ([e855fb8](https://github.com/abordage/dockerkit/commit/e855fb875800a5806dba6201224a58175c29a358))
* **workspace:** enhance database setup script with user automation and service health checks ([752d1ae](https://github.com/abordage/dockerkit/commit/752d1ae67c500a2c8dfda56e72cc296787998ed1))
* **workspace:** enhance MinIO setup script with project automation and modular utilities ([84d9367](https://github.com/abordage/dockerkit/commit/84d936716b6030c58f8a345f55138c0fedff9df0))

# [1.6.0](https://github.com/abordage/dockerkit/compare/v1.5.0...v1.6.0) (2025-06-30)


### Bug Fixes

* **nginx:** add index directive for default index file handling ([043c083](https://github.com/abordage/dockerkit/commit/043c083af65366eb195fda6ee260ed3ef2d83ee9))
* **tools:** streamline SSL and Nginx directory handling ([3b65108](https://github.com/abordage/dockerkit/commit/3b65108e846462f055a2e3dba034b29a199dc742))


### Features

* **workspace:** install selective tools from Debian Backports repository ([c62278f](https://github.com/abordage/dockerkit/commit/c62278fd465159cc4d2a568f15a440cce5487555))

# [1.5.0](https://github.com/abordage/dockerkit/compare/v1.4.0...v1.5.0) (2025-06-30)


### Features

* **tools:** add `dk` command and manager scripts for DockerKit integration ([e1c3176](https://github.com/abordage/dockerkit/commit/e1c31760c054738822ad18b31cb3e0cf3bc35311))

# [1.4.0](https://github.com/abordage/dockerkit/compare/v1.3.0...v1.4.0) (2025-06-29)


### Features

* **tools:** add comprehensive cleanup service modules ([d4d7583](https://github.com/abordage/dockerkit/commit/d4d7583c18cc45c5f5335481af1d3557c4d6451b))
* **tools:** add linting support for shell configuration files ([199f669](https://github.com/abordage/dockerkit/commit/199f669ff089f4aadbace83d559ffcc87ffcd7da))
* **workspace:** add health checks for postgres and mysql service dependencies in docker-compose ([c0fa09a](https://github.com/abordage/dockerkit/commit/c0fa09a7b623e15a8e2e6a5351c4e6ae56486a1a))
* **workspace:** replace dejavu with elasticvue for Elasticsearch Web UI integration ([ebfe759](https://github.com/abordage/dockerkit/commit/ebfe7598089e921bb3b097aeb8acf37bf32a2e06))
* **workspace:** update composer to latest version in Dockerfile ([2a8915c](https://github.com/abordage/dockerkit/commit/2a8915c6db665648ac62b6c816b144e02188b978))
* **workspace:** update npm to latest version during Node.js tools installation ([adcdbfe](https://github.com/abordage/dockerkit/commit/adcdbfe74fae021cec4017daf0b028b521c9b63f))

# [1.3.0](https://github.com/abordage/dockerkit/compare/v1.2.0...v1.3.0) (2025-06-28)


### Features

* **workspace:** enhance terminal experience with comprehensive shell improvements ([#8](https://github.com/abordage/dockerkit/issues/8)) ([a086a08](https://github.com/abordage/dockerkit/commit/a086a081acb7a7339b35d129ebe9e5031e0be7c2))

# [1.2.0](https://github.com/abordage/dockerkit/compare/v1.1.0...v1.2.0) (2025-06-25)


### Features

* **workspace:** add automatic database creation for .local projects ([#7](https://github.com/abordage/dockerkit/issues/7)) ([1b7085a](https://github.com/abordage/dockerkit/commit/1b7085abb099abed676266d59fae4cacec6979b7))

# [1.1.0](https://github.com/abordage/dockerkit/compare/v1.0.0...v1.1.0) (2025-06-25)


### Features

* improve project documentation and semantic-release configuration ([#6](https://github.com/abordage/dockerkit/issues/6)) ([37eae7d](https://github.com/abordage/dockerkit/commit/37eae7db0eee6cf004f8a5551ebb6d4cb97d7f1b))
