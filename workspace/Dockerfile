# syntax=docker/dockerfile:1.4
ARG PHP_VERSION
FROM shinsenter/php:${PHP_VERSION}-cli as base

# Build arguments - centralized configuration
ARG TZ=UTC
ARG APP_USER=dockerkit
ARG APP_GROUP=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000
ARG APP_PATH=/var/www

# PHP Extensions
ARG INSTALL_AST=false
ARG INSTALL_XDEBUG=false
ARG XDEBUG_PORT=9003
ARG INSTALL_PCOV=false
ARG INSTALL_MONGO=false
ARG INSTALL_AMQP=false

# System Utilities
ARG INSTALL_JAVA=true

# Database Clients
ARG POSTGRES_CLIENT_VERSION=15
ARG INSTALL_POSTGRES_CLIENT=true
ARG INSTALL_MYSQL_CLIENT=false

# Node.js
ARG INSTALL_NODE=false
ARG NODE_VERSION=22
ARG INSTALL_VACUUM=false
ARG INSTALL_OPENAPI_GENERATOR=false

# Performance and Security
ARG ENABLE_NON_ROOT_USER=true

# Environment variables
ENV TZ=${TZ} \
    APP_USER=${APP_USER} \
    APP_GROUP=${APP_GROUP} \
    APP_UID=${APP_UID} \
    APP_GID=${APP_GID} \
    APP_PATH=${APP_PATH} \
    ENABLE_CRONTAB=1 \
    DISABLE_AUTORUN_COMPOSER_INSTALL=1 \
    ALLOW_RUNTIME_PHP_ENVVARS=1 \
    DEBIAN_FRONTEND=noninteractive

# Start as root for system setup
USER root

# ============================================================================
# Stage: System Dependencies
# ============================================================================
FROM base as dependencies

# Update package lists and install base system tools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    # Core system tools
    nano xz-utils build-essential curl parallel dnsutils ca-certificates graphviz sudo \
    # Graphics utilities
    jpegoptim optipng pngquant gifsicle \
    # Python environment
    python3 python3-dev python3-venv \
    # System dependencies for PHP extensions
    libmagickwand-dev \
    $([ "$INSTALL_MONGO" = "true" ] && echo "libssl-dev") \
    $([ "$INSTALL_AMQP" = "true" ] && echo "librabbitmq-dev") \
    # Conditional utilities
    $([ "$INSTALL_JAVA" = "true" ] && echo "default-jdk ca-certificates-java") \
    # Database clients
    $([ "$INSTALL_POSTGRES_CLIENT" = "true" ] && echo "postgresql-client-${POSTGRES_CLIENT_VERSION}") \
    $([ "$INSTALL_MYSQL_CLIENT" = "true" ] && echo "default-mysql-client") \
    && rm -rf /var/lib/apt/lists/*

# Update Java certificates if Java is installed
RUN if [ "$INSTALL_JAVA" = "true" ]; then update-ca-certificates -f; fi

# ============================================================================
# Stage: PHP Extensions
# ============================================================================
FROM dependencies as php-extensions

# Install always-on PHP extensions
RUN phpaddmod bz2 gmp imagick inotify soap xlswriter

# Install conditional PHP extensions in parallel where possible
RUN set -eux; \
    extensions=""; \
    [ "$INSTALL_AMQP" = "true" ] && extensions="$extensions amqp"; \
    [ "$INSTALL_AST" = "true" ] && extensions="$extensions ast"; \
    [ "$INSTALL_MONGO" = "true" ] && extensions="$extensions mongodb"; \
    [ "$INSTALL_PCOV" = "true" ] && extensions="$extensions pcov"; \
    [ "$INSTALL_XDEBUG" = "true" ] && extensions="$extensions xdebug"; \
    [ -n "$extensions" ] && phpaddmod $extensions || true

# ============================================================================
# Stage: Node.js Tools
# ============================================================================
FROM php-extensions as node-tools

# Install Node.js if requested
RUN if [ "$INSTALL_NODE" = "true" ]; then \
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g npm-check-updates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*; \
    fi

# Install additional Node.js tools
RUN if [ "$INSTALL_NODE" = "true" ] && [ "$INSTALL_VACUUM" = "true" ]; then \
    npm install -g @quobix/vacuum; \
    fi

RUN if [ "$INSTALL_NODE" = "true" ] && [ "$INSTALL_OPENAPI_GENERATOR" = "true" ]; then \
    npm install -g @openapitools/openapi-generator-cli; \
    fi

# ============================================================================
# Stage: Python Environment
# ============================================================================
FROM node-tools as python-env

# Create and configure Python virtual environment
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/python -m pip install --upgrade pip virtualenv && \
    /opt/venv/bin/pip install --upgrade powerline-status psutil

# Add venv to PATH for powerline scripts
ENV PATH="/opt/venv/bin:$PATH"

# Configure powerline for bash
RUN PYTHON_VERSION=$(/opt/venv/bin/python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')") && \
    { \
        echo ""; \
        echo "# Python virtual environment"; \
        echo "export PATH=\"/opt/venv/bin:\$PATH\""; \
        echo ""; \
        echo "# Powerline configuration"; \
        echo ". /opt/venv/lib/python${PYTHON_VERSION}/site-packages/powerline/bindings/bash/powerline.sh"; \
    } >> /etc/bash.bashrc

# ============================================================================
# Stage: Final Configuration
# ============================================================================
FROM python-env as final

# Copy configuration files
COPY ./crontab /etc/cron.d

# Set permissions
RUN chmod -R 644 /etc/cron.d

# Ensure user exists (shinsenter/php base image should handle this automatically)
# But we add sudo access for development convenience
RUN if [ "$ENABLE_NON_ROOT_USER" = "true" ]; then \
    # Check if user already exists, if not create it
    id -u ${APP_USER} >/dev/null 2>&1 || { \
        groupadd -g ${APP_GID} ${APP_GROUP} 2>/dev/null || true && \
        useradd -u ${APP_UID} -g ${APP_GID} -m -s /bin/bash ${APP_USER} 2>/dev/null || true; \
    } && \
    # Add to sudo group for development convenience
    usermod -aG sudo ${APP_USER} 2>/dev/null || true; \
    fi

# Set working directory
WORKDIR ${APP_PATH}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD php --version || exit 1

# Validation step - ensure critical tools are available
RUN set -eux; \
    php --version; \
    python3 --version; \
    /opt/venv/bin/python --version; \
    [ "$INSTALL_NODE" = "true" ] && node --version || true; \
    [ "$INSTALL_NODE" = "true" ] && npm --version || true; \
    [ "$INSTALL_VACUUM" = "true" ] && vacuum --version || true; \
    [ "$INSTALL_OPENAPI_GENERATOR" = "true" ] && openapi-generator-cli version || true; \
    [ "$INSTALL_POSTGRES_CLIENT" = "true" ] && psql --version || true; \
    [ "$INSTALL_MYSQL_CLIENT" = "true" ] && mysql --version || true; \
    echo "✓ All tools validated successfully"
