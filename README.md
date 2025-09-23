<!--suppress HtmlDeprecatedAttribute, HtmlUnknownAnchorTarget -->

# 🚀 Modern Docker Stack for Local Development

![Release](https://img.shields.io/github/v/release/abordage/dockerkit)
![Hadolint Status](https://img.shields.io/github/actions/workflow/status/abordage/dockerkit/hadolint.yml?label=hadolint)
![Shellcheck Status](https://img.shields.io/github/actions/workflow/status/abordage/dockerkit/shellcheck.yml?label=shellcheck)
![License](https://img.shields.io/github/license/abordage/dockerkit)

DockerKit is a modern development environment enabling you to run, configure, and manage multiple Laravel/Symfony (and more) projects in Docker with minimal effort and maximum automation.

![dockerkit-setup.gif](.github/images/dockerkit-setup.gif)

## Features

### Zero-Configuration Discovery

- **Automatic project scanning** for `.localhost` projects in parent directory
- **Framework detection** based on project structure
- **SSL certificate generation** using mkcert for secure HTTPS development
- **Nginx configuration** auto-generated from project-specific templates

### Service Auto-Configuration

- **Multi-project .env scanning** across all `.localhost` directories
- **Database auto-creation** for PostgreSQL and MySQL with user management
- **Redis ACL setup** with multi-password configuration per project
- **RabbitMQ management** with user, virtual host, and permission setup
- **MinIO bucket creation** with user management and policy configuration

### Developer Productivity Tools

- **Interactive project creation** for Laravel and Symfony frameworks
- **Database backup/restore** with step-by-step workflow and compression support
- **Enhanced workspace** with modern terminal, fuzzy search, and smart autocompletion
- **Docker network aliases** for seamless microservice communication

## Table of Contents

1. [Quick Start](#quick-start)
2. [Configuration](#configuration)
3. [Usage](#usage)
4. [Web Consoles](#web-consoles)
5. [Development Tools](#development-tools)

## Quick Start

### Prerequisites

- **Docker & Docker Compose** for container orchestration
- **[mkcert](https://github.com/FiloSottile/mkcert)** for automatic HTTPS certificate generation (recommended)

### Installation

```bash
# 1. Clone repository to your projects directory
cd /path/to/your/projects
git clone https://github.com/abordage/dockerkit.git

# 2. Navigate to DockerKit directory
cd dockerkit

# 3. Run automatic environment setup
make setup

# 4. Start all services
make start

# 5. Install the `dk` command for instant workspace access from any project dir
make dk-install
```

### Project Structure

DockerKit automatically discovers projects in the parent directory:

```text
/your/projects/directory/
├── dockerkit/             # This repository  
├── myapp.localhost/       # Laravel project
│   ├── artisan            #   ← Laravel indicator
│   ├── composer.json      #   ← Contains "laravel/framework"
│   └── public/index.php   #   ← Standard Laravel structure
├── api.localhost/         # Symfony project  
│   ├── bin/console        #   ← Symfony indicator
│   ├── composer.json      #   ← Contains "symfony/framework-bundle"
│   └── public/index.php   #   ← Standard Symfony structure
├── blog.localhost/        # WordPress project
│   ├── wp-config.php      #   ← WordPress indicator
│   └── wp-content/        #   ← WordPress structure
├── legacy.localhost/      # PHP project
│   └── index.php          #   ← Basic PHP project
├── docs/                  # Ignored: no .localhost suffix
└── backup-files/          # Ignored: no .localhost suffix
```

Modern browsers automatically resolve `.localhost` domains to `127.0.0.1` according to RFC standards:

- [RFC 2606](https://datatracker.ietf.org/doc/html/rfc2606) — Reserved Top Level DNS Names: Defines `.localhost` as a reserved domain
- [RFC 6761](https://datatracker.ietf.org/doc/html/rfc6761) — Special-Use Top Level Domains: `.localhost` should resolve to loopback addresses
- [RFC 6762](https://datatracker.ietf.org/doc/html/rfc6762) — Multicast DNS: Confirms `.localhost` special handling in modern systems

This eliminates the need for hosts file modifications or DNS configuration.

### Create New Project

```bash
# Create new project interactively
make project

# Choose project type (Laravel/Symfony)
# Enter project name (e.g., myapp.localhost)
# Project will be available at https://myapp.localhost
```

### Deploy Existing Projects

```bash
# 1. Clone your existing projects to the parent directory
cd /path/to/your/projects  # Same level as dockerkit/
git clone https://github.com/yourorg/myapp.git myapp.localhost
git clone https://github.com/yourorg/api.git api.localhost

# 2. Reconfigure DockerKit to detect new projects
cd dockerkit
make setup

# 3. Your projects are now available:
# https://myapp.localhost
# https://api.localhost
```

## Configuration

### Dockerkit Configuration

Customize enabled services in `.env`:

```bash
# Choose which services to start (comma-separated)
ENABLE_SERVICES="nginx,php-fpm,workspace,postgres,mysql,redis,rabbitmq,minio"

# Customize PHP extensions
DEPENDENCY_PHP_EXTENSIONS="gd,imagick,redis,xdebug,opcache"
```

### Composer Authentication

For private repositories, configure `workspace/auth.json`:

```json
{
  "github-oauth": {
    "github.com": "ghp_your_personal_access_token"
  },
  "gitlab-token": {
    "gitlab.com": "glpat-your_project_access_token"
  }
}
```

Or configure directly in workspace container:

```bash
dk  # Access workspace container
composer config --global repositories.repo-name composer https://packages.example.com
# See: https://getcomposer.org/doc/05-repositories.md
```

### SSH Configuration

Mount SSH keys for deployment and git operations:

```bash
# Option 1: Copy keys to workspace/ssh/
cp ~/.ssh/* workspace/ssh/

# Option 2: Mount system SSH (in .env)
HOST_SSH_PATH=~/.ssh

make restart  # Apply changes
```

## Usage

DockerKit provides a comprehensive set of Make targets for streamlined development:

```bash
# Environment Management
make setup         # Complete environment setup (run once)
make start         # Start selected services with network aliases
make stop          # Stop all services
make restart       # Restart selected services
make status        # Show current system status

# Project Management  
make project       # Create new project (Laravel/Symfony)
make dump          # Interactive database backup/restore tool

# Development Tools
make dk-install    # Install dk command for quick workspace access
make dk-uninstall  # Remove dk command from system

# Maintenance
make reset         # Reset project to initial state
make rebuild       # Rebuild workspace and php-fpm images
make lint          # Run all quality checks (Dockerfiles, bash scripts)
make tmp-clean     # Clean /tmp inside workspace container
```

The workspace container provides an enhanced terminal experience:

### Interactive Navigation

- **`Ctrl+T`** — Interactive file finder (fzf)
- **`Ctrl+R`** — Fuzzy command history search
- **Modern prompt** — Starship with project context and git status

### Smart Autocompletion

Bash completion available for all development tools:

- **Composer** commands and packages
- **npm** and Node.js tools
- **Git** branches and commands
- **Laravel Artisan** commands
- **Symfony Console** commands

### Useful Aliases

Pre-configured shortcuts for common tasks:

```bash
# Laravel/PHP shortcuts
art             # php artisan
fresh           # php artisan migrate:fresh
seed            # php artisan db:seed

# Development tools
pint            # ./vendor/bin/pint
pest            # ./vendor/bin/pest
phpstan         # ./vendor/bin/phpstan

# File operations
ll              # ls -alF --color=auto
tree            # tree -I vendor -C
```

## Web Consoles

Access management interfaces for development services:

| Service           | URL                      | Credentials           | Purpose           |
|-------------------|--------------------------|-----------------------|-------------------|
| **Mailpit**       | <http://localhost:8125>  | -                     | Email testing     |
| **MinIO Console** | <http://localhost:9001>  | dockerkit / dockerkit | File storage      |
| **RabbitMQ**      | <http://localhost:15672> | dockerkit / dockerkit | Message queues    |
| **Elasticvue**    | <http://localhost:9210>  | -                     | Elasticsearch UI  |
| **Portainer**     | <http://localhost:9010>  | Setup on first visit  | Docker management |

## Development Tools

### API Development Tools

- **OpenAPI Generator CLI** — Generate client libraries and server stubs from OpenAPI specs
- **Vacuum** — OpenAPI specification linter and quality checker

### PHP Development Tools  

- **Composer** with global packages (normalize, changelogs)
- **Deployer** — Modern deployment tool with zero-downtime deployments
- **Laravel Installer** — Quick Laravel project scaffolding
- **Symfony CLI** — Official Symfony command-line tool

### Database Clients

- **PostgreSQL client** (`psql`)
- **MySQL client** (`mysql`)
- **Redis tools** (`redis-cli`)

### Modern Terminal Experience

- **fzf** — Interactive fuzzy finder for file search and command history
- **Starship** — Modern shell prompt with project context
- **yq** — YAML processor for configuration management

## Comparison

### DockerKit vs Laradock

| Feature                    | DockerKit                                                      | Laradock                        |
|----------------------------|----------------------------------------------------------------|---------------------------------|
| **Project Discovery**      | ✅ Automatic scanning and detection                             | ❌ Manual configuration          |
| **SSL Certificates**       | ✅ Automatic SSL generation with mkcert                         | ❌ Manual SSL setup              |
| **Nginx Configuration**    | ✅ Auto-generated configs                                       | ❌ Manual nginx configuration    |
| **MinIO Management**       | ✅ Automatic user/bucket creation based on project .env files   | ❌ Manual bucket setup           |
| **Database Creation**      | ✅ Automatic database/user creation based on project .env files | ❌ Manual database setup         |
| **Container Optimization** | ✅ Multi-stage builds, smaller images, caching                  | ⚠️ Traditional Docker approach  |
| **Project Maturity**       | ⚠️ Modern but newer project                                    | ✅ Battle-tested, proven by time |
| **Available Services**     | ⚠️ Focused essential toolkit                                   | ✅ Extensive service library     |
| **Community Support**      | ⚠️ Growing community                                           | ✅ Large established community   |

#### 🎯 Choose DockerKit if you want

- **Automated workflow** for local development
- **Modern Docker practices** with optimized performance
- **Focus on essential tools** without complexity

#### 🎯 Choose Laradock if you need

- **Extensive service ecosystem** out of the box
- **Proven stability** and mature codebase
- **Large community** support and resources

## Roadmap

DockerKit is actively developed with exciting features planned for future releases:

- [ ] **Improve documentation** — Comprehensive documentation with examples and clear structure
- [ ] **Configure supervisor for process management** — Advanced process monitoring and management
- [ ] **Add RoadRunner support** — High-performance PHP application server as alternative to PHP-FPM
- [ ] **Add FrankenPHP support** — Modern PHP runtime built on top of Caddy web server
- [ ] **Add Laravel Horizon support** — Queue monitoring and management dashboard
- [ ] **Add support for Node.js projects** — Automatic detection and configuration for Node.js applications
- [ ] **Add MongoDB database support** — Automatic collection setup with user management
- [ ] **Add pgBadger support** — PostgreSQL log analysis and performance insights

## Contributing

Please see [CONTRIBUTING.md](.github/CONTRIBUTING.md) for details.

## Security

Please review [security policy](https://github.com/abordage/.github/security/policy)
on how to report security vulnerabilities.

## Credits

- [Pavel Bychko](https://github.com/abordage)
- [All Contributors](https://github.com/abordage/dockerkit/graphs/contributors)

## License

```text
$$$$$$$\                      $$\                           $$\   $$\ $$\   $$\     
$$  __$$\                     $$ |                          $$ | $$  |\__|  $$ |    
$$ |  $$ | $$$$$$\   $$$$$$$\ $$ |  $$\  $$$$$$\   $$$$$$\  $$ |$$  / $$\ $$$$$$\   
$$ |  $$ |$$  __$$\ $$  _____|$$ | $$  |$$  __$$\ $$  __$$\ $$$$$  /  $$ |\_$$  _|  
$$ |  $$ |$$ /  $$ |$$ /      $$$$$$  / $$$$$$$$ |$$ |  \__|$$  $$<   $$ |  $$ |    
$$ |  $$ |$$ |  $$ |$$ |      $$  _$$<  $$   ____|$$ |      $$ |\$$\  $$ |  $$ |$$\ 
$$$$$$$  |\$$$$$$  |\$$$$$$$\ $$ | \$$\ \$$$$$$$\ $$ |      $$ | \$$\ $$ |  \$$$$  |
\_______/  \______/  \_______|\__|  \__| \_______|\__|      \__|  \__|\__|   \____/ 

The MIT License (MIT)
```
