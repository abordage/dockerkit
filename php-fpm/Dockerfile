# syntax=docker/dockerfile:1.4
# check=error=true

ARG PHP_VERSION=8.4
ARG TZ=UTC
ARG APP_USER=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000

# PHP Extensions (from .env)
ARG DEPENDENCY_PHP_EXTENSIONS

FROM php:${PHP_VERSION}-fpm AS base

# Import ARG values into this stage
ARG TZ=UTC
ARG APP_USER=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000

# OCI Standard Labels
LABEL org.opencontainers.image.title="DockerKit PHP-FPM"
LABEL org.opencontainers.image.description="PHP-FPM service for DockerKit development environment"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.authors="Pavel Bychko <box@abordage.dev>"
LABEL org.opencontainers.image.url="https://github.com/abordage/dockerkit"
LABEL org.opencontainers.image.source="https://github.com/abordage/dockerkit"
LABEL org.opencontainers.image.documentation="https://github.com/abordage/dockerkit/blob/main/README.md"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="DockerKit"
LABEL org.opencontainers.image.created="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

# DockerKit Specific Labels
LABEL dockerkit.service.type="web"
LABEL dockerkit.service.role="php-fpm"
LABEL dockerkit.php.version="${PHP_VERSION}"
LABEL dockerkit.user.name="${APP_USER}"
LABEL dockerkit.user.uid="${APP_UID}"

# Environment variables
ENV TZ=${TZ} \
    APP_USER=${APP_USER} \
    APP_UID=${APP_UID} \
    APP_GID=${APP_GID} \
    DEBIAN_FRONTEND=noninteractive

# Create user and group early for security
RUN groupadd -g "${APP_GID}" "${APP_USER}" && \
    useradd --no-log-init -u "${APP_UID}" -g "${APP_GID}" -m -s /bin/bash "${APP_USER}"

# ============================================================================
# Stage: System Dependencies
# ============================================================================
FROM base AS dependencies

USER root

# Install minimal system tools for PHP-FPM operation
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    # Core system tools
    ca-certificates curl gosu sudo \
    # System utilities
    xz-utils \
    # Graphics utilities for image processing
    gifsicle jpegoptim optipng pngquant \
    # Build tools (needed for PHP extensions)
    build-essential \
    # Libraries for PHP extensions
    libmagickwand-dev libssl-dev librabbitmq-dev \
    && \
    # Fix CA certificates
    update-ca-certificates --fresh && \
    c_rehash /etc/ssl/certs/ 2>/dev/null || true && \
    rm -rf /var/lib/apt/lists/*

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: PHP Extensions
# ============================================================================
FROM dependencies AS php-extensions

USER root

# Import ARG values needed in this stage
ARG DEPENDENCY_PHP_EXTENSIONS

# Install mlocati/docker-php-extension-installer
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# Install PHP extensions
RUN install-php-extensions ${DEPENDENCY_PHP_EXTENSIONS}

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: PHP-FPM Configuration
# ============================================================================
FROM php-extensions AS fpm-config

USER root

# Configure PHP-FPM pool
RUN set -eux; \
    # Create PHP-FPM log directory
    mkdir -p /var/log/php-fpm && \
    chown "${APP_USER}:${APP_GID}" /var/log/php-fpm && \
    chmod 755 /var/log/php-fpm && \
    \
    # Configure FPM pool to run as our user
    sed -i "s/user = www-data/user = ${APP_USER}/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i "s/group = www-data/group = ${APP_USER}/g" /usr/local/etc/php-fpm.d/www.conf && \
    \
    # Configure FPM to log to our directory
    sed -i "s|;access.log = log/\$pool.access.log|access.log = /var/log/php-fpm/access.log|g" /usr/local/etc/php-fpm.d/www.conf && \
    \
    # Configure FPM to catch worker output
    sed -i "s|;catch_workers_output = yes|catch_workers_output = yes|g" /usr/local/etc/php-fpm.d/www.conf && \
    \
    # Configure error log
    echo "php_admin_value[error_log] = /var/log/php-fpm/error.log" >> /usr/local/etc/php-fpm.d/www.conf

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: Final Image
# ============================================================================
FROM fpm-config AS final

USER root

# Import ARG values needed in this stage
ARG APP_USER=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000

# Configure user for sudo access (needed for entrypoint scripts)
RUN usermod -aG sudo "${APP_USER}" && \
    echo "${APP_USER} ALL=(ALL) NOPASSWD:ALL" >> "/etc/sudoers"

# ============================================================================
# ENTRYPOINT Configuration
# ============================================================================
# Copy and setup entrypoint script with proper permissions
COPY --chmod=0755 entrypoint.sh /usr/local/bin/

# Add healthcheck for PHP-FPM monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD php-fpm -t || exit 1

# Set final configuration
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["php-fpm", "-F"]

WORKDIR /var/www

# Expose PHP-FPM port
EXPOSE 9000

USER ${APP_UID}:${APP_GID}
