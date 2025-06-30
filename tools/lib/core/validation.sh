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
# shellcheck source=./base.sh
source "$BASE_DIR/base.sh"

# Mark as loaded
readonly DOCKERKIT_VALIDATION_LOADED="true"

# Exit codes are already defined in base.sh - no need to redefine them

# =============================================================================
# VALIDATION PATTERNS
# =============================================================================

# Domain validation pattern (only define if not already set)
if [ -z "${PATTERN_LOCAL_DOMAIN:-}" ]; then
    readonly PATTERN_LOCAL_DOMAIN='^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.local$'
fi

# =============================================================================
# DOMAIN VALIDATION
# =============================================================================

# Validate .local domain name
is_valid_local_domain() {
    local domain="$1"
    [[ -n "$domain" ]] && [[ "$domain" =~ $PATTERN_LOCAL_DOMAIN ]]
}

# =============================================================================
# PROJECT VALIDATION
# =============================================================================

# Validate project directory exists and is accessible
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

# Validate nginx template syntax
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

    # Check for listen directive
    if ! grep -q "listen " "$template_path"; then
        return "$EXIT_INVALID_CONFIG"
    fi

    # Check for server_name directive
    if ! grep -q "server_name " "$template_path"; then
        return "$EXIT_INVALID_CONFIG"
    fi

    return "$EXIT_SUCCESS"
}
