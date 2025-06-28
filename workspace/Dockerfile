# syntax=docker/dockerfile:1.4
# check=error=true

ARG PHP_VERSION=8.4
ARG TZ=UTC
ARG APP_USER=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000

# PHP Extensions (from .env)
ARG DEPENDENCY_PHP_EXTENSIONS

# Xdebug Configuration
ARG PHP_XDEBUG_CLIENT_PORT=9003

# System Utilities
ARG INSTALL_JAVA=true

# Database Clients
ARG INSTALL_POSTGRES_CLIENT=true
ARG INSTALL_MYSQL_CLIENT=false

# Node.js
ARG INSTALL_NODE=false
ARG NODE_VERSION=22
ARG INSTALL_VACUUM=false
ARG INSTALL_OPENAPI_GENERATOR=false

# MinIO Client
ARG INSTALL_MINIO_CLIENT=true

FROM php:${PHP_VERSION}-cli AS base

# Import ARG values into this stage
ARG TZ=UTC
ARG APP_USER=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000

# OCI Standard Labels
LABEL org.opencontainers.image.title="DockerKit Workspace"
LABEL org.opencontainers.image.description="Development workspace with PHP CLI, tools and utilities"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.authors="Pavel Bychko <box@abordage.dev>"
LABEL org.opencontainers.image.url="https://github.com/abordage/dockerkit"
LABEL org.opencontainers.image.source="https://github.com/abordage/dockerkit"
LABEL org.opencontainers.image.documentation="https://github.com/abordage/dockerkit/blob/main/README.md"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="DockerKit"
LABEL org.opencontainers.image.created="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

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

# Import ARG values needed in this stage
ARG INSTALL_JAVA=true
ARG INSTALL_MYSQL_CLIENT=false
ARG INSTALL_POSTGRES_CLIENT=true

# Install only essential system tools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    # Install packages with standard git
    apt-get update && \
    apt-get install -y --no-install-recommends \
    # Core system tools
    bash-completion build-essential ca-certificates cron curl debianutils dnsutils git gosu  \
    graphviz htop iputils-ping jq nano rsync sqlite3 sudo tree unzip wget xz-utils \
    # Archive utilities
    zip p7zip-full \
    # Graphics utilities
    gifsicle jpegoptim optipng pngquant \
    # Documentation
    man-db manpages manpages-dev \
    && \
    # Fix CA certificates
    update-ca-certificates --fresh && \
    c_rehash /etc/ssl/certs/ 2>/dev/null || true && \
    # Update manual pages database
    (command -v mandb >/dev/null 2>&1 && mandb) || true && \
    rm -rf /var/lib/apt/lists/*

# Install mlocati/docker-php-extension-installer
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# Install conditional packages
RUN set -eux; \
    packages=""; \
    [ "${INSTALL_JAVA}" = "true" ] && packages="${packages} ca-certificates-java default-jdk"; \
    [ "${INSTALL_MYSQL_CLIENT}" = "true" ] && packages="${packages} default-mysql-client"; \
    [ "${INSTALL_POSTGRES_CLIENT}" = "true" ] && packages="${packages} postgresql-client-15"; \
    if [ -n "${packages}" ]; then \
        echo "Installing conditional packages:${packages}"; \
        apt-get update; \
        apt-get install -y --no-install-recommends ${packages}; \
        rm -rf /var/lib/apt/lists/*; \
    else \
        echo "No conditional packages to install"; \
    fi

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: PHP Extensions
# ============================================================================
FROM dependencies AS php-extensions

USER root

# Import ARG values needed in this stage
ARG DEPENDENCY_PHP_EXTENSIONS

RUN install-php-extensions ${DEPENDENCY_PHP_EXTENSIONS}

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: Composer Installation
# ============================================================================
FROM php-extensions AS composer-install

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV COMPOSER_NO_INTERACTION=1 \
    COMPOSER_DISABLE_XDEBUG_WARN=1

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Update Composer to latest version
RUN composer self-update --no-interaction && \
    composer --version

USER ${APP_UID}:${APP_GID}

RUN set -eux; \
    # Configure and install plugins
    composer config --global allow-plugins.ergebnis/composer-normalize true --no-interaction; \
    composer config --global allow-plugins.pyrech/composer-changelogs true --no-interaction; \
    composer global require ergebnis/composer-normalize pyrech/composer-changelogs --no-interaction; \
    # Verify installation
    composer --version

# ============================================================================
# Stage: Node.js Tools
# ============================================================================
FROM composer-install AS node-tools

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Import ARG values needed in this stage
ARG INSTALL_NODE=false
ARG NODE_VERSION=22
ARG INSTALL_VACUUM=false
ARG INSTALL_OPENAPI_GENERATOR=false

# Install Node.js if requested
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    if [ "${INSTALL_NODE}" = "true" ]; then \
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*; \
    fi

# Install Node.js tools with NPM cache
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    if [ "${INSTALL_NODE}" = "true" ]; then \
        npm install -g npm@latest; \
        npm install -g npm-check-updates; \
        if [ "${INSTALL_VACUUM}" = "true" ]; then \
            npm install -g @quobix/vacuum; \
        fi; \
        if [ "${INSTALL_OPENAPI_GENERATOR}" = "true" ]; then \
            npm install -g @openapitools/openapi-generator-cli; \
        fi; \
    fi

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: MinIO Client Tools
# ============================================================================
FROM node-tools AS minio-tools

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Import ARG values needed in this stage
ARG INSTALL_MINIO_CLIENT=true

RUN set -eux; \
    if [ "${INSTALL_MINIO_CLIENT}" = "true" ]; then \
        echo "Installing MinIO Client..."; \
        # Test network connectivity first
        curl -fsSL --connect-timeout 10 --max-time 30 https://dl.min.io/ > /dev/null && \
        echo "MinIO download server is accessible"; \
        # Detect architecture for MinIO Client
        ARCH=$(uname -m); \
        case "$ARCH" in \
            x86_64) MC_ARCH="linux-amd64" ;; \
            aarch64) MC_ARCH="linux-arm64" ;; \
            armv7l) MC_ARCH="linux-arm" ;; \
            *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
        esac; \
        echo "Detected architecture: $ARCH, using MinIO Client variant: ${MC_ARCH}"; \
        # Download MinIO Client with retry logic
        for attempt in 1 2 3; do \
            echo "Download attempt ${attempt}/3..."; \
            if curl -fsSL --connect-timeout 10 --max-time 60 --retry 3 \
                "https://dl.min.io/client/mc/release/${MC_ARCH}/mc" \
                -o /usr/local/bin/mc; then \
                echo "MinIO Client binary downloaded successfully"; \
                break; \
            else \
                echo "Download attempt ${attempt} failed"; \
                [ ${attempt} -eq 3 ] && exit 1; \
                sleep 5; \
            fi; \
        done; \
        # Set executable permissions immediately after download
        chmod +x /usr/local/bin/mc && \
        echo "MinIO Client permissions set successfully"; \
        # Test installation
        /usr/local/bin/mc --version && \
        echo "MinIO Client installed and tested successfully"; \
    else \
        echo "MinIO Client installation skipped"; \
    fi

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: Modern Terminal Tools (fzf + ble.sh + starship)
# ============================================================================
FROM minio-tools AS modern-terminal-tools

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    echo "Installing modern terminal tools..."; \
    \
    # Verify git is available (should be inherited from dependencies stage)
    echo "Verifying git: $(git --version)"; \
    \
    # Install Nerd Fonts Symbols Only for optimal terminal experience (2MB vs 123MB)
    echo "Installing Nerd Fonts Symbols Only..."; \
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.tar.xz -o /tmp/symbols.tar.xz && \
    tar -xf /tmp/symbols.tar.xz -C /usr/share/fonts && \
    rm /tmp/symbols.tar.xz && \
    fc-cache -fv && \
    \
    # Install fzf (fuzzy finder)
    echo "Installing fzf..."; \
    git clone --depth 1 https://github.com/junegunn/fzf.git /opt/fzf && \
    /opt/fzf/install --bin && \
    cp /opt/fzf/bin/fzf /usr/local/bin/ && \
    chmod +x /usr/local/bin/fzf && \
    fzf --version && \
    \
    # Install Starship (modern prompt)
    echo "Installing Starship..."; \
    curl -sS https://starship.rs/install.sh | sh -s -- -y && \
    starship --version && \
    \
    # Install yq (YAML processor) for config management - multi-arch support
    echo "Installing yq..."; \
    ARCH=$(uname -m); \
    case "$ARCH" in \
        x86_64) YQ_ARCH="amd64" ;; \
        aarch64) YQ_ARCH="arm64" ;; \
        armv7l) YQ_ARCH="arm" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac; \
    echo "Detected architecture: $ARCH, using yq variant: linux_${YQ_ARCH}"; \
    curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH}" -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    yq --version && \
    \
    echo "All modern terminal tools installed successfully"

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: Final Image
# ============================================================================
FROM modern-terminal-tools AS final

USER root

# Import ARG values needed in this stage
ARG APP_USER=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000

# Configure user for sudo access
RUN usermod -aG sudo "${APP_USER}" && \
    echo "${APP_USER} ALL=(ALL) NOPASSWD:ALL" >> "/etc/sudoers"

# Create user directories (moved from entrypoint script for better performance)
RUN mkdir -p "/home/${APP_USER}/.config" \
             "/home/${APP_USER}/.local/bin" \
             "/home/${APP_USER}/.local/share" \
             "/home/${APP_USER}/.cache" && \
    chown -R "${APP_USER}:${APP_GID}" "/home/${APP_USER}/.config" \
                                      "/home/${APP_USER}/.local" \
                                      "/home/${APP_USER}/.cache"

# Setup bash completion for all development tools
RUN set -eux; \
    # Create bash completion directory
    mkdir -p /etc/bash_completion.d && \
    # Composer completion
    composer completion bash > /etc/bash_completion.d/composer && \
    # Docker completion (if available)
    if command -v docker >/dev/null 2>&1; then \
        docker completion bash > /etc/bash_completion.d/docker 2>/dev/null || true; \
    fi && \
    # Git completion is usually included with git package but ensure it's there
    curl -fsSL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash \
         -o /etc/bash_completion.d/git-completion.bash 2>/dev/null || true

# Configure cron
RUN set -eux; \
    # Create cron log directory with proper permissions
    mkdir -p /var/log/cron && \
    chown "${APP_USER}:${APP_GID}" "/var/log/cron" && \
    # Create cron log file
    touch /var/log/cron/cron.log && \
    chown "${APP_USER}:${APP_GID}" "/var/log/cron/cron.log" && \
    chmod 644 /var/log/cron/cron.log && \
    # Ensure cron spool directory exists with proper permissions
    mkdir -p /var/spool/cron/crontabs && \
    chmod 755 /var/spool/cron/crontabs

# ============================================================================
# ENTRYPOINT Configuration (keeping root for final setup)
# ============================================================================
# Copy and setup entrypoint script with proper permissions
COPY --chmod=0755 entrypoint.sh /usr/local/bin/

# Copy Starship configuration directly to user config directory
COPY --chown=${APP_USER}:${APP_GID} --chmod=0644 starship.toml /home/${APP_USER}/.config/starship.toml

# Add healthcheck for container monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD php --version > /dev/null || exit 1

# Set final configuration
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["bash"]

WORKDIR /var/www

USER ${APP_UID}:${APP_GID}
