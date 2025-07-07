# 🚀 Modern Docker Stack for Local Development

![GitHub Release](https://img.shields.io/github/v/release/abordage/dockerkit)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/abordage/dockerkit/hadolint.yml?label=hadolint)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/abordage/dockerkit/shellcheck.yml?label=shellcheck)
![GitHub License](https://img.shields.io/github/license/abordage/dockerkit)

**What you get:**

- **Multi-project support** — create `*.local` folders, auto-configuration handles the rest
- **Project-based automation** — automatic scanning and configuration based on your `.env` files
- **HTTPS between microservices** — containers communicate securely out of the box
- **Pre-installed dev tools** — OpenAPI Generator, Vacuum, Composer normalizer and other
- **Streamlined workflow** — `make setup`, `make start`, `make status` covers everything

 **It simply works.** No kidding.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Advanced Configuration](#advanced-configuration)
3. [Project Automation](#project-automation)
4. [Web Interfaces](#web-interfaces)
5. [Development Tools](#development-tools)
6. [Comparison](#comparison)
7. [FAQ](#faq)
8. [Roadmap](#roadmap)
9. [Contributing](#contributing)

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

Review and customize your `.env` file for your specific needs:

```bash
# Choose which services to start (comma-separated)
ENABLE_SERVICES="nginx php-fpm workspace postgres mysql redis rabbitmq elasticsearch elasticvue minio mailpit"

# Customize PHP extensions for your projects
DEPENDENCY_PHP_EXTENSIONS="amqp ast bcmath bz2 decimal exif gd gmp imagick intl opcache pcntl pcov pdo_mysql pdo_pgsql redis soap sockets sodium xdebug xlswriter yaml zip"
```

### 5. Start Services

```bash
make start
```

This command:

- Checks network aliases configuration
- Starts all enabled services in detached mode
- Uses `docker-compose.aliases.yml` for `.local` domain routing
- Shows startup status for each container

### Optional: Install Quick Access Tool

For even faster development workflow, install the `dk` command for instant workspace access:

```bash
make dk-install     # Install dk command system-wide
```

Now you can quickly access workspace from any `.local` project:

```bash
cd myapp.local      # Navigate to any .local project
dk                  # Instant access to workspace container
```

## Advanced Configuration

### Composer Configuration

For private repositories, edit `workspace/auth.json` file:

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

### Scheduled Tasks (cron)

Cron is enabled by default and reads jobs from `workspace/crontab/` directory:

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

## Project Automation

DockerKit eliminates manual configuration through comprehensive automation that works seamlessly across your entire development environment. Every `.local` project gets automatically configured based on intelligent project detection and environment file analysis.

### Automated Features

#### 1. **Project Discovery**

- **Automatic scanning** for `.local` projects in parent directory
- **Real-time detection** during setup and container startup
- **Project type identification** based on framework-specific files and structure
- **Support for multiple frameworks**: Laravel, Symfony, WordPress, Static HTML, Simple PHP

#### 2. **Project Type Detection**

- **Laravel**: Detected via `artisan` file and `laravel/framework` in composer.json
- **Symfony**: Identified by `bin/console`, `symfony.lock`, or Symfony packages in composer.json
- **WordPress**: Recognized through `wp-config.php`, `wp-content/`, or `wp-includes/` structure
- **Static HTML**: Projects with `index.html` but no server-side processing
- **Simple PHP**: Fallback for any project containing PHP files

#### 3. **Database Management**

- **Automatic database creation** for PostgreSQL and MySQL based on project `.env` files
- **User management** with appropriate permissions per project
- **Environment-specific configurations** (`.env`, `.env.testing`)
- **Legacy user support** for existing project compatibility

#### 4. **Object Storage (MinIO)**

- **Automatic bucket creation** based on `AWS_BUCKET` or `MINIO_BUCKET` in project `.env`
- **User management** using `AWS_ACCESS_KEY_ID`/`MINIO_ACCESS_KEY` credentials
- **Policy configuration** with public/private bucket support
- **Multiple project isolation** with dedicated access controls

#### 5. **Redis Cache Configuration**

- **Multi-password ACL support** for Redis default user configuration
- **Project-based scanning** for `REDIS_PASSWORD` in `.env` files
- **Deduplication logic** to avoid duplicate password configurations

#### 6. **RabbitMQ Queue Management**

- **User and virtual host creation** via Management API
- **Comprehensive permission setup** (configure, write, read)
- **Environment variable scanning** for `RABBITMQ_USER`, `RABBITMQ_PASSWORD`, `RABBITMQ_VHOST`

#### 7. **Web Server Configuration**

- **Nginx configuration generation** from project-specific templates
- **Framework-optimized configs** with modern/legacy PHP-FPM routing
- **Security headers and rules** tailored per project type
- **Performance optimizations** built into generated configurations

#### 8. **SSL Certificate Management**

- **Automatic SSL certificate generation** using mkcert for all `.local` domains
- **Certificate validation and renewal** as needed
- **HTTPS-enabled nginx configs** when certificates are available
- **Container CA installation** for internal HTTPS communication

#### 9. **Host File Management**

- **Automatic `.local` domain addition** to system hosts file using hostctl
- **Clean management** with profile-based organization
- **Cross-platform support** for macOS, Linux, and WSL2

#### 10. **Network Configuration**

- **Docker Compose aliases generation** for microservice communication
- **Internal DNS resolution** for `.local` domains within Docker network
- **Service discovery** enabling containers to communicate via project domains
- **Network isolation** with secure inter-container communication

#### 11. **Development Environment Setup**

- **Configuration file creation** from examples (`.env`, auth.json, php.ini)
- **Directory structure preparation** for logs, certificates, configurations
- **Permission management** ensuring proper file access across containers

### Automation Scripts

DockerKit's automation is powered by initialization scripts that run during container startup, ensuring your development environment is always properly configured.

#### Workspace Container (`workspace/entrypoint.d/`)

**`01-ca-certificates`**

- Installs mkcert CA certificates for HTTPS development
- Enables secure communication between containers
- Updates system certificate store automatically

**`02-redis-setup`**

- Configures Redis ACLs with multiple password support
- Scans Laravel/Symfony projects for `REDIS_PASSWORD` in `.env` files
- Ensures secure access while maintaining development flexibility

**`03-rabbitmq-setup`**

- Creates RabbitMQ users, virtual hosts, and permissions
- Scans all project types for RabbitMQ configuration
- Uses Management API for comprehensive setup
- Supports `RABBITMQ_USER`, `RABBITMQ_PASSWORD`, `RABBITMQ_VHOST` variables

**`04-minio-setup`**

- Scans all `.local` projects for MinIO/AWS configuration
- Creates users and buckets based on project `.env` files
- Sets up appropriate bucket policies (public/private)
- Handles credential management and access control

**`05-database-setup`**

- Analyzes project `.env` files for database configuration
- Creates PostgreSQL/MySQL databases and users automatically
- Applies proper permissions and access controls
- Supports multiple environment files per project

#### PHP-FPM Container (`php-fpm/entrypoint.d/`)

**`01-ca-certificates`**

- Installs CA certificates for secure HTTPS requests from PHP applications
- Enables verification of SSL certificates in development environment

### Automation Workflow

1. **Project Scan**: DockerKit automatically discovers all `.local` projects in the parent directory
2. **Type Detection**: Each project is analyzed to determine its framework/type
3. **Environment Analysis**: Project `.env` files are parsed for service configurations
4. **Resource Creation**: Databases, storage buckets, users, and certificates are created
5. **Configuration Generation**: Nginx configs, network aliases, and host entries are generated
6. **Service Integration**: All services are configured to work together seamlessly

This comprehensive automation means you can simply create a new `.local` project folder, add your code, run `make setup`, and everything else is handled automatically.

## Web Interfaces

| Service           | URL                      | Credentials           | Purpose           |
|-------------------|--------------------------|-----------------------|-------------------|
| **Mailpit**       | <http://localhost:8125>  | -                     | Email testing     |
| **MinIO Console** | <http://localhost:9001>  | dockerkit / dockerkit | File storage      |
| **RabbitMQ**      | <http://localhost:15672> | dockerkit / dockerkit | Message queues    |
| **Elasticvue**    | <http://localhost:9210>  | -                     | Elasticsearch UI  |
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

### Deployment Tools

#### Deployer

Modern deployment tool for PHP applications with zero-downtime deployments:

```bash
# Initialize deployer in your project
dep init

# Deploy to staging
dep deploy staging

# Deploy to production
dep deploy production

# Rollback if something goes wrong
dep rollback

# List available tasks
dep list
```

**Key Features:**

- **Zero-downtime deployments** with automatic rollback support
- **Multi-server deployments** with parallel execution
- **Framework recipes** for Laravel, Symfony, WordPress, and more
- **Server provisioning** with automatic PHP, MySQL, and HTTPS setup

**Documentation:** [deployer.org](https://deployer.org)

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

### Database Dump Management

DockerKit includes a comprehensive database dump management system with support for MySQL and PostgreSQL.

#### Features

- **Interactive workflow** with step-by-step database and operation selection
- **MySQL and PostgreSQL support** with automatic driver detection  
- **Compression support** with optional gzip compression for smaller files

#### Usage

```bash
# Start interactive dump manager
make dump

# Follow the prompts:
# 1. Select database type (MySQL/PostgreSQL)
# 2. Select operation (Backup database/Restore database)
# 3. Complete the workflow based on your choice
```

#### Manual File Placement

You can also manually place dump files in the appropriate directories:

```bash
# Copy external dumps to DockerKit
cp /path/to/external.sql dumps/mysql/
cp /path/to/backup.sql.gz dumps/postgres/

# Then use 'make dump' to restore them
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

**Automatic Project Integration:** DockerKit automatically creates users/buckets based on project `.env` configurations during container startup.

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

## Common Commands

### Essential Commands

```bash
make setup         # Initial setup (run once)
make start         # Start all services  
make stop          # Stop all services
make restart       # Restart all services
make status        # Check system status
```

### Database Management

```bash
make dump          # Interactive database backup/restore tool
```

### Quick Access Tool

Install `dk` command for instant workspace access from any `.local` project:

```bash
make dk-install    # Install dk command system-wide
make dk-uninstall  # Remove dk command from system
```

**Usage:**

```bash
# Navigate to any .local project and run:
cd myapp.local
dk                 # Quick connect to workspace

# Show version and help
dk --version       # Show dk version
dk --help          # Show help information
```

**Features:**

- **Auto-discovery:** Detects available DockerKit instances automatically
- **Smart routing:** Connects to the appropriate workspace based on current project
- **Cross-platform:** Works on macOS, Linux, and WSL2
- **Shell integration:** Adds to PATH and creates shell function automatically

### Maintenance

```bash
make build         # Rebuild containers
make reset         # Clean project resources
```

## Comparison

### DockerKit vs Laradock

| Feature                    | DockerKit                                                      | Laradock                        |
|----------------------------|----------------------------------------------------------------|---------------------------------|
| **Project Discovery**      | ✅ Automatic scanning for `.local` suffixed folders             | ❌ Manual configuration          |
| **SSL Certificates**       | ✅ Automatic SSL generation with mkcert                         | ❌ Manual SSL setup              |
| **Nginx Configuration**    | ✅ Auto-generated configs with project type detection           | ❌ Manual nginx configuration    |
| **Hosts Management**       | ✅ Automatic `.local` domains addition with hostctl             | ❌ Manual hosts file editing     |
| **MinIO Management**       | ✅ Automatic user/bucket creation based on project .env files   | ❌ Manual bucket setup           |
| **Database Creation**      | ✅ Automatic database/user creation based on project .env files | ❌ Manual database setup         |
| **Container Optimization** | ✅ Multi-stage builds, smaller images, faster builds, caching   | ⚠️ Traditional Docker approach  |
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

## FAQ

### Can I use this with existing projects?

Yes! Just rename your project folder to `myproject.local` and run `make setup`.

### Does it work on Windows?

Yes, through WSL2. Install Docker Desktop with WSL2 backend.

### Can I add custom services?

Yes! Edit `docker-compose.yml` to add any Docker service you need.

## Roadmap

- [x] Add MinIO Client integration with automatic bucket management
- [x] Implement project-based MinIO automation (automatic user/bucket creation from .env files)
- [x] Add Composer configuration for private repositories (GitLab, GitHub, etc)
- [x] Add flexible service management with environment variables (ENABLE_* flags)
- [x] Implement container startup automation system
- [x] Add CA certificate installation for HTTPS development
- [x] Add automatic hosts file generation for local projects
- [x] Add Service Discovery system for inter-project communication (DNS aliases, network routing)
- [x] Add a quick access tool (dk command) for instant workspace connection from any .local project
- [x] Add comprehensive database dump management system with MySQL/PostgreSQL support
- [ ] Configure supervisor for process management
- [ ] Add Xdebug configuration documentation with IDE setup examples
- [x] Implement automatic database and user creation for detected projects
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
