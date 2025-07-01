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

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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
    build-essential \
    ca-certificates \
    curl \
    gifsicle \
    gosu \
    jpegoptim \
    librabbitmq-dev \
    libmagickwand-dev \
    libssl-dev \
    optipng \
    pngquant \
    sudo \
    xz-utils && \
    update-ca-certificates --fresh && \
    rm -rf /var/lib/apt/lists/*

# Configure sudo for the application user
RUN echo "${APP_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${APP_USER}" && chmod 0440 "/etc/sudoers.d/${APP_USER}"

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
RUN --mount=type=cache,target=/tmp/ipe-cache \
    install-php-extensions ${DEPENDENCY_PHP_EXTENSIONS}

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: PHP-FPM Configuration
# ============================================================================
FROM php-extensions AS fpm-config

USER root

# 1. Create PHP-FPM log directory and set permissions
RUN mkdir -p /var/log/php-fpm && \
    chown "${APP_UID}:${APP_GID}" /var/log/php-fpm

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

# ============================================================================
# ENTRYPOINT Configuration
# ============================================================================
# Copy and setup entrypoint script with proper permissions
COPY --chmod=0755 entrypoint.sh /usr/local/bin/

# Add healthcheck for PHP-FPM monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -connect 127.0.0.1:9000 || exit 1

# Set final configuration
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["php-fpm", "-F"]

WORKDIR /var/www

# Expose PHP-FPM port
EXPOSE 9000

USER ${APP_UID}:${APP_GID}
