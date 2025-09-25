#!/bin/bash

# =============================================================================
# DOCKERKIT FILES MANAGEMENT LIBRARY
# =============================================================================
# Functions for managing project files (create from examples, cleanup, etc.)
# =============================================================================

# Prevent multiple inclusion
if [[ "${DOCKERKIT_FILES_LOADED:-}" == "true" ]]; then
    return 0
fi

# Mark as loaded
readonly DOCKERKIT_FILES_LOADED="true"

# Registry of files to create from examples (source:destination pairs)
SETUP_FILES=(
    ".env.example:.env"
    "workspace/auth.json.example:workspace/auth.json"
    "php-fpm/www.conf.example:php-fpm/www.conf"
    "php-fpm/php.ini.example:php-fpm/php.ini"
    "workspace/php.ini.example:workspace/php.ini"
)

# Create file from example if it doesn't exist
create_file_from_example() {
    local source="$1"
    local destination="$2"

    if [ ! -f "$DOCKERKIT_DIR/$source" ]; then
        print_error "Example file not found: $source"
        return 1
    fi

    if [ -f "$DOCKERKIT_DIR/$destination" ]; then
        print_success "File already exists: $destination"
        return 0
    fi

    cp "$DOCKERKIT_DIR/$source" "$DOCKERKIT_DIR/$destination"
    print_success "Created $destination"
    return 0
}

# Create all setup files from examples
create_managed_files() {
    local created_count=0
    local total_count=${#SETUP_FILES[@]}

    for file_pair in "${SETUP_FILES[@]}"; do
        local source="${file_pair%:*}"
        local destination="${file_pair#*:}"
        if create_file_from_example "$source" "$destination"; then
            created_count=$((created_count + 1))
        fi
    done

    if [ $created_count -eq 0 ]; then
        print_success "All configuration files already exist"
    else
        print_success "Created $created_count/$total_count configuration files"
    fi
}

# Ensure project directory exists (relative to DOCKERKIT_DIR)
ensure_project_directory() {
    local dir_path="$1"

    if [ ! -d "$DOCKERKIT_DIR/$dir_path" ]; then
        mkdir -p "$DOCKERKIT_DIR/$dir_path"
        print_success "Created directory: $dir_path"
    fi
}

# Remove managed file if it exists
remove_managed_file() {
    local file_path="$1"

    if [ -f "$DOCKERKIT_DIR/$file_path" ]; then
        rm -f "$DOCKERKIT_DIR/$file_path"
        print_success "Removed $file_path"
    fi
}
