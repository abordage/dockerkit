# syntax=docker/dockerfile:1.4
# check=error=true

ARG PHP_VERSION=8.4
ARG TZ=UTC
ARG APP_USER=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000

# PHP Extensions (from .env)
ARG DEPENDENCY_PHP_EXTENSIONS

# Node.js
ARG NODE_VERSION=22

# Xdebug Configuration
ARG PHP_XDEBUG_CLIENT_PORT=9003

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
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install essential system tools, database clients, and Java
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    bash-completion \
    build-essential \
    ca-certificates \
    ca-certificates-java \
    cron \
    debianutils \
    default-jdk \
    default-mysql-client \
    dnsutils \
    gifsicle \
    gosu \
    graphviz \
    gnupg \
    iputils-ping \
    jpegoptim \
    lsb-release \
    nano \
    openssh-client \
    optipng \
    p7zip-full \
    pngquant \
    sudo \
    tree \
    unzip \
    xz-utils \
    zip && \
    update-ca-certificates --fresh && \
    rm -rf /var/lib/apt/lists/*

# Configure sudo for dockerkit user
RUN echo "${APP_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${APP_USER}" && chmod 0440 "/etc/sudoers.d/${APP_USER}"

# Install latest versions from Debian Backports for better features and security
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    # Add Debian Backports repository \
    echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/backports.list && \
    apt-get update && \
    # Install latest versions from backports \
    apt-get install -y --no-install-recommends -t bookworm-backports \
    curl \
    git \
    htop \
    jq \
    redis-tools \
    rsync \
    sqlite3 \
    wget && \
    rm -rf /var/lib/apt/lists/*

# Install PostgreSQL 17 client
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends postgresql-client-17 && \
    rm -rf /var/lib/apt/lists/*

# Install yq (YAML processor) for config management
RUN set -eux; \
    ARCH=$(uname -m); \
    case "$ARCH" in \
        x86_64) YQ_ARCH="amd64" ;; \
        aarch64) YQ_ARCH="arm64" ;; \
        armv7l) YQ_ARCH="arm" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH}" -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    yq --version

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

RUN --mount=type=cache,target=/tmp/ipe-cache \
    install-php-extensions ${DEPENDENCY_PHP_EXTENSIONS}

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

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: Node.js Installation
# ============================================================================
FROM composer-install AS node-install

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Import ARG values needed in this stage
ARG NODE_VERSION=22

# Install Node.js
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*;

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: MinIO Client Tools
# ============================================================================
FROM node-install AS minio-tools

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    echo "Installing MinIO Client..."; \
    # Test network connectivity first \
    curl -fsSL --connect-timeout 10 --max-time 30 https://dl.min.io/ > /dev/null && \
    echo "MinIO download server is accessible"; \
    # Detect architecture for MinIO Client \
    ARCH=$(uname -m); \
    case "$ARCH" in \
        x86_64) MC_ARCH="linux-amd64" ;; \
        aarch64) MC_ARCH="linux-arm64" ;; \
        armv7l) MC_ARCH="linux-arm" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac; \
    echo "Detected architecture: $ARCH, using MinIO Client variant: ${MC_ARCH}"; \
    # Download MinIO Client with retry logic \
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
    # Set executable permissions immediately after download \
    chmod +x /usr/local/bin/mc && \
    echo "MinIO Client permissions set successfully"; \
    # Test installation \
    /usr/local/bin/mc --version && \
    echo "MinIO Client installed and tested successfully";

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: Modern Terminal Tools (fzf + starship)
# ============================================================================
FROM minio-tools AS modern-terminal-tools

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN --mount=type=cache,target=/tmp/downloads \
    set -eux; \
    echo "Installing modern terminal tools..."; \
    \
    # Verify git is available (should be inherited from dependencies stage) \
    echo "Verifying git: $(git --version)"; \
    \
    # Install Nerd Fonts Symbols Only for optimal terminal experience (2MB vs 123MB) \
    echo "Installing Nerd Fonts Symbols Only..."; \
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.tar.xz -o /tmp/downloads/symbols.tar.xz && \
    tar -xf /tmp/downloads/symbols.tar.xz -C /usr/share/fonts && \
    rm /tmp/downloads/symbols.tar.xz && \
    fc-cache -fv && \
    \
    # Install fzf (fuzzy finder) \
    echo "Installing fzf..."; \
    git clone --depth 1 https://github.com/junegunn/fzf.git /opt/fzf && \
    /opt/fzf/install --bin && \
    cp /opt/fzf/bin/fzf /usr/local/bin/ && \
    chmod +x /usr/local/bin/fzf && \
    fzf --version && \
    \
    # Install Starship (modern prompt) \
    echo "Installing Starship..."; \
    curl -sS https://starship.rs/install.sh | sh -s -- -y && \
    starship --version && \
    \
    echo "All modern terminal tools installed successfully"

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: User Tools Installation
# ============================================================================
FROM modern-terminal-tools AS user-tools

USER root

# Import ARG values needed in this stage
ARG APP_USER=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000

# Switch to the non-privileged user to run user-specific commands
USER ${APP_UID}:${APP_GID}

# Configure user-specific paths for Composer and NPM global packages
ENV COMPOSER_HOME="/home/${APP_USER}/.composer"
ENV NPM_CONFIG_PREFIX="/home/${APP_USER}/.npm-global"
ENV PATH="${COMPOSER_HOME}/vendor/bin:${NPM_CONFIG_PREFIX}/bin:${PATH}"

# Install and configure user-specific tools
RUN set -eux; \
    # Configure composer \
    composer self-update; \
    composer --version; \
    composer config --global allow-plugins.ergebnis/composer-normalize true; \
    composer config --global allow-plugins.pyrech/composer-changelogs true; \
    composer global require ergebnis/composer-normalize pyrech/composer-changelogs deployer/deployer laravel/installer; \
    \
    # Install global NPM packages \
    npm install -g npm@latest; \
    npm install -g npm-check-updates; \
    npm install -g @quobix/vacuum; \
    npm install -g @openapitools/openapi-generator-cli;

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: User Environment Setup
# ============================================================================
FROM user-tools AS user-setup

USER root

# Import ARG values needed in this stage
ARG APP_USER=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000

# Create essential directories and set permissions
RUN mkdir -p "/home/${APP_USER}/.config" \
             "/home/${APP_USER}/.local/bin" \
             "/home/${APP_USER}/.local/share" \
             "/home/${APP_USER}/.cache" && \
    chown -R "${APP_UID}:${APP_GID}" "/home/${APP_USER}"

# Setup bash configuration from shell files
COPY --chown=${APP_UID}:${APP_GID} shell/.inputrc /home/${APP_USER}/.inputrc
COPY --chown=${APP_UID}:${APP_GID} shell/.bash_aliases /home/${APP_USER}/.bash_aliases
COPY --chown=${APP_UID}:${APP_GID} shell/.bashrc /home/${APP_USER}/.bashrc
COPY --chown=${APP_UID}:${APP_GID} shell/starship.toml /home/${APP_USER}/.config/starship.toml

# Add fzf and starship configurations
COPY --chown=${APP_UID}:${APP_GID} shell/fzf.sh shell/starship.sh /tmp/
RUN cat /tmp/fzf.sh >> /home/${APP_USER}/.bashrc && \
    cat /tmp/starship.sh >> /home/${APP_USER}/.bashrc && \
    rm /tmp/fzf.sh /tmp/starship.sh

# Setup bash completion for all development tools
RUN set -eux; \
    mkdir -p /etc/bash_completion.d && \
    \
    composer completion bash > /etc/bash_completion.d/composer && \
    \
    npm completion > /etc/bash_completion.d/npm && \
    \
    yq shell-completion bash > /etc/bash_completion.d/yq && \
    \
    curl -fsSL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash \
         -o /etc/bash_completion.d/git-completion.bash

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: Final Image
# ============================================================================
FROM user-setup AS final

USER root

# Copy entrypoint scripts
COPY --chmod=0755 entrypoint.sh /usr/local/bin/

# Add healthcheck for container monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD php --version > /dev/null || exit 1

# Set final runtime configuration
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
WORKDIR /var/www
USER ${APP_UID}:${APP_GID}
