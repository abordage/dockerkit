# syntax=docker/dockerfile:1.4
# check=error=true

ARG PHP_VERSION=8.4
ARG TZ=UTC
ARG APP_USER=dockerkit
ARG APP_UID=1000
ARG APP_GID=1000

# PHP Extensions (from .env)
ARG DEPENDENCY_PHP_EXTENSIONS

# cURL Configuration
ARG CURL_VERSION=curl-8_16_0

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

# Import ARG values needed in this stage
ARG DEPENDENCY_PHP_EXTENSIONS

# Check which libcurl PHP extension is using
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
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

# Verify critical tools installation
RUN set -eux; \
    echo "Verifying critical tools installation..."; \
    php --version && \
    curl --version && \
    echo "All critical tools verified successfully"

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
