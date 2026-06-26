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
5. [Change Data Capture (Debezium)](#change-data-capture-debezium)
6. [Development Tools](#development-tools)

## Quick Start

### Prerequisites

- **Docker & Docker Compose** for container orchestration
- **[Homebrew](https://brew.sh)** (macOS only) - required for automatic mkcert installation

### Installation

```bash
# 1. Clone repository to your projects directory
cd /path/to/your/projects
git clone https://github.com/abordage/dockerkit.git

# 2. Navigate to DockerKit directory
cd dockerkit

# 3. Run automatic environment setup
make setup
```

### Automatic Tool Installation

DockerKit automatically installs required development tools during setup:

- **mkcert** - for trusted SSL certificates (installed automatically)
  - On macOS: via Homebrew (`brew install mkcert`)
  - On Linux/WSL2: from GitHub releases
  - Certificate Authority is configured automatically
- **dk command** - for quick workspace access from any project directory

No manual installation required - everything is handled by `make setup`.

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

### Git configuration (host)

The `workspace` service bind-mounts your host `~/.gitconfig` (see `docker-compose.yml`). That path must be a **regular file** (for example create it with `touch ~/.gitconfig` or set `user.name` / `user.email` with `git config --global`) **before** the first `docker compose up` that starts `workspace` if you skip `make setup`. If the file is missing, Docker can create a **directory** at the same path, which breaks Git. `make setup` checks this before continuing (including when it restarts containers at the end).

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

# Maintenance
make update        # Update DockerKit and rebuild containers
make reset         # Reset project to initial state
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

| Service           | URL                      | Credentials           | Purpose             |
|-------------------|--------------------------|-----------------------|---------------------|
| **Mailpit**       | <http://localhost:8125>  | -                     | Email testing       |
| **MinIO Console** | <http://localhost:9001>  | dockerkit / dockerkit | File storage        |
| **RabbitMQ**      | <http://localhost:15672> | dockerkit / dockerkit | Message queues      |
| **Elasticvue**    | <http://localhost:9210>  | -                     | Elasticsearch UI    |
| **Portainer**     | <http://localhost:9010>  | Setup on first visit  | Docker management   |
| **Prometheus**    | <http://localhost:9090>  | -                     | Metrics collection  |
| **Grafana**       | <http://localhost:3100>  | dockerkit / dockerkit | Metrics dashboards  |

> Prometheus and Grafana are optional services. Add `prometheus grafana` to `ENABLE_SERVICES` in `.env` to start them.

## Change Data Capture (Debezium)

Debezium Server captures PostgreSQL changes via logical replication (WAL) and publishes them to RabbitMQ. **One Debezium instance monitors one PostgreSQL database.** For multiple databases, create multiple instances.

### Create an instance

```bash
make debezium-instance INSTANCE=myapp DATABASE=myapp_db PORT=8081
make debezium-instance INSTANCE=api DATABASE=api_db PORT=8082
```

This creates:

```text
debezium/instances/
├── _template/              # Template (do not use as instance)
├── myapp/
│   ├── application.properties   # connector config (table.include.list, topic.prefix)
│   └── instance.env             # SERVER_PORT for health endpoint
└── api/
    ├── application.properties
    └── instance.env
```

`make setup` regenerates `docker-compose.debezium.yml` with a service per instance (`debezium-myapp`, `debezium-api`, …).

### Enable instances

Add each instance to `ENABLE_SERVICES` in `.env` (requires `postgres` and `rabbitmq`):

```bash
ENABLE_SERVICES="nginx php-fpm workspace postgres rabbitmq debezium-myapp debezium-api"
```

Then run `make restart`.

> **Note:** `wal_level=logical` is configured in `postgres/postgresql.conf`. If the PostgreSQL volume already exists, restart PostgreSQL after the config change. In some cases you may need to recreate the `postgres_data` volume.  
> Also you can set up `max_wal_senders = 5` and `max_replication_slots = 5`.
> **max_replication_slots** - Specifies the maximum number of replication slots that the server can support (10 by default).  
> **max_wal_senders** - Sets the maximum number of simultaneously running WAL sender processes (10 by default).

### PostgreSQL setup

Run the following SQL **in each database** you want to capture (replace placeholders):

```sql
-- 1. Create a replication user (run once per PostgreSQL server)
CREATE USER debezium WITH REPLICATION LOGIN PASSWORD 'your_password';

-- 2. Connect to the target database and grant access
GRANT CONNECT ON DATABASE your_db TO debezium;
GRANT USAGE ON SCHEMA public TO debezium;

-- 3. Grant SELECT on tables you want to capture
GRANT SELECT ON TABLE public.table1, public.table2 TO debezium;

-- 4. Create a publication for those tables
CREATE PUBLICATION dbz_publication FOR TABLE public.table1, public.table2;
```

Match `DEBEZIUM_DB_USER` / `DEBEZIUM_DB_PASSWORD` in `.env` with the user created above. The publication name must match `debezium.source.publication.name` in the instance `application.properties` (default: `dbz_publication`).

Each instance uses a unique `topic.prefix` (e.g. `cdc.myapp`) and `slot.name` (e.g. `debezium_slot_myapp`) — set automatically when creating the instance.

Debezium creates the replication slot automatically.

### RabbitMQ setup

Create a **direct** exchange (default name: `cdc`) and bind one queue per table.

Routing key format: `{topic.prefix}.{schema}.{table}`

| Instance | Table           | Routing key                 | Queue   |
|----------|-----------------|-----------------------------|---------|
| `myapp`  | `public.orders` | `cdc.myapp.public.orders`   | `orders`  |
| `api`    | `public.events` | `cdc.api.public.events`     | `events`  |

With `autoCreateRoutingKey=true` (default), queues are created automatically when the first message arrives. To use custom queue names, create the queue and binding manually in the [RabbitMQ Management UI](http://localhost:15672).

### Adding a new table

1. `GRANT SELECT ON TABLE public.new_table TO debezium;`
2. `ALTER PUBLICATION dbz_publication ADD TABLE public.new_table;`
3. Add `public.new_table` to `table.include.list` in `debezium/instances/<instance>/application.properties`
4. Create a queue and binding in RabbitMQ (if not using auto-create)
5. `docker compose restart debezium-<instance>`

### Health check

```bash
curl http://localhost:8081/q/health   # debezium-myapp (if SERVER_PORT=8080)
curl http://localhost:8082/q/health   # debezium-api
```

Ports are configured per instance in `debezium/instances/<instance>/instance.env`. Default starting port: `DEBEZIUM_SERVER_PORT_BASE` in `.env` (8080).

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
