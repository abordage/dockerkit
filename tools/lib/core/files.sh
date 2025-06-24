#!/bin/bash

# =============================================================================
# DOCKERKIT FILES MANAGEMENT LIBRARY
# =============================================================================
# Functions for managing project files (create from examples, cleanup, etc.)
# =============================================================================

# Registry of files to create from examples (source:destination pairs)
SETUP_FILES=(
    ".env.example:.env"
    "workspace/auth.json.example:workspace/auth.json"
)

# Directories to manage
MANAGED_DIRECTORIES=(
    "logs"
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
    print_section "Creating configuration files"

    local created_count=0
    local total_count=${#SETUP_FILES[@]}

    for file_pair in "${SETUP_FILES[@]}"; do
        local source="${file_pair%:*}"
        local destination="${file_pair#*:}"
        if create_file_from_example "$source" "$destination"; then
            ((created_count++))
        fi
    done

    if [ $created_count -eq 0 ]; then
        print_success "All configuration files already exist"
    else
        print_success "Created $created_count/$total_count configuration files"
    fi
}

# Ensure directory exists
ensure_directory() {
    local dir_path="$1"

    if [ ! -d "$DOCKERKIT_DIR/$dir_path" ]; then
        mkdir -p "$DOCKERKIT_DIR/$dir_path"
        print_success "Created directory: $dir_path"
    else
        print_success "Directory already exists: $dir_path"
    fi
}

# Create all managed directories
create_managed_directories() {
    print_section "Creating directories"

    for dir_path in "${MANAGED_DIRECTORIES[@]}"; do
        ensure_directory "$dir_path"
    done
}

# Remove managed file if it exists
remove_managed_file() {
    local file_path="$1"

    if [ -f "$DOCKERKIT_DIR/$file_path" ]; then
        rm -f "$DOCKERKIT_DIR/$file_path"
        print_success "Removed $file_path"
    fi
}

# Clean directory contents but keep structure
clean_directory_contents() {
    local dir_path="$1"

    if [ -d "$DOCKERKIT_DIR/$dir_path" ]; then
        find "$DOCKERKIT_DIR/$dir_path" -type f -delete 2>/dev/null || true
        print_success "Cleaned directory: $dir_path"
    fi
}

# Clean all managed directories
clean_managed_directories() {
    print_section "Cleaning directories"

    for dir_path in "${MANAGED_DIRECTORIES[@]}"; do
        clean_directory_contents "$dir_path"
    done
}

# Get logs directory from environment or use default
get_logs_directory() {
    local logs_dir="${HOST_LOGS_PATH:-./logs}"
    echo "$logs_dir"
}

# Create logs directory based on environment
create_logs_directory() {
    local logs_dir
    logs_dir=$(get_logs_directory)

    ensure_directory "$logs_dir"
}

# Clean logs directory based on environment
clean_logs_directory() {
    local logs_dir
    logs_dir=$(get_logs_directory)

    clean_directory_contents "$logs_dir"
}
