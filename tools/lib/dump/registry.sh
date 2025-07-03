#!/bin/bash

# =============================================================================
# DATABASE REGISTRY
# =============================================================================
# Metadata and configuration for supported database systems
# =============================================================================

# =============================================================================
# DATABASE TYPES
# =============================================================================

# Available database types (displayed in UI)
readonly DB_TYPES=(
    "MySQL"
    "PostgreSQL"
)

# =============================================================================
# REGISTRY FUNCTIONS
# =============================================================================

# Get driver name for database type
get_db_driver() {
    local db_type="$1"

    case "$db_type" in
        "MySQL")
            echo "mysql"
            ;;
        "PostgreSQL")
            echo "postgres"
            ;;
        *)
            return 1
            ;;
    esac
}



# Check if database type is supported
is_db_type_supported() {
    local db_type="$1"

    case "$db_type" in
        "MySQL"|"PostgreSQL")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Get all supported database types
get_supported_db_types() {
    printf '%s\n' "${DB_TYPES[@]}"
}

# Validate database type
validate_db_type() {
    local db_type="$1"

    if ! is_db_type_supported "$db_type"; then
        print_error "Unsupported database type: $db_type"
        print_tip "Supported types: $(printf '%s, ' "${DB_TYPES[@]}" | sed 's/, $//')"
        return 1
    fi

    return 0
}
