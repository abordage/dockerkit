# DockerKit

> Modern Docker development environment with automated local setup

## Overview

DockerKit is a comprehensive Docker-based development environment that provides a complete stack for web development. It features automated local development setup with SSL certificates, intelligent project type detection, and seamless integration with popular PHP frameworks.

The kit automatically **discovers your projects**, **configures local domains**, **adds hosts entries**, **generates SSL certificates**, and **creates optimized nginx configurations** - all with a single command.

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/abordage/dockerkit dockerkit
cd dockerkit

# 2. Place your projects in the parent directory
# Projects must end with '.local' (e.g., myapp.local, api.local)
#
# your-projects-dir/
# ├── dockerkit/               # This repository
# ├── myapp.local/             # Laravel project (will be processed)
# ├── api.local/               # Symfony API (will be processed)
# ├── blog.local/              # WordPress blog (will be processed)
# ├── shop.local/              # E-commerce site (will be processed)
# ├── old-project/             # Regular directory (ignored)
# ├── backup-files/            # Regular directory (ignored)
# └── docs/                    # Regular directory (ignored)

# 3. Configure services (optional)
# Edit .env to enable/disable services as needed
# Default: nginx, workspace, postgres, redis enabled

# 4. Set up local development environment
make setup

# 5. Start the services
make start
```

**Important**: Only directories with `.local` suffix are automatically discovered and configured. The setup system completely ignores all other directories in the parent folder.

Your projects will be available at:

- `https://myapp.local` (with SSL)
- `https://api.local` (with SSL)
- `https://blog.local` (with SSL)
- `https://shop.local` (with SSL)

## Available Services

DockerKit provides a comprehensive set of services that can be **flexibly enabled or disabled** based on your project needs:

```text
┌─────────────────┬──────────┬─────────────────────────────────────┬─────────────┐
│ Service         │ Port     │ Description                         │ Default     │
├─────────────────┼──────────┼─────────────────────────────────────┼─────────────┤
│ nginx           │ 80, 443  │ PHP-FPM + nginx web server          │ ✅ Enabled  │
│ workspace       │ 3000+    │ Development workspace with Composer │ ✅ Enabled  │
│ postgres        │ 5432     │ PostgreSQL database server          │ ✅ Enabled  │
│ redis           │ 6379     │ Redis cache server                  │ ✅ Enabled  │
│ mysql           │ 3306     │ MySQL database server               │ ❌ Disabled │
│ mongodb         │ 27017    │ MongoDB document database           │ ❌ Disabled │
│ rabbitmq        │ 5672+    │ RabbitMQ message broker             │ ✅ Enabled  │
│ elasticsearch   │ 9200     │ Elasticsearch search engine         │ ❌ Disabled │
│ dejavu          │ 1358     │ Elasticsearch web UI                │ ❌ Disabled │
│ minio           │ 9000+    │ MinIO S3-compatible object storage  │ ✅ Enabled  │
│ mailpit         │ 8025+    │ Email testing tool                  │ ✅ Enabled  │
│ portainer       │ 9000     │ Docker container management         │ ✅ Enabled  │
└─────────────────┴──────────┴─────────────────────────────────────┴─────────────┘
```

### Flexible Service Configuration

Control which services to run by editing the `.env` file:

```bash
### Services ###############################################
# Core services (1 = enabled, 0 = disabled)
ENABLE_NGINX=1
ENABLE_WORKSPACE=1

# Database services (1 = enabled, 0 = disabled)
ENABLE_POSTGRES=1
ENABLE_MYSQL=0
ENABLE_MONGODB=0
ENABLE_REDIS=1

# Additional services (1 = enabled, 0 = disabled)
ENABLE_RABBITMQ=1
ENABLE_ELASTICSEARCH=0
ENABLE_DEJAVU=0
ENABLE_MINIO=1
ENABLE_MAILPIT=1
ENABLE_PORTAINER=1
```

### Common Configurations

#### Minimal Setup (Static Sites)

```bash
ENABLE_NGINX=1
ENABLE_WORKSPACE=1
# All databases = 0
```

#### Laravel Project

```bash
ENABLE_NGINX=1
ENABLE_WORKSPACE=1
ENABLE_MYSQL=1
ENABLE_REDIS=1
ENABLE_MAILPIT=1
ENABLE_MINIO=1
```

#### Microservices with Search

```bash
ENABLE_NGINX=1
ENABLE_WORKSPACE=1
ENABLE_POSTGRES=1
ENABLE_REDIS=1
ENABLE_RABBITMQ=1
ENABLE_ELASTICSEARCH=1
ENABLE_DEJAVU=1
```

**Apply changes**: Simply run `docker compose up -d` after modifying `.env`

## Development Tools

The workspace container includes pre-installed development tools for API development and validation.

### OpenAPI Tools

#### @openapitools/openapi-generator-cli

**Purpose**: Generate client libraries, server stubs, and API documentation from OpenAPI specifications

**Installation**: Pre-installed when `INSTALL_OPENAPI_GENERATOR=true`

**Usage Examples**:

```bash
# Generate TypeScript client from OpenAPI spec
openapi-generator-cli generate -g typescript-fetch \
  -i https://petstore.swagger.io/v2/swagger.json \
  -o ./generated/typescript-client

# Generate PHP client
openapi-generator-cli generate -g php \
  -i ./api/openapi.yaml \
  -o ./generated/php-client

# List available generators
openapi-generator-cli list
```

**Use Cases**:

- Generate API clients for frontend applications
- Create server stubs for new APIs
- Generate API documentation
- Keep clients in sync with API changes

**Documentation**: [OpenAPI Generator CLI](https://github.com/OpenAPITools/openapi-generator-cli)

#### @quobix/vacuum

**Purpose**: OpenAPI specification linter and quality checker

**Installation**: Pre-installed when `INSTALL_VACUUM=true`

**Usage Examples**:

```bash
# Lint OpenAPI specification
vacuum lint ./api/openapi.yaml

# Generate detailed report
vacuum lint ./api/openapi.yaml --details

# Check specific rules
vacuum lint ./api/openapi.yaml --functions=owasp

# Output formats
vacuum lint ./api/openapi.yaml --format=json
vacuum lint ./api/openapi.yaml --format=html > report.html
```

**Use Cases**:

- Validate OpenAPI specifications for errors
- Enforce API design standards
- Security analysis (OWASP rules)
- Quality metrics and reporting
- CI/CD integration for API validation

**Documentation**: [Vacuum](https://github.com/daveshanley/vacuum)

### Additional Tools

The workspace also includes:

- **Graphviz**: For generating diagrams and dependency graphs
- **Java Development Kit**: For Java-based tools and generators
- **Python Environment**: With powerline and development tools
- **Database Clients**: PostgreSQL and MySQL clients for database operations

## Optional Tools

`hostctl` and `mkcert` are **optional but highly recommended** for the best development experience. DockerKit will work without them, but with limitations:

- **Without hostctl**: You'll need to manually edit your `/etc/hosts` file to add local domain entries
- **Without mkcert**: SSL certificates won't be generated, so only HTTP (not HTTPS) will be available

## hostctl

[hostctl](https://github.com/guumaster/hostctl) manages `/etc/hosts` entries for local development domains

- VPN-resistant (uses hosts file, not DNS)
- Profile-based management for multiple projects
- Cross-platform compatibility

### macOS DNS Performance Fix

On macOS, `.local` domains can experience 5+ second delays due to IPv6 DNS resolution timeouts. DockerKit automatically solves this by creating **dual-stack host entries**:

```text
127.0.0.1  myapp.local    # IPv4 entry
::1        myapp.local    # IPv6 entry (prevents timeout)
```

**Before fix**: `curl http://myapp.local` takes ~5.002 seconds  
**After fix**: `curl http://myapp.local` takes ~0.015 seconds (**333x faster!**)

This optimization is automatically applied during `make setup-hosts` - no manual configuration needed.

### Installation hostctl

```bash
# macOS: using Homebrew
brew install guumaster/tap/hostctl

# Linux
curl -L https://github.com/guumaster/hostctl/releases/latest/download/hostctl_linux_amd64.tar.gz | tar xz
sudo mv hostctl /usr/local/bin/

# Windows: using Chocolatey
choco install hostctl
```

## mkcert

[mkcert](https://github.com/FiloSottile/mkcert) generates locally-trusted SSL certificates

- Creates valid HTTPS certificates for development
- Automatically installs local Certificate Authority
- Browser-trusted certificates without warnings

### Installation mkcert

```bash
# macOS: using homebrew
brew install mkcert
mkcert -install

# Linux: using package manager or download
# Ubuntu/Debian: apt install libnss3-tools
# Then download from: https://github.com/FiloSottile/mkcert/releases

# Windows: chocolatey
choco install mkcert
```

### Automatic Project Type Detection

The system automatically detects your project types based on file presence:

```text
┌──────────────┬─────────────────────────────────────────────────────┐
│ Project Type │ Detection Logic                                     │
├──────────────┼─────────────────────────────────────────────────────┤
│ Laravel      │ artisan file exists                                 │
│ Symfony      │ bin/console OR symfony.lock exists                  │
│ WordPress    │ wp-config.php OR wp-content/index.php exists        │
│ Static HTML  │ index.html exists AND index.php does NOT exist      │
│ Simple PHP   │ Default fallback for other PHP projects             │
└──────────────┴─────────────────────────────────────────────────────┘
```

### Document Root Mapping

```text
Laravel/Symfony:  /var/www/{sitename.local}/public
WordPress/PHP:    /var/www/{sitename.local}
Static HTML:      /var/www/{sitename.local}
```

## Network Architecture

DockerKit implements intelligent **multi-network architecture** with automatic service discovery:

### Network Topology

```text
┌───────────────────────────────────────────────────────────────────────┐
│                             Host Machine                              │
│                                                                       │
│          Browser ──► https://myapp.local:443 ──► /etc/hosts           │
│                                                                       │
│         ┌─────────────────┐   :443/:80   ┌─────────────────┐          │
│         │   web network   │◄────────────►│ backend network │          │
│         │                 │              │                 │          │
│         │  ┌───────────┐  │              │  ┌───────────┐  │          │
│         │  │   nginx   │◄─┼──────────────┼─►│ workspace │  │          │
│         │  └───────────┘  │              │  └───────────┘  │          │
│         │                 │              │                 │          │
│         │  aliases:       │              │  aliases:       │          │
│         │  • myapp.local  │              │  • myapp.local  │          │
│         │  • api.local    │              │  • api.local    │          │
│         │  • blog.local   │              │  • blog.local   │          │
│         └─────────────────┘              └─────────────────┘          │
│                                                                       │
│         Container-to-container communication:                         │
│         HTTP:  curl http://api.local/users                            │
│         HTTPS: curl https://myapp.local/api (with SSL certs)          │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

### Automatic Network Aliases

For every discovered `.local` project, DockerKit automatically:

1. **Generates network aliases** in `docker-compose.aliases.yml`
2. **Updates container networking** for seamless inter-service communication
3. **Maintains sync** when projects are added or removed

```bash
# Example: Internal API calls work automatically
curl http://api.local/users    # From any container
curl http://blog.local/posts   # Cross-service communication
```

**Benefits:**
- ✅ **Internal routing**: Containers can resolve `myapp.local` directly
- ✅ **API communication**: Services can call each other by domain name
- ✅ **Auto-sync**: Aliases update automatically when projects are added/removed
- ✅ **Network isolation**: Proper separation between web and backend networks

## Makefile Commands

```bash
# Help & Information
make help                 # Show this help message
make status               # Show current system status

# Environment Setup  
make setup                # Complete environment setup (deps, hosts, SSL, nginx for .local projects)

# Service Management
make start                # Start all enabled services
make stop                 # Stop all services
make restart              # Restart all services

# Build Management
make build                # Build all containers
make build-nc             # Build all containers without cache
make rebuild              # Rebuild everything and start

# Development Tools
make shell                # Enter workspace container shell
make shell-nginx          # Enter nginx container shell  
make shell-root           # Enter workspace as root

# Cleanup & Maintenance
make clean-project        # Clean project resources (safer)

# System Checks & Diagnostics
make health               # Check container health status
```

## Tools Directory Structure

The `tools/` directory contains the automated environment configuration system:

```text
tools/
├── setup.sh                          # Main setup orchestrator
├── status.sh                         # System status checker
├── lib/                              # Modular library components
│   ├── core/                         # Core functionality
│   │   ├── base.sh                   # Base constants and utilities
│   │   ├── colors.sh                 # Terminal color definitions
│   │   ├── config.sh                 # Configuration management
│   │   ├── utils.sh                  # Utility functions
│   │   └── validation.sh             # Input validation
│   ├── services/                     # Service management
│   │   ├── hosts.sh                  # Host file management
│   │   ├── nginx.sh                  # Nginx configuration
│   │   ├── packages.sh               # Package installation
│   │   ├── projects.sh               # Project discovery
│   │   ├── ssl.sh                    # SSL certificate management
│   │   └── templates.sh              # Template processing
│   └── status/                       # Status checking modules
│       ├── docker-status.sh          # Docker container status
│       ├── site-status.sh            # Website availability status
│       ├── system-status.sh          # System requirements status
│       └── tools-status.sh           # Tools availability status
└── templates/                        # nginx configuration templates
    ├── laravel.conf                  # Laravel HTTP template
    ├── laravel-ssl.conf              # Laravel HTTPS template
    ├── symfony.conf                  # Symfony HTTP template
    ├── symfony-ssl.conf              # Symfony HTTPS template
    ├── wordpress.conf                # WordPress HTTP template
    ├── wordpress-ssl.conf            # WordPress HTTPS template
    ├── static.conf                   # Static HTML HTTP template
    ├── static-ssl.conf               # Static HTML HTTPS template
    ├── simple.conf                   # Simple PHP HTTP template
    └── simple-ssl.conf               # Simple PHP HTTPS template

# Container startup automation
workspace/startup/                    # Workspace container initialization
├── 01-aliases                        # Development aliases and autocomplete
├── 02-composer                       # Composer environment setup
├── 03-ca-certificates               # SSL CA certificate installation
└── 04-local-hosts                   # Automatic hosts file generation

nginx/startup/                        # Nginx container initialization
├── 01-activate-sites                # Activate nginx site configurations
├── 02-ca-certificates               # SSL CA certificate installation
└── 04-local-hosts                   # Automatic hosts file generation

# Configuration files
workspace/
├── auth.json.example                # Composer authentication template
├── auth.json                        # Your Composer credentials (gitignored)
└── crontab/                         # Scheduled tasks
    └── example                      # Example crontab configuration
```

## Container Startup Automation

DockerKit features intelligent container startup automation that configures your development environment automatically when containers start.

### Workspace Container Automation

The workspace container runs these startup scripts in sequence:

#### 01-aliases

- **Purpose**: Sets up development aliases and command autocomplete
- **Features**:
  - Enhanced bash/zsh completion for common commands
  - Docker and Git shortcuts
  - Laravel Artisan command shortcuts
  - Symfony Console command shortcuts

#### 02-composer

- **Purpose**: Configures Composer environment and installs global packages
- **Features**:
  - Performance optimization (2GB memory limit, extended timeouts)
  - Authentication setup for private repositories
  - Global plugin installation (normalize, changelogs)
  - Persistent cache configuration

#### 03-ca-certificates

- **Purpose**: Installs mkcert CA certificates for HTTPS development
- **Features**:
  - Automatic detection of CA certificates in `/ssl-ca/`
  - System-wide certificate installation
  - HTTPS support for local `.local` domains
  - Browser-trusted certificates without warnings

### Nginx Container Automation

The nginx container runs these startup scripts:

#### 01-activate-sites

- **Purpose**: Activates nginx site configurations
- **Features**:
  - Links configurations from `sites-available` to `sites-enabled`
  - Validates nginx configuration syntax
  - Reloads nginx with new configurations

#### 02-ca-certificates

- **Purpose**: Installs mkcert CA certificates
- **Features**: Same as workspace container, ensures nginx trusts local CA

### Automatic SSL and Hosts Configuration

The startup system provides seamless HTTPS development:

```bash
# Automatic process when containers start:
# 1. Detect .local projects in /var/www/
# 2. Install CA certificates if available
# 3. Generate hosts entries for each project
# 4. Test connectivity and SSL status
# 5. Report status with visual indicators

# Example output:
[INFO] Found project: myapp.local
[INFO] Adding hosts entry: myapp.local -> nginx
[SUCCESS] ✓ myapp.local (200 OK, SSL: Valid)
[INFO] Found project: api.local  
[INFO] Adding hosts entry: api.local -> nginx
[SUCCESS] ✓ api.local (200 OK, SSL: Valid)
```

### Benefits

- **Zero Configuration**: Projects work immediately after `docker compose up`
- **Automatic Discovery**: New projects are detected and configured automatically
- **SSL by Default**: HTTPS works out of the box with proper certificates
- **Status Monitoring**: Visual feedback on project availability and SSL status
- **Cross-Container Communication**: Both containers can access local projects by name

## Network Architecture

DockerKit uses a three-tier network architecture for optimal security and performance:

```text
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   WEB NETWORK   │    │ BACKEND NETWORK  │    │ MANAGEMENT NET  │
├─────────────────┤    ├──────────────────┤    ├─────────────────┤
│ • nginx         │    │ • postgres       │    │ • portainer     │
│ • workspace     │    │ • mysql          │    │                 │
│ • elasticsearch │    │ • mongo          │    │                 │
│ • dejavu        │    │ • redis          │    │                 │
│ • minio         │    │ • rabbitmq       │    │                 │
│ • mailpit       │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                        │                        │
        └────────────────────────┼────────────────────────┘
                                 │
                    workspace and nginx have 
                    access to both networks
```

### Network Segmentation

**Web Network (`web`)**

- Services with web interfaces accessible via browser
- ElasticSearch, Dejavu, Minio, Mailpit web consoles
- Nginx web server and workspace development environment

**Backend Network (`backend`)**

- Internal services (databases, cache, message queues)
- PostgreSQL, MySQL, MongoDB, Redis, RabbitMQ
- Isolated from direct web access for security

**Management Network (`management`)**

- Docker administration tools
- Portainer container management interface
- Separated from application networks

### Security Benefits

**Database Isolation**: Databases cannot be accessed directly from web services  
**Principle of Least Privilege**: Services only have access to required networks  
**Management Separation**: Admin tools are isolated from application traffic  
**Development Flexibility**: Workspace has full access for development needs  

### Service Communication

```bash
# From workspace (has access to both networks)
curl http://postgres:5432        # Backend database access
curl http://elasticsearch:9200   # Web service access

# From dejavu (web network only)
curl http://elasticsearch:9200   # Can access Elasticsearch
curl http://postgres:5432        # Cannot access database

# From postgres (backend network only)  
# No web service access - only internal services
```

### Network Aliases for .local Projects

DockerKit automatically generates network aliases for `.local` projects, enabling seamless domain resolution within the Docker network environment.

#### How It Works

When you run `make setup`, DockerKit:

1. **Scans** for `.local` projects in your workspace
2. **Generates** `docker-compose.aliases.yml` with network aliases
3. **Configures** nginx to resolve `.local` domains in both `web` and `backend` networks

#### Generated Aliases Structure

```yaml
# docker-compose.aliases.yml (auto-generated)
services:
  nginx:
    networks:
      web:
        aliases:
          - myproject.local
          - api.local
      backend:
        aliases:
          - myproject.local
          - api.local
```

**External Access**: Browser requests to `https://myproject.local` → nginx  
**Internal Access**: Workspace can make HTTP requests to `http://myproject.local` → nginx  
**Service Discovery**: Automatic domain resolution without hardcoded IPs  
**Multi-Project Support**: Each `.local` project gets its own aliases  

#### Use Cases

```bash
# From workspace container - monitoring all local sites
curl -I http://myproject.local     # Resolves to nginx, returns site status
curl -I http://api.local           # Works for API endpoints

# From PHP application - inter-service communication
$response = file_get_contents('http://api.local/data');

# From console commands - health checks
php artisan health:check --url=http://myproject.local
```

#### File Management

- **Auto-generated**: `docker-compose.aliases.yml` is created automatically
- **Version controlled**: Include in git for team consistency  
- **Self-updating**: Regenerated when new `.local` projects are added
- **Clean removal**: `make clean-project` removes the aliases file

## Nginx Template System

### Template Structure

Each project type has two templates:

- `{type}.conf` - HTTP only
- `{type}-ssl.conf` - HTTPS with SSL redirect

### Template Variables

Templates use placeholder variables that are replaced during generation:

- `{{SITE_NAME}}` - The .local domain name
- `{{DOCUMENT_ROOT}}` - Project-specific document root path

### Custom Templates

You can modify templates in `tools/templates/` to customize nginx configurations for your needs.

## Custom nginx Configuration

DockerKit provides flexible nginx customization through the `nginx/custom.d/` directory.

### Available Custom Configurations

The following configurations are automatically loaded:

```text
nginx/custom.d/
├── 00-client_body_timeout.conf    # Client body timeout settings
├── 00-client_max_body_size.conf   # Maximum upload size (100M)
├── 00-ext-gzip.conf               # Gzip compression settings
├── 00-proxy_timeout.conf          # Proxy timeout configuration (21600s)
└── 00-set-variables.conf          # Custom nginx variables
```

### Adding Custom Configuration

Create new `.conf` files in the `nginx/custom.d/` directory:

```bash
# Example: Custom security headers
echo 'add_header X-Content-Type-Options nosniff;
add_header X-Frame-Options DENY;
add_header X-XSS-Protection "1; mode=block";' > nginx/custom.d/01-security-headers.conf
```

### Configuration Priority

Files are loaded in alphabetical order. Use numeric prefixes to control loading order:

- `00-*` - Core system configurations
- `01-*` - Security configurations  
- `02-*` - Performance optimizations
- `99-*` - Override configurations

### SSL Configuration

SSL certificates and configurations are managed in:

```text
nginx/ssl/              # SSL certificates directory
nginx/sites-available/  # Generated nginx site configurations
```

## Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
# Project paths
HOST_APP_PATH=../                    # Parent directory with projects
HOST_DATA_PATH=~/.dockerkit/data     # Persistent data storage

# Database credentials
MYSQL_ROOT_PASSWORD=secret
POSTGRES_PASSWORD=secret

# Service ports
MYSQL_PORT=3306
POSTGRES_PORT=5432
REDIS_PORT=6379

# Service control (1 = enabled, 0 = disabled)
ENABLE_NGINX=1                       # Core web server (required)
ENABLE_WORKSPACE=1                   # Development environment (required)
ENABLE_POSTGRES=1                    # PostgreSQL database
ENABLE_MYSQL=0                       # MySQL database
ENABLE_MONGODB=0                     # MongoDB database
ENABLE_REDIS=1                       # Redis cache
ENABLE_RABBITMQ=1                    # Message broker
ENABLE_ELASTICSEARCH=0               # Search engine
ENABLE_DEJAVU=0                      # Elasticsearch UI
ENABLE_MINIO=1                       # Object storage
ENABLE_MAILPIT=1                     # Email testing
ENABLE_PORTAINER=1                   # Container management
```

## Logging

All services log to the `logs/` directory:

```text
logs/
├── nginx/                     # nginx access and error logs
├── php-fpm/                   # PHP-FPM logs
├── mysql/                     # MySQL logs
├── postgres/                  # PostgreSQL logs
└── workspace/                 # Development container logs
```

## Composer Configuration

DockerKit provides an optimized Composer environment with automatic authentication, global plugins, and performance tuning for PHP projects in the workspace container.

### Features

- **Performance Optimization**: 2GB memory limit, extended timeouts, and optimized caching
- **Private Repository Authentication**: Secure credential management for GitHub, GitLab, and private repositories
- **Global Plugins**: Automatic installation of development tools
- **Smart Autocomplete**: Extended command completion for all Composer commands and plugins
- **Secure Credential Handling**: Authentication files are properly managed with correct permissions

The following environment variables are automatically configured:

```bash
COMPOSER_DISABLE_XDEBUG_WARN=1 # Suppress Xdebug performance warnings
```

### Authentication Setup

For private repositories, create an authentication file:

```bash
# Copy the example template
cp workspace/auth.json.example workspace/auth.json

# Edit with your credentials
nano workspace/auth.json
```

**auth.json structure:**

```json
{
    "http-basic": {
        "repo.example.com": {
            "username": "your-username",
            "password": "your-password"
        }
    },
    "github-oauth": {
        "github.com": "your-github-token"
    },
    "gitlab-token": {
        "gitlab.com": "your-gitlab-token"
    }
}
```

**Security Notes:**

- The `auth.json` file is automatically excluded from git
- File permissions are set to 600 (owner read/write only)
- Credentials are copied to the user's Composer home directory inside the container

### Global Plugins

Two plugins are automatically installed and configured:

#### ergebnis/composer-normalize

**Purpose**: Normalizes composer.json files according to a defined schema

**Usage**: Manual execution required

```bash
# Inside the workspace container
composer normalize                       # Normalize current project
composer normalize --dry-run             # Preview changes without applying
composer normalize path/to/composer.json # Normalize specific file
```

**Benefits**:

- Consistent composer.json formatting across projects
- Alphabetical sorting of dependencies
- Validation of required fields
- Standardized property ordering

#### pyrech/composer-changelogs

**Purpose**: Displays changelogs when updating packages

**Usage**: Automatic - works during `composer update`

```bash
composer update                         # Automatically shows changelogs
composer update --with-all-dependencies # Shows changelogs for all updates
```

**Benefits**:

- Immediate visibility of changes in updated packages
- Better understanding of breaking changes
- Links to release notes and documentation
- Helps with upgrade planning

### Command Aliases and Autocomplete

The workspace container includes enhanced command completion:

```bash
# Available composer commands with autocomplete:
composer install require update remove show outdated validate status
composer dump-autoload clear-cache config global search depends why-not
composer run-script check-platform-reqs archive audit init create-project
composer self-update bump normalize changelogs
```

## Scheduled Tasks (Cron)

The workspace container includes cron support for automated task scheduling.

### Configuration

Cron jobs are configured in the `workspace/crontab/` directory:

```text
workspace/crontab/
└── example                # Example crontab file
```

Cron is controlled by these environment variables:

```bash
ENABLE_CRONTAB=1           # Enable cron daemon
CRONTAB_DIR=/workspace/crontab  # Crontab files directory
```

### Adding Cron Jobs

Create crontab files in `workspace/crontab/`:

```bash
# Example: workspace/crontab/laravel-scheduler
* * * * * cd /var/www/myproject.local && php artisan schedule:run >> /dev/null 2>&1

# Example: workspace/crontab/database-backup
0 2 * * * cd /var/www && pg_dump -h postgres -U user database > backup_$(date +\%Y\%m\%d).sql
```

Crontab files are automatically set to 644 permissions during container startup.

Cron logs are available in the workspace container logs:

```bash
make shell
sudo tail -f /var/log/cron.log
```

## DockerKit vs Laradock

| Feature                    | DockerKit                                                                                                          | Laradock                        |
|----------------------------|--------------------------------------------------------------------------------------------------------------------|---------------------------------|
| **Site Discovery**         | ✅ Automatic scanning for `.local` suffixed folders                                                                 | ❌ Manual configuration          |
| **SSL Certificates**       | ✅ Automatic SSL generation with mkcert                                                                             | ❌ Manual SSL setup              |
| **Nginx Configuration**    | ✅ Auto-generated configs with project type detection<br/>(`Laravel`, `Symfony`, `WordPress`, `PHP`, `Static HTML`) | ❌ Manual nginx configuration    |
| **Hosts Management**       | ✅ Automatic `.local` domains addition with hostctl                                                                 | ❌ Manual hosts file editing     |
| **Database Creation**      | ✅ Automatic database creation for local sites (coming soon)                                                        | ❌ Manual database setup         |
| **Container Optimization** | ✅ Multi-stage builds, smaller images, faster builds, caching                                                       | ⚠️ Traditional Docker approach  |
| **Project Maturity**       | ⚠️ Modern but newer project                                                                                        | ✅ Battle-tested, proven by time |
| **Available Services**     | ⚠️ Focused essential toolkit                                                                                       | ✅ Extensive service library     |
| **Community Support**      | ⚠️ Growing community                                                                                               | ✅ Large established community   |

### 🎯 Choose DockerKit if you want:
- **Automated workflow** for local development
- **Modern Docker practices** with optimized performance
- **Focus on essential tools** without complexity

### 🎯 Choose Laradock if you need:
- **Extensive service ecosystem** out of the box
- **Proven stability** for production-like environments
- **Large community** support and resources

## Screenshots

TODO

## Roadmap

### Recently Completed

- [x] Add Composer configuration for private repositories (GitLab, GitHub, etc)
- [x] Add flexible service management with environment variables (ENABLE_* flags)
- [x] Implement container startup automation system
- [x] Add CA certificate installation for HTTPS development
- [x] Add automatic hosts file generation for local projects
- [x] Add Service Discovery system for inter-project communication (DNS aliases, network routing)

### Planned Features

- [ ] Configure supervisor for process management
- [ ] Add Xdebug configuration documentation with IDE setup examples
- [ ] Implement automatic database creation for detected projects
- [ ] Add IDEs integration support (terminal, plugins, .devcontainer)
- [ ] Add RoadRunner support as alternative to PHP-FPM
- [ ] Add FrankenPHP support for modern PHP applications
- [ ] Add Laravel Horizon support for queue monitoring
- [ ] Add pgBadger support for PostgreSQL log analysis
- [ ] Add support for Node.js project type detection (package.json, next.config.js)
- [ ] Implement project health monitoring service (status checks, performance metrics, alerts)

## Contributing

Please see [CONTRIBUTING](https://github.com/abordage/.github/blob/master/CONTRIBUTING.md) for details.

## Security

Please review [security policy](https://github.com/abordage/.github/security/policy) on how to report
security vulnerabilities.

## Feedback

Find a bug or have a feature request? Open an issue, or better yet, submit a pull request - contribution welcome!

## Built With

- [shinsenter/php](https://github.com/shinsenter/php) - production-ready PHP Docker images with startup script system
- [guumaster/hostctl](https://github.com/guumaster/hostctl) - cross-platform hosts file manager
- [FiloSottile/mkcert](https://github.com/FiloSottile/mkcert) - simple tool for making locally-trusted development certificates

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
