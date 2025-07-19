<!--suppress HtmlDeprecatedAttribute, HtmlUnknownAnchorTarget -->

# 🚀 Modern Docker Stack for Local Development

![Release](https://img.shields.io/github/v/release/abordage/dockerkit)
![Hadolint Status](https://img.shields.io/github/actions/workflow/status/abordage/dockerkit/hadolint.yml?label=hadolint)
![Shellcheck Status](https://img.shields.io/github/actions/workflow/status/abordage/dockerkit/shellcheck.yml?label=shellcheck)
![License](https://img.shields.io/github/license/abordage/dockerkit)

<p style="text-align: center;" align="center">
  <a href="#features">Features</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#usage">Usage</a> •
  <a href="#development-tools">Tools</a>
</p>

![dockerkit-setup.gif](.github/images/dockerkit-setup.gif)

DockerKit is a modern development environment enabling you to run, configure, and manage multiple Laravel/Symfony (and more) projects in Docker with minimal effort and maximum automation. **Everything just works out of the box.**

---

## Features

### **Automatic Infrastructure**

#### **Project Discovery**

- **Automatic scanning** for `.localhost` projects in parent directory
- **Project type identification** based on framework-specific files and structure
- **Support for multiple frameworks / CMS**: Laravel, Symfony, WordPress, Static HTML, Simple PHP

#### **Web Server Configuration**

- **Automatic SSL certificate generation** using mkcert for all `.localhost` domains
- **Nginx configuration generation** from project-specific templates
- **Security headers and rules** tailored per project type

#### **Network Configuration**

- **Docker Compose aliases generation** for microservice communication
- **Internal DNS resolution** for `.localhost` domains within Docker network
- **Container CA installation** for internal HTTPS communication

### **Automatic Service Configuration**

#### **Environment Scanning**

- **Project .env file detection** across all `.localhost` directories
- **Multi-environment support** for `.env` and `.env.testing` configurations
- **Service configuration mapping** from environment variables to service settings

#### **Database Configuration**

- **Database creation** for PostgreSQL and MySQL based on `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`
- **User management** with appropriate permissions per project
- **Legacy user support** for existing project compatibility

#### **Redis Configuration**

- **Multi-password ACL setup** based on `REDIS_PASSWORD`
- **Project isolation** with dedicated Redis configurations

#### **RabbitMQ Configuration**

- **User and virtual host creation** based on `RABBITMQ_USER`, `RABBITMQ_PASSWORD`, `RABBITMQ_VHOST`
- **Permission setup** (configure, write, read) per project

#### **MinIO Configuration**

- **Bucket creation** based on `AWS_BUCKET` or `MINIO_BUCKET`
- **User management** based on `AWS_ACCESS_KEY_ID`/`MINIO_ACCESS_KEY`
- **Policy configuration** with public/private bucket support

### **Development Tools**

#### **Project Creation**

- **Interactive project creation** for Laravel and Symfony frameworks
- **Environment configuration** with .env file generation
- **Instant HTTPS setup** for newly created projects

#### **Database Management**

- **Interactive backup/restore tool** with step-by-step workflow
- **Multi-database support** for PostgreSQL and MySQL
- **Compression support** with optional gzip compression

---

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
├── dockerkit/              # This repository  
├── myapp.localhost/        # Detected: Laravel project
├── api.localhost/          # Detected: Symfony project  
├── blog.localhost/         # Detected: WordPress project
├── docs/                   # Ignored: no .localhost suffix
└── backup-files/           # Ignored: no .localhost suffix
```

Modern browsers automatically resolve `.localhost` domains to `127.0.0.1` according to RFC standards:

- [RFC 2606](https://datatracker.ietf.org/doc/html/rfc2606) — Reserved Top Level DNS Names: Defines `.localhost` as a reserved domain
- [RFC 6761](https://datatracker.ietf.org/doc/html/rfc6761) — Special-Use Top Level Domains: Specifies that `.localhost` should resolve to loopback addresses
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
make lint          # Run all quality checks (Dockerfiles, bash scripts)
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
artisan         # php artisan
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
