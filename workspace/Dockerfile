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

# PostgreSQL Configuration
ARG POSTGRES_VERSION=17

# cURL Configuration
ARG CURL_VERSION=curl-8_16_0

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

ARG POSTGRES_VERSION=17

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
    git \
    htop \
    jq \
    redis-tools \
    rsync \
    sqlite3 \
    wget \
    xterm && \
    rm -rf /var/lib/apt/lists/*

# Install PostgreSQL client
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    # Extract major version from POSTGRES_VERSION (e.g., 13.22 -> 13, 15.14-trixie -> 15) \
    POSTGRES_MAJOR=$(echo "${POSTGRES_VERSION}" | cut -d'.' -f1 | cut -d'-' -f1) && \
    echo "PostgreSQL version mapping: ${POSTGRES_VERSION} -> postgresql-client-${POSTGRES_MAJOR}" && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends postgresql-client-${POSTGRES_MAJOR} && \
    rm -rf /var/lib/apt/lists/*

# Install Symfony CLI from official repository
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.deb.sh' | bash && \
    apt-get update && \
    apt-get install -y --no-install-recommends symfony-cli && \
    rm -rf /var/lib/apt/lists/*

# Install yq (YAML processor) for config management
RUN set -eux; \
    # Detect architecture \
    ARCH=$(uname -m); \
    case "$ARCH" in \
        x86_64) DEBIAN_ARCH="amd64" ;; \
        aarch64) DEBIAN_ARCH="arm64" ;; \
        armv7l) DEBIAN_ARCH="arm" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${DEBIAN_ARCH}" -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    yq --version

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: Build cURL with RFC 6761 .localhost hardcoding disabled
# ============================================================================
#
# Problem: Standard cURL hardcodes .localhost domains to 127.0.0.1 per RFC 6761,
# ignoring /etc/hosts and Docker DNS. This breaks Laravel HTTP clients when
# trying to connect to other containers via .localhost domains.
#
# Solution: Build custom cURL with RFC 6761 localhost hardcoding disabled,
# allowing .localhost domains to be resolved via /etc/hosts and Docker DNS.
# ============================================================================
FROM dependencies AS curl-builder

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Import ARG values needed in this stage
ARG CURL_VERSION

# Add metadata labels for cURL build
LABEL org.opencontainers.image.curl.version="${CURL_VERSION}"
LABEL org.opencontainers.image.curl.patch="rfc6761-disabled"

# Install build dependencies for cURL
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    libtool \
    libssl-dev \
    zlib1g-dev \
    pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Set working directory for cURL build
WORKDIR /tmp

# Download, patch and build cURL with RFC 6761 disabled
RUN --mount=type=cache,target=/tmp/curl-cache \
    set -eux; \
    echo "Building cURL with disabled RFC 6761 .localhost hardcoding..."; \
    \
    # Download specific cURL version for reproducible builds \
    echo "Building cURL version: $CURL_VERSION" && \
    if [ ! -f "/tmp/curl-cache/curl-${CURL_VERSION}.tar.gz" ]; then \
        curl -fsSL --progress-bar -o "/tmp/curl-cache/curl-${CURL_VERSION}.tar.gz" \
            "https://github.com/curl/curl/archive/refs/tags/${CURL_VERSION}.tar.gz"; \
    fi && \
    \
    # Extract source \
    rm -rf curl-curl-* && \
    tar -xzf "/tmp/curl-cache/curl-${CURL_VERSION}.tar.gz" && \
    CURL_DIR="$(find . -maxdepth 1 -name "curl-curl-*" -type d | head -1)" && \
    \
    # Apply patch to disable RFC 6761 localhost hardcoding \
    echo "Applying patch to disable RFC 6761 .localhost hardcoding..." && \
    # Verify the target code exists before patching \
    if ! grep -q "if(!is_ipaddr &&" "$CURL_DIR/lib/hostip.c"; then \
        echo "ERROR: Expected code pattern not found in $CURL_DIR/lib/hostip.c"; \
        echo "This may indicate a cURL version change that requires patch update"; \
        exit 1; \
    fi && \
    # Replace the RFC 6761 check with a simple false condition \
    sed -i 's/if(!is_ipaddr &&/if(0 \&\& !is_ipaddr \&\&/' "$CURL_DIR/lib/hostip.c" && \
    # Add comment explaining the change \
    sed -i '/if(0 && !is_ipaddr &&/i\  /* RFC 6761 localhost hardcoding disabled for Docker development */' "$CURL_DIR/lib/hostip.c" && \
    # Verify patch was applied successfully \
    if ! grep -q "RFC 6761 localhost hardcoding disabled" "$CURL_DIR/lib/hostip.c"; then \
        echo "ERROR: Patch was not applied successfully"; \
        exit 1; \
    fi && \
    echo "Patch applied successfully" && \
    \
    # Generate configure script \
    (cd "$CURL_DIR" && ./buildconf) && \
    \
    # Configure with optimal settings \
    (cd "$CURL_DIR" && ./configure \
        --prefix=/usr/local/curl-latest \
        --with-openssl \
        --enable-static \
        --enable-shared \
        --enable-threaded-resolver \
        --enable-libcurl-option \
        --enable-alt-svc \
        --enable-hsts \
        --enable-versioned-symbols \
        --disable-manual \
        --disable-ldap \
        --disable-ldaps \
        --without-libpsl \
        --without-libidn2 \
        --without-nghttp2 \
        --without-nghttp3 \
        --without-ngtcp2) && \
    \
    # Build and install \
    (cd "$CURL_DIR" && make -j"$(nproc)") && \
    (cd "$CURL_DIR" && make install) && \
    \
    # Clean up build artifacts to reduce image size \
    rm -rf "$CURL_DIR" && \
    rm -rf /usr/local/curl-latest/share/man && \
    rm -rf /usr/local/curl-latest/share/doc && \
    find /usr/local/curl-latest -name "*.la" -delete && \
    \
    # Verify installation \
    /usr/local/curl-latest/bin/curl --version && \
    echo "Latest cURL built successfully with RFC 6761 disabled"

# Replace system curl and libcurl with our custom build
RUN set -eux; \
    # Backup original curl if it exists \
    if [ -f /usr/bin/curl ]; then \
        mv /usr/bin/curl /usr/bin/curl-backup; \
    fi && \
    \
    # Install our curl binary \
    cp /usr/local/curl-latest/bin/curl /usr/bin/curl && \
    chmod +x /usr/bin/curl && \
    \
    # Install curl-config for other tools \
    cp /usr/local/curl-latest/bin/curl-config /usr/bin/curl-config && \
    chmod +x /usr/bin/curl-config && \
    \
    # Detect architecture and set library paths \
    ARCH=$(uname -m); \
    case "$ARCH" in \
        x86_64) GNU_ARCH="x86_64-linux-gnu" ;; \
        aarch64) GNU_ARCH="aarch64-linux-gnu" ;; \
        armv7l) GNU_ARCH="arm-linux-gnueabihf" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac; \
    LIB_ARCH="$GNU_ARCH" && \
    echo "Detected architecture: $ARCH, using library path: $LIB_ARCH"; \
    \
    # Replace system libcurl with our version in both /usr/lib and /lib \
    mkdir -p "/usr/lib/$LIB_ARCH" "/lib/$LIB_ARCH" && \
    cp /usr/local/curl-latest/lib/libcurl.a "/usr/lib/$LIB_ARCH/" && \
    cp /usr/local/curl-latest/lib/libcurl.so* "/usr/lib/$LIB_ARCH/" && \
    cp /usr/local/curl-latest/lib/libcurl.so* "/lib/$LIB_ARCH/" && \
    \
    # Update shared library links in both locations \
    for LIB_DIR in "/usr/lib/$LIB_ARCH" "/lib/$LIB_ARCH"; do \
        LIBCURL_SO="$(basename "$(find "$LIB_DIR" -maxdepth 1 -name "libcurl.so.4.*" | head -1)")" && \
        ln -sf "$LIBCURL_SO" "$LIB_DIR/libcurl.so.4" && \
        ln -sf libcurl.so.4 "$LIB_DIR/libcurl.so"; \
    done && \
    \
    # Copy headers \
    mkdir -p /usr/include && \
    cp -r /usr/local/curl-latest/include/curl /usr/include/ && \
    \
    # Update library cache \
    ldconfig && \
    \
    # Test installation \
    curl --version && \
    echo "System curl and libcurl replaced with patched version (RFC 6761 disabled) successfully"

USER ${APP_UID}:${APP_GID}

# ============================================================================
# Stage: PHP Extensions (with custom cURL)
# ============================================================================
FROM curl-builder AS php-extensions

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Import ARG values needed in this stage
ARG DEPENDENCY_PHP_EXTENSIONS

# Check which libcurl PHP extension is using
RUN set -eux; \
    echo "Checking PHP curl extension linkage:"; \
    php --ri curl | grep -i version || true && \
    ldd "$(php-config --extension-dir)/curl.so" | grep libcurl || true && \
    echo "Current PHP curl extension uses the above libcurl version"

# Install mlocati/docker-php-extension-installer for other extensions
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
        x86_64) GO_ARCH="linux-amd64" ;; \
        aarch64) GO_ARCH="linux-arm64" ;; \
        armv7l) GO_ARCH="linux-arm" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac; \
    MC_ARCH="$GO_ARCH" && \
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

# Ensure proper permissions for /opt where IDE stores helpers/coverage
RUN mkdir -p /opt \
 && chown ${APP_UID}:${APP_GID} /opt \
 && chmod 2775 /opt

# Verify critical tools installation
RUN set -eux; \
    echo "Verifying critical tools installation..."; \
    php --version && \
    curl --version && \
    node --version && \
    composer --version && \
    /usr/local/bin/mc --version && \
    git --version && \
    echo "All critical tools verified successfully"

# Add healthcheck for container monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD php --version > /dev/null || exit 1

# Set final runtime configuration
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
WORKDIR /var/www
USER ${APP_UID}:${APP_GID}
