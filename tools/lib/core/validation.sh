#!/bin/bash

# =============================================================================
# VALIDATION MODULE
# =============================================================================
# Centralized validation functions for DockerKit
# Usage: source this file to access validation functions
# =============================================================================

set -euo pipefail

# Prevent multiple inclusion
if [[ "${DOCKERKIT_VALIDATION_LOADED:-}" == "true" ]]; then
    return 0
fi

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/base.sh"

# Mark as loaded
readonly DOCKERKIT_VALIDATION_LOADED="true"

# Exit codes are already defined in base.sh - no need to redefine them

# =============================================================================
# VALIDATION PATTERNS
# =============================================================================

if [ -z "${PATTERN_LOCAL_DOMAIN:-}" ]; then
    readonly PATTERN_LOCAL_DOMAIN='^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.localhost$'
fi

# =============================================================================
# DOMAIN VALIDATION
# =============================================================================

is_valid_local_domain() {
    local domain="$1"
    [[ -n "$domain" ]] && [[ "$domain" =~ $PATTERN_LOCAL_DOMAIN ]]
}

# =============================================================================
# PROJECT VALIDATION
# =============================================================================

validate_project_directory() {
    local project_path="$1"

    if [ ! -d "$project_path" ]; then
        return "$EXIT_INVALID_CONFIG"
    fi

    if [ ! -r "$project_path" ]; then
        return "$EXIT_PERMISSION_DENIED"
    fi

    return "$EXIT_SUCCESS"
}

# =============================================================================
# TEMPLATE VALIDATION
# =============================================================================

validate_template_syntax() {
    local template_path="$1"

    # Check file exists and is readable
    if [ ! -f "$template_path" ] || [ ! -r "$template_path" ]; then
        return "$EXIT_INVALID_CONFIG"
    fi

    # Check for required placeholders
    if ! grep -q "{{SITE_NAME}}" "$template_path"; then
        return "$EXIT_INVALID_CONFIG"
    fi

    if ! grep -q "{{DOCUMENT_ROOT}}" "$template_path"; then
        return "$EXIT_INVALID_CONFIG"
    fi

    # Check for basic nginx syntax
    if ! grep -q "server {" "$template_path"; then
        return "$EXIT_INVALID_CONFIG"
    fi

    # Check for HTTP server block (listen 80)
    if ! grep -q "listen 80" "$template_path"; then
        return "$EXIT_INVALID_CONFIG"
    fi

    # Check for server_name directive
    if ! grep -q "server_name " "$template_path"; then
        return "$EXIT_INVALID_CONFIG"
    fi

    # Validate HTTPS block markers (if present)
    local has_https_start has_https_end
    has_https_start=$(grep -c "# HTTPS_BLOCK_START" "$template_path")
    has_https_end=$(grep -c "# HTTPS_BLOCK_END" "$template_path")

    # If HTTPS markers exist, validate them
    if [ "$has_https_start" -gt 0 ] || [ "$has_https_end" -gt 0 ]; then
        # Both markers must be present and match
        if [ "$has_https_start" -ne 1 ] || [ "$has_https_end" -ne 1 ]; then
            return "$EXIT_INVALID_CONFIG"
        fi

        # Check for HTTPS server block (listen 443 ssl)
        if ! grep -q "listen 443 ssl" "$template_path"; then
            return "$EXIT_INVALID_CONFIG"
        fi

        # Check for SSL certificate configuration
        if ! grep -q "ssl_certificate " "$template_path"; then
            return "$EXIT_INVALID_CONFIG"
        fi

        if ! grep -q "ssl_certificate_key " "$template_path"; then
            return "$EXIT_INVALID_CONFIG"
        fi
    fi

    return "$EXIT_SUCCESS"
}
