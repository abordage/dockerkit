#!/bin/bash

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================
# Centralized configuration loading and management
# Usage: source this file to access configuration variables and functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./base.sh
source "$BASE_DIR/base.sh"

# Project configuration
if [ -z "${PROFILE_NAME:-}" ]; then
    PROFILE_NAME="dockerkit-global"
fi

if [ -z "${DEFAULT_PROJECT_TYPES:-}" ]; then
    DEFAULT_PROJECT_TYPES=("laravel" "symfony" "wordpress" "static" "simple")
fi

# Environment variables validation
if [ -z "${REQUIRED_ENV_VARS:-}" ]; then
    readonly REQUIRED_ENV_VARS=(
        "COMPOSE_PROJECT_NAME"
        "PROJECT_NAME"
        "PHP_VERSION"
        "APP_USER"
        "POSTGRES_DB"
    )
fi

# Required Makefile targets
if [ -z "${REQUIRED_MAKEFILE_TARGETS:-}" ]; then
    readonly REQUIRED_MAKEFILE_TARGETS=(
        "setup"
        "help"
        "start"
        "stop"
    )
fi

# Required nginx templates
if [ -z "${REQUIRED_NGINX_TEMPLATES:-}" ]; then
    readonly REQUIRED_NGINX_TEMPLATES=(
        "simple.conf"
        "simple-ssl.conf"
        "laravel.conf"
        "laravel-ssl.conf"
        "symfony.conf"
        "symfony-ssl.conf"
        "static.conf"
        "static-ssl.conf"
        "wordpress.conf"
        "wordpress-ssl.conf"
    )
fi

# Tool version requirements
if [ -z "${MINIMUM_VERSIONS_LOADED:-}" ]; then
    # Minimum required versions for proper functioning
    readonly MAKE_MIN_VERSION="4.4"
    readonly BASH_MIN_VERSION="4.0"
    readonly GIT_MIN_VERSION="2.0"

    # Recommended versions (for upgrade suggestions)
    readonly MAKE_RECOMMENDED_VERSION="4.4.1"
    readonly BASH_RECOMMENDED_VERSION="5.0"
    readonly GIT_RECOMMENDED_VERSION="2.40"

    # Export for external use
    export MAKE_MIN_VERSION BASH_MIN_VERSION GIT_MIN_VERSION
    export MAKE_RECOMMENDED_VERSION BASH_RECOMMENDED_VERSION GIT_RECOMMENDED_VERSION

    readonly MINIMUM_VERSIONS_LOADED=true
fi

# Performance thresholds (in seconds)
export PERFORMANCE_THRESHOLD_TOTAL=2.0    # Total time > 2s = slow (was 1.0)
export PERFORMANCE_THRESHOLD_DNS=1.0      # DNS lookup > 1s = slow
export PERFORMANCE_THRESHOLD_SSL=1.5      # SSL handshake > 1.5s = slow

# Directory paths
export NGINX_SITES_DIR="nginx/conf.d"
export NGINX_SSL_DIR="nginx/ssl"
export SSL_CA_DIR="ssl-ca"
export NGINX_TEMPLATES_DIR="nginx/templates"

# Timeout settings
export CURL_CONNECT_TIMEOUT=10
export CURL_MAX_TIME=30
