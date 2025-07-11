#!/bin/bash

# =============================================================================
# PROJECT TYPES REGISTRY
# =============================================================================
# Metadata and configuration for supported project types
# =============================================================================

# =============================================================================
# PROJECT TYPES
# =============================================================================

readonly PROJECT_TYPES=(
    "Laravel"
    "Symfony"
)

# =============================================================================
# REGISTRY FUNCTIONS
# =============================================================================

get_project_driver() {
    local project_type="$1"

    case "$project_type" in
        "Laravel")
            echo "laravel"
            ;;
        "Symfony")
            echo "symfony"
            ;;
        *)
            return 1
            ;;
    esac
}

is_project_type_supported() {
    local project_type="$1"

    case "$project_type" in
        "Laravel"|"Symfony")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

get_supported_project_types() {
    printf '%s\n' "${PROJECT_TYPES[@]}"
}

validate_project_type() {
    local project_type="$1"

    if ! is_project_type_supported "$project_type"; then
        print_error "Unsupported project type: $project_type"
        print_tip "Supported types: $(printf '%s, ' "${PROJECT_TYPES[@]}" | sed 's/, $//')"
        return 1
    fi

    return 0
}
