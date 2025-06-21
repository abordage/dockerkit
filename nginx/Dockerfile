# syntax=docker/dockerfile:1.4
# check=error=true

# Build arguments - centralized configuration
ARG PHP_VERSION=8.4
ARG TZ=UTC

# User configuration arguments
ARG APP_USER=dockerkit
ARG APP_GROUP=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000
ARG APP_PATH=/var/www

# PHP Extensions Arguments
ARG INSTALL_AST=false
ARG INSTALL_XDEBUG=false
ARG XDEBUG_PORT=9003
ARG INSTALL_MONGO=false
ARG INSTALL_AMQP=false

FROM shinsenter/php:${PHP_VERSION}-fpm-nginx AS base

# Import ARG values into this stage
ARG TZ=UTC
ARG APP_USER=dockerkit
ARG APP_GROUP=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000
ARG APP_PATH=/var/www
ARG INSTALL_AST=false
ARG INSTALL_XDEBUG=false
ARG INSTALL_MONGO=false
ARG INSTALL_AMQP=false

# OCI Standard Labels
LABEL org.opencontainers.image.title="DockerKit Nginx"
LABEL org.opencontainers.image.description="Nginx with PHP-FPM for automated local development environment"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.authors="Pavel Bychko <box@abordage.dev>"
LABEL org.opencontainers.image.url="https://github.com/abordage/dockerkit"
LABEL org.opencontainers.image.source="https://github.com/abordage/dockerkit"
LABEL org.opencontainers.image.documentation="https://github.com/abordage/dockerkit/blob/main/README.md"
LABEL org.opencontainers.image.licenses="MIT"

# DockerKit Specific Labels
LABEL dockerkit.service.type="web"
LABEL dockerkit.service.role="nginx-php"
LABEL dockerkit.php.version="${PHP_VERSION}"
LABEL dockerkit.user.name="${APP_USER}"
LABEL dockerkit.user.uid="${APP_UID}"
LABEL dockerkit.path.app="${APP_PATH}"
LABEL dockerkit.extensions.xdebug="${INSTALL_XDEBUG}"
LABEL dockerkit.extensions.mongo="${INSTALL_MONGO}"
LABEL dockerkit.extensions.amqp="${INSTALL_AMQP}"
LABEL dockerkit.healthcheck.enabled="true"
LABEL dockerkit.healthcheck.endpoint="http://localhost:80"

# Configure user environment
ENV APP_USER=${APP_USER}
ENV APP_GROUP=${APP_GROUP}
ENV APP_UID=${APP_UID}
ENV APP_GID=${APP_GID}

# Application path configuration
ENV APP_PATH=${APP_PATH}

# Enable automatic composer install and other autorun features
ENV DISABLE_AUTORUN_COMPOSER_INSTALL=1

# Runtime PHP environment variables support
ENV ALLOW_RUNTIME_PHP_ENVVARS=1

# Timezone configuration
ENV TZ=${TZ}

# Start as root for system setup
USER root

# ============================================================================
# Stage: System Dependencies
# ============================================================================
FROM base AS dependencies

# Update package lists and install system tools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    # Core system tools
    xz-utils build-essential curl parallel dnsutils ca-certificates \
    # Graphics utilities for image processing
    jpegoptim optipng pngquant gifsicle \
    # System dependencies for PHP extensions
    libmagickwand-dev \
    $([ "$INSTALL_MONGO" = "true" ] && echo "libssl-dev") \
    $([ "$INSTALL_AMQP" = "true" ] && echo "librabbitmq-dev") \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Stage: PHP Extensions
# ============================================================================
FROM dependencies AS php-extensions

# Install always-on PHP extensions
RUN phpaddmod bz2 gmp imagick inotify soap xlswriter

# Install conditional PHP extensions in parallel where possible
RUN set -eux; \
    extensions=""; \
    [ "$INSTALL_AMQP" = "true" ] && extensions="$extensions amqp"; \
    [ "$INSTALL_AST" = "true" ] && extensions="$extensions ast"; \
    [ "$INSTALL_MONGO" = "true" ] && extensions="$extensions mongodb"; \
    [ "$INSTALL_XDEBUG" = "true" ] && extensions="$extensions xdebug"; \
    [ -n "$extensions" ] && phpaddmod $extensions || true

# Set working directory
WORKDIR ${APP_PATH}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:80 || exit 1

# Validation step - ensure critical services are configured
RUN set -eux; \
    php --version; \
    nginx -v; \
    php-fpm -t; \
    echo "✓ All services validated successfully"

# Expose ports
EXPOSE 80 443
