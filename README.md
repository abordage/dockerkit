# 🚀 Modern Docker Stack for Local Development

![GitHub Release](https://img.shields.io/github/v/release/abordage/dockerkit)
![GitHub last commit](https://img.shields.io/github/last-commit/abordage/dockerkit)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/abordage/dockerkit/hadolint.yml?label=hadolint)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/abordage/dockerkit/shellcheck.yml?label=shellcheck)
![GitHub License](https://img.shields.io/github/license/abordage/dockerkit)

**What you get:**

- **Multi-project support** — create `*.local` folders, auto-configuration handles the rest
- **Full site automation** — generate nginx configs, SSL certificates, auto-create databases, /etc/hosts management
- **HTTPS between microservices** — containers communicate securely out of the box
- **Pre-installed dev tools** — OpenAPI Generator, Vacuum, Composer normalizer pre-installed
- **Streamlined workflow** — `make setup`, `make start`, `make status` covers everything

 **It simply works.** No kidding.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Advanced Configuration](#advanced-configuration)
   - [Container Startup Automation](#container-startup-automation)
   - [Nginx Configuration](#nginx-configuration)
   - [Composer Configuration](#composer-configuration)
   - [Scheduled Tasks](#scheduled-tasks)
3. [Web Interfaces](#web-interfaces)
4. [Development Tools](#development-tools)
5. [Architecture Overview](#architecture-overview)
6. [Common Commands](#common-commands)
7. [Troubleshooting](#troubleshooting)
8. [Comparison](#comparison)
9. [FAQ](#faq)
10. [Roadmap](#roadmap)
11. [Contributing](#contributing)

## Quick Start

### Understanding the Structure

DockerKit scans the **parent directory** for `.local` projects:

```text
/Users/<user>/PhpstormProjects/
├── dockerkit/         # This repository
├── myapp.local/       # Detected: Laravel project
├── api.local/         # Detected: Symfony project
├── blog.local/        # Detected: WordPress project
├── backup-files/      # Ignored
└── docs/              # Ignored
```

### 1. Install Dependencies (recommended)

`hostctl` and `mkcert` are **optional but highly recommended** for the best development experience. DockerKit will work without them, but with limitations:

- **without hostctl**: You'll need to manually edit your `/etc/hosts` file to add local domain entries
- **without mkcert**: SSL certificates won't be generated, so only HTTP (not HTTPS) will be available

```bash
# macOS: using Homebrew
brew install guumaster/tap/hostctl
brew install mkcert && mkcert -install

# Windows: using Chocolatey
choco install hostctl
choco install mkcert && mkcert -install

# Linux: download binary from
https://github.com/guumaster/hostctl/releases
https://github.com/FiloSottile/mkcert/releases
```

### 2. Clone Repository

```bash
# Navigate to your projects directory
cd /path/to/your/projects

# Clone DockerKit
git clone https://github.com/abordage/dockerkit dockerkit
cd dockerkit
```

### 3. Run Setup

```bash
make setup
```

This will automatically:

- Create `.env` file from `.env.example`
- Detect your `.local` projects
- Generate `SSL certificates`
- Create `nginx configurations`
- Set up `hosts file` entries

### 4. Review Configuration

Edit `ENABLE_*` flags to customize your stack.

```bash
nano .env
```

### 5. Start Services

```bash
make start
```

This command:

- Checks network aliases configuration
- Starts all enabled services (`ENABLE_*=1`) in detached mode
- Uses `docker-compose.aliases.yml` for `.local` domain routing
- Shows startup status for each container

### Access Your Projects

Your projects are now available:

- <https://myapp.local>
- <https://api.local>
- <https://blog.local>

## Advanced Configuration

### Container Startup Automation

DockerKit uses automated startup scripts to configure development environment on container launch.

#### Workspace Container Startup

The workspace container automatically executes these initialization scripts:

```text
workspace/entrypoint.d/
├── 01-ca-certificates   # Install SSL CA certificates for HTTPS
├── 02-php-config        # Generate PHP configuration from environment
├── 03-minio-client      # Configure MinIO Client and create buckets
├── 04-bash-config       # Configure bash environment with autocomplete
└── 05-database-setup    # Automatic database creation for .local projects
```

#### Key features

- **SSL certificates:** Local HTTPS certificates for development sites
- **PHP configuration:** Dynamic PHP settings from environment variables
- **MinIO buckets:** Automatic bucket creation with configurable policies
- **Bash environment:** Complete development shell with Laravel/Symfony autocomplete
- **Database automation:** Automatic database creation based on .env files
- **Development aliases:** `art` (artisan), `fresh`, `migrate`, `pint`, `pest`
- **Auto-completion:** Laravel Artisan and Composer commands
- **Composer auth:** Automatic setup from `workspace/auth.json`

#### PHP-FPM Container Startup

The PHP-FPM container runs these initialization scripts:

```text
php-fpm/entrypoint.d/
├── 01-ca-certificates   # Install SSL CA certificates for PHP requests
└── 02-php-config        # Generate PHP configuration from environment
```

#### Custom Startup Scripts

Add custom scripts to `workspace/entrypoint.d/` or `php-fpm/entrypoint.d/`:

```bash
# workspace/entrypoint.d/99-custom-setup
#!/bin/bash
echo "Running custom workspace setup..."
# Your custom initialization code
```

**Note:** Scripts execute in alphabetical order. Use numeric prefixes (00-, 01-, etc.) to control execution sequence.

### Database Automation

DockerKit automatically creates databases for your `.local` projects by scanning environment files.

#### Supported Databases

- **MySQL/MariaDB** (`DB_CONNECTION=mysql`)
- **PostgreSQL** (`DB_CONNECTION=pgsql`)

#### How it works

1. **Project Detection:** Scans `/var/www/*.local` directories
2. **Environment Parsing:** Reads `.env` and `.env.testing` files
3. **Database Creation:** Creates databases based on `DB_CONNECTION` and `DB_DATABASE`
4. **Project Types:** Supports Laravel, Symfony, WordPress, and simple PHP projects

#### Configuration Example

```bash
# .env file in your project
DB_CONNECTION=mysql
DB_DATABASE=myapp_local

# .env.testing file
DB_CONNECTION=pgsql  
DB_DATABASE=myapp_testing
```

#### Manual Database Creation

```bash
# MySQL
mysql -h mysql -u dockerkit -p -e "CREATE DATABASE myapp_local;"

# PostgreSQL
PGPASSWORD=dockerkit createdb -h postgres -U dockerkit myapp_local
```

### Nginx Configuration

DockerKit provides flexible nginx customization through configuration snippets:

```text
nginx/snippets/
├── security.conf          # Security headers and restrictions
├── ssl-params.conf        # SSL/TLS configuration  
├── php-fpm.conf           # PHP-FPM backend settings
└── modern-fpm.conf        # Optimized PHP-FPM config
```

#### Adding Custom Rules

Create `.conf` files in `nginx/conf.d/` for custom server blocks.

### Composer Configuration

For private repositories, create `auth.json` file:

```bash
# Copy the example template
cp workspace/auth.json.example workspace/auth.json

# Edit with your credentials
nano workspace/auth.json
```

#### auth.json structure

```json
{
   "http-basic": {
      "private.repo.com": {
         "username": "your-username",
         "password": "your-password"
      }
   },
   "github-oauth": {
      "github.com": "ghp_your_personal_access_token"
   },
   "gitlab-token": {
      "gitlab.com": "glpat-your_project_access_token"
   },
   "bitbucket-oauth": {
      "bitbucket.org": {
         "consumer-key": "your-key",
         "consumer-secret": "your-secret"
      }
   }
}
```

**Security:** File is git-ignored and has restricted permissions (600) inside containers.

### Scheduled Tasks

Automated task execution using cron in the workspace container.

#### Configuration

Cron is enabled by default and reads jobs from `workspace/crontab/` directory:

```bash
CRONTAB_DIR=/etc/crontab.d  # Crontab directory (mapped from workspace/crontab)
```

#### Add Scheduled Tasks

Create crontab files in `workspace/crontab/`:

##### Laravel Scheduler

```bash
# workspace/crontab/scheduler
* * * * * /usr/local/bin/php /var/www/myapp.local/artisan schedule:run >> /var/log/cron/scheduler.log 2>&1
```

##### Database Backup

```bash  
# workspace/crontab/backup
0 2 * * * /usr/bin/pg_dump -h postgres -U dockerkit -d default > /var/www/backup_$(date +\%Y\%m\%d).sql 2>> /var/log/cron/backup.log
```

##### Log Cleanup

```bash
# workspace/crontab/cleanup
0 0 * * 0 find /var/www/*/storage/logs -name "*.log" -mtime +30 -delete 2>> /var/log/cron/cleanup.log
```

**Apply changes:** `make restart`

### MinIO Object Storage Configuration

DockerKit provides automated MinIO bucket management with configurable access policies.

#### Environment Configuration

Configure bucket creation in your `.env` file:

```bash
# MinIO Client Configuration
INSTALL_MINIO_CLIENT=true
MINIO_CLIENT_WAIT_TIME=60

# Bucket Categories with Access Policies
MINIO_BUCKETS_PUBLIC=documents,shared       # Public read/write access
MINIO_BUCKETS_UPLOAD=uploads,forms          # Upload-only access
MINIO_BUCKETS_DOWNLOAD=media,assets         # Download-only access  
MINIO_BUCKETS_PRIVATE=backups,logs          # Private access only

# Optional Features
MINIO_ENABLE_VERSIONING=false               # Enable bucket versioning
```

#### Bucket Access Policies

| Policy Type  | Read Access | Write Access | Use Case            |
|--------------|-------------|--------------|---------------------|
| **public**   | ✅ Anonymous | ✅ Anonymous  | Public file sharing |
| **upload**   | ❌ Auth only | ✅ Anonymous  | File upload forms   |
| **download** | ✅ Anonymous | ❌ Auth only  | Public downloads    |
| **private**  | ❌ Auth only | ❌ Auth only  | Secure storage      |

#### Automatic Setup Process

During container startup, DockerKit automatically:

1. **Validates** MinIO service availability
2. **Creates** configured buckets if they don't exist
3. **Applies** access policies based on bucket categories
4. **Enables** versioning if configured
5. **Logs** setup status for debugging

#### Manual Bucket Management

Access workspace container for manual operations:

```bash
# Enter workspace container
make shell

# List existing buckets
mc ls minio

# Create bucket with specific policy
mc mb minio/new-bucket
mc anonymous set download minio/new-bucket

# Check bucket policy
mc anonymous get minio/new-bucket
```

## Web Interfaces

| Service           | URL                      | Credentials           | Purpose           |
|-------------------|--------------------------|-----------------------|-------------------|
| **Mailpit**       | <http://localhost:8125>  | -                     | Email testing     |
| **MinIO Console** | <http://localhost:9001>  | dockerkit / dockerkit | File storage      |
| **RabbitMQ**      | <http://localhost:15672> | dockerkit / dockerkit | Message queues    |
| **Portainer**     | <http://localhost:9010>  | Setup on first visit  | Docker management |

## Development Tools

The workspace container includes a comprehensive set of pre-installed development tools for modern web development.

### API Development Tools

#### OpenAPI Generator CLI

Generate client libraries, server stubs, and API documentation from OpenAPI specifications:

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

#### Vacuum OpenAPI Linter

OpenAPI specification linter and quality checker:

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

### Composer Global Tools

#### ergebnis/composer-normalize

Normalizes `composer.json` files according to a defined schema:

```bash
# Normalize current project
composer normalize

# Preview changes without applying
composer normalize --dry-run

# Normalize specific file
composer normalize path/to/composer.json
```

#### pyrech/composer-changelogs

Displays changelogs when updating packages:

```bash
# Automatically shows changelogs during updates
composer update

# Shows changelogs for all dependencies
composer update --with-all-dependencies
```

### Database Tools

#### PostgreSQL Client

Direct database access and operations:

```bash
# Connect to PostgreSQL
psql -h postgres -U dockerkit -d default

# Export database
pg_dump -h postgres -U dockerkit -d default > backup.sql

# Import database
psql -h postgres -U dockerkit -d default < backup.sql
```

#### MySQL Client

```bash
# Connect to MySQL
mysql -h mysql -u dockerkit -p

# Export database
mysqldump -h mysql -u dockerkit -p default > backup.sql
```

### Object Storage Tools

#### MinIO Client (mc)

MinIO Client provides command-line interface for object storage operations and bucket management:

```bash
# List all buckets
mc ls minio

# Create new bucket
mc mb minio/my-new-bucket

# Set bucket policy (public, upload, download, private)
mc anonymous set public minio/documents
mc anonymous set upload minio/uploads
mc anonymous set download minio/media

# Copy files to bucket
mc cp ./file.txt minio/documents/

# Sync directory with bucket
mc mirror ./assets/ minio/assets/

# Enable versioning
mc version enable minio/backups

# Get bucket info
mc stat minio/documents
```

**Automatic Bucket Creation:** DockerKit automatically creates and configures buckets based on environment variables during container startup.

### Terminal Navigation Tools

#### fzf (Fuzzy Finder)

fzf is a fast, interactive command-line fuzzy finder that enhances file navigation and command history searching.

#### Key Features

- **Interactive file search** with fuzzy matching
- **Command history search** with instant filtering  
- **Directory navigation** with preview support
- **Git integration** for branches, commits, and files
- **Customizable preview** for files and directories

#### Keyboard Shortcuts

| Shortcut | Function       | Description                                |
|----------|----------------|--------------------------------------------|
| `Ctrl+T` | File finder    | Find files/directories in current path     |
| `Ctrl+R` | History search | Search command history with fuzzy matching |

## Architecture Overview

### Network Topology

DockerKit implements intelligent **multi-network architecture** with automatic service discovery:

```text
┌───────────────────────────────────────────────────────────────────────┐
│                             Host Machine                              │
│                                                                       │
│          Browser ──► https://myapp.local:443 ──► /etc/hosts           │
│                                                                       │
│         ┌─────────────────┐   :443/:80   ┌─────────────────┐          │
│         │   web network   │◄────────────►│ backend network │          │
│         │                 │              │                 │          │
│         │  ┌───────────┐  │   :443/:80   │  ┌───────────┐  │          │
│         │  │           │◄─┼──────────────┼──│ workspace │  │          │
│         │  │           │  │              │  └───────────┘  │          │
│         │  │   nginx   │  │   :443/:80   │  ┌───────────┐  │          │
│         │  │           │◄─┼──────────────┼──│           │  │          │
│         │  │           │  │     :9000    │  │  php-fpm  │  │          │
│         │  │           │──┼──────────────┼─►│           │  │          │
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
│         nginx → php-fpm:9000 (FastCGI protocol)                       │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

### Network Segmentation

DockerKit uses a **three-tier network architecture** for optimal security and performance:

```text
┌─────────────────┐       ┌──────────────────┐       ┌─────────────────┐
│   WEB NETWORK   │       │ BACKEND NETWORK  │       │ MANAGEMENT NET  │
├─────────────────┤       ├──────────────────┤       ├─────────────────┤
│ • nginx         │───────│ • nginx          │       │ • portainer     │
│ • workspace     │───────│ • workspace      │       │                 │
│ • php-fpm       │───────│ • php-fpm        │       │                 │
│ • elasticsearch │       │ • postgres       │       │                 │
│ • dejavu        │       │ • mysql          │       │                 │
│ • minio         │       │ • mongo          │       │                 │
│ • mailpit       │       │ • redis          │       │                 │
│                 │       │ • rabbitmq       │       │                 │
└─────────────────┘       └──────────────────┘       └─────────────────┘
```

**Bridge Services:** nginx, workspace, and php-fpm belong to both web and backend networks, enabling seamless communication between tiers.

### Network Aliases

Every `.local` project gets automatic network aliases across all containers:

```bash
# From any container, these work automatically:
curl http://myapp.local/api
curl https://blog.local/posts
curl http://api.local/users
```

### External Ports (accessible from host)

| Port  | Service             | URL                      | Description                 |
|-------|---------------------|--------------------------|-----------------------------|
| 80    | Nginx HTTP          | <http://localhost>       | Web server (HTTP)           |
| 443   | Nginx HTTPS         | <https://localhost>      | Web server (HTTPS)          |
| 3000  | BrowserSync         | <http://localhost:3000>  | Live reload server          |
| 3001  | BrowserSync UI      | <http://localhost:3001>  | BrowserSync control panel   |
| 5173  | Vite                | <http://localhost:5173>  | Frontend dev server         |
| 5432  | PostgreSQL          | localhost:5432           | Database connection         |
| 6379  | Redis               | localhost:6379           | Cache/session storage       |
| 8125  | Mailpit             | <http://localhost:8125>  | Email testing interface     |
| 9001  | MinIO Console       | <http://localhost:9001>  | Object storage management   |
| 9002  | MinIO API           | <http://localhost:9002>  | S3-compatible API           |
| 9010  | Portainer           | <http://localhost:9010>  | Docker management interface |
| 15672 | RabbitMQ Management | <http://localhost:15672> | Message queue management    |

```text
Host Machine Ports:
├── 9001 → MinIO Console
├── 9002 → MinIO API  
└── 9010 → Portainer

Docker Internal Networks:
├── php-fpm:9000 ← Nginx (FastCGI)
├── minio:9000 (S3 API)
└── portainer:9000 (Web UI)
```

**Note:** Multiple containers can use the same internal port (9000) because they're mapped to different external ports.

#### Generated files

- `docker-compose.aliases.yml` - Network alias definitions
- Updated when running `make setup`

## Common Commands

### Essential Commands

```bash
make setup         # Initial setup (run once)
make start         # Start all services  
make stop          # Stop all services
make restart       # Restart all services
make status        # Check system status
```

### Development

```bash
make shell         # Access workspace container
make shell-root    # Access workspace as root
make health        # Check container health
```

### Maintenance

```bash
make build         # Rebuild containers
make reset         # Clean project resources
```

## Troubleshooting

### Services won't start

```bash
make status  # Comprehensive system diagnostics
make health  # Check container health status
```

### Sites not accessible

- Verify `/etc/hosts` entries: `hostctl list`
- Test nginx config: `make shell-nginx` → `nginx -t`

View container logs:

```bash
docker compose logs nginx     # Nginx logs
docker compose logs php-fpm   # PHP-FPM logs
docker compose logs workspace # Workspace logs
```

#### MinIO Buckets not created automatically

Check workspace container logs:

```bash
docker compose logs workspace | grep -i minio
```

Common solutions:

- Increase `MINIO_CLIENT_WAIT_TIME=120` in `.env`
- Verify MinIO service is running: `docker compose ps minio`
- Check bucket names are valid (lowercase, no spaces)

#### MinIO Console not accessible

Verify service status and port mapping:

```bash
docker compose ps minio           # Check container status
curl http://localhost:9001        # Test console access
```

#### S3 API connection issues

Test MinIO API endpoint:

```bash
curl http://localhost:9002/minio/health/live
```

### Slow local site response on macOS (5+ seconds)

macOS has IPv6 DNS resolution timeouts for `.local` domains. DockerKit automatically fixes this by adding **dual-stack entries**:

```text
# Automatic fix during `make setup`:
127.0.0.1  myapp.local    # IPv4 entry  
::1        myapp.local    # IPv6 entry (prevents timeout)
```

**Manual fix** (if adding hosts entries manually):

```bash
# Add both IPv4 and IPv6 entries
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts
echo "::1 myapp.local" | sudo tee -a /etc/hosts
```

Performance impact:

- **Before fix:** ~5.002 seconds per request
- **After fix:** ~0.015 seconds (**333x faster!**)

### Performance issues

System resources:

- Increase Docker resources (RAM/CPU in Docker Desktop)
- Check resource usage: `docker stats`

Debugging:

- Review service logs: `tail -f logs/*/error.log`
- Check disk space: `df -h`
- Monitor container performance: `docker compose top`

## Comparison

### DockerKit vs Laradock

| Feature                     | DockerKit                                                    | Laradock                        |
|-----------------------------|--------------------------------------------------------------|---------------------------------|
| **Site Discovery**          | ✅ Automatic scanning for `.local` suffixed folders           | ❌ Manual configuration          |
| **SSL Certificates**        | ✅ Automatic SSL generation with mkcert                       | ❌ Manual SSL setup              |
| **Nginx Configuration**     | ✅ Auto-generated configs with project type detection         | ❌ Manual nginx configuration    |
| **Hosts Management**        | ✅ Automatic `.local` domains addition with hostctl           | ❌ Manual hosts file editing     |
| **MinIO Bucket Management** | ✅ Automatic bucket creation with configurable policies       | ❌ Manual bucket setup           |
| **Database Creation**       | ✅ Automatic database creation for local sites                | ❌ Manual database setup         |
| **Container Optimization**  | ✅ Multi-stage builds, smaller images, faster builds, caching | ⚠️ Traditional Docker approach  |
| **Project Maturity**        | ⚠️ Modern but newer project                                  | ✅ Battle-tested, proven by time |
| **Available Services**      | ⚠️ Focused essential toolkit                                 | ✅ Extensive service library     |
| **Community Support**       | ⚠️ Growing community                                         | ✅ Large established community   |

#### 🎯 Choose DockerKit if you want

- **Automated workflow** for local development
- **Modern Docker practices** with optimized performance
- **Focus on essential tools** without complexity

#### 🎯 Choose Laradock if you need

- **Extensive service ecosystem** out of the box
- **Proven stability** for production-like environments
- **Large community** support and resources

## FAQ

### Can I use this with existing projects?

Yes! Just rename your project folder to `myproject.local` and run `make setup`.

### Does it work on Windows?

Yes, through WSL2. Install Docker Desktop with WSL2 backend.

### Can I add custom services?

Yes! Edit `docker-compose.yml` to add any Docker service you need.

### How do I manage MinIO buckets?

Buckets are automatically created during container startup based on your `.env` configuration. For manual management:

```bash
make shell              # Enter workspace container
mc ls minio             # List buckets
mc mb minio/new-bucket  # Create bucket
```

### Can I change bucket policies after creation?

Yes! Use MinIO Client commands:

```bash
mc anonymous set public minio/my-bucket    # Make public
mc anonymous set private minio/my-bucket   # Make private
```

## Roadmap

- [x] Add MinIO Client integration with automatic bucket management
- [x] Implement configurable bucket access policies (public, upload, download, private)
- [x] Add bucket versioning support for MinIO storage
- [x] Add Composer configuration for private repositories (GitLab, GitHub, etc)
- [x] Add flexible service management with environment variables (ENABLE_* flags)
- [x] Implement container startup automation system
- [x] Add CA certificate installation for HTTPS development
- [x] Add automatic hosts file generation for local projects
- [x] Add Service Discovery system for inter-project communication (DNS aliases, network routing)
- [ ] Configure supervisor for process management
- [ ] Add Xdebug configuration documentation with IDE setup examples
- [x] Implement automatic database creation for detected projects
- [ ] Add support for Python project type detection (requirements.txt, pyproject.toml)
- [ ] Add support for Node.js project type detection (package.json, next.config.js)
- [ ] Add MongoDB database support with automatic collection setup
- [ ] Add RoadRunner support as an alternative to PHP-FPM
- [ ] Add FrankenPHP support for modern PHP applications
- [ ] Add Laravel Horizon support for queue monitoring
- [ ] Add pgBadger support for PostgreSQL log analysis
- [ ] Migrate Portainer to secure HTTPS port 9443* (currently using HTTP on 9010)

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
