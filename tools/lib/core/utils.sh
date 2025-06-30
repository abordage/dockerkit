#!/bin/bash

# =============================================================================
# COMMON UTILITIES
# =============================================================================
# Common utility functions used across multiple scripts
# Usage: source this file to access utility functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./base.sh
source "$BASE_DIR/base.sh"

# Ensure colors are loaded
if ! command -v red >/dev/null 2>&1; then
    # shellcheck source=./colors.sh
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux) echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# Check if command exists
command_exists() {
    local command_name="$1"

    # Special case for docker compose
    if [ "$command_name" = "docker compose" ]; then
        docker compose version >/dev/null 2>&1
    else
        command -v "$command_name" >/dev/null 2>&1
    fi
}

# Get version of a command
get_command_version() {
    local command_name="$1"
    local version_flag="${2:---version}"

    if ! command_exists "$command_name"; then
        echo "not_installed"
        return "$EXIT_GENERAL_ERROR"
    fi

    case "$command_name" in
        git)
            git --version | tr -s ' ' | cut -d' ' -f3
            ;;
        docker)
            docker --version | cut -d' ' -f3 | tr -d ','
            ;;
        "docker compose")
            if docker compose version --short >/dev/null 2>&1; then
                docker compose version --short
            else
                echo "not_installed"
                return "$EXIT_GENERAL_ERROR"
            fi
            ;;
        make)
            make --version | head -1 | tr -s ' ' | cut -d' ' -f3
            ;;
        bash)
            bash --version | head -1 | tr -s ' ' | cut -d' ' -f4 | cut -d'(' -f1
            ;;
        curl)
            curl --version | head -1 | tr -s ' ' | cut -d' ' -f2
            ;;
        brew)
            brew --version | head -1 | tr -s ' ' | cut -d' ' -f2 | cut -d'-' -f1
            ;;
        hostctl)
            hostctl --version 2>/dev/null | tr -s ' ' | cut -d' ' -f3 || echo "unknown"
            ;;
        mkcert)
            if command_exists brew; then
                brew list --versions mkcert 2>/dev/null | tr -s ' ' | cut -d' ' -f2 || echo "unknown"
            else
                echo "unknown"
            fi
            ;;
        *)
            $command_name "$version_flag" 2>/dev/null | head -1 || echo "unknown"
            ;;
    esac
}

# Request sudo privileges
request_sudo() {
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        macos)
            if ! sudo -n true 2>/dev/null; then
                sudo -v || {
                    print_error "Failed to obtain administrator privileges"
                    return "$EXIT_GENERAL_ERROR"
                }
            else
                print_success "Administrator privileges cached"
            fi
            ;;
        linux)
            if ! sudo -n true 2>/dev/null; then
                print_info "Root privileges required"
                sudo -v || {
                    print_error "Failed to obtain root privileges"
                    return "$EXIT_GENERAL_ERROR"
                }
            else
                print_success "Root privileges cached"
            fi
            ;;
        *)
            print_warning "Unsupported operating system for sudo operations"
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# Create directory with proper permissions
ensure_directory() {
    local directory="$1"
    local permissions="${2:-755}"

    if [ ! -d "$directory" ]; then
        mkdir -p "$directory"
        chmod "$permissions" "$directory"
    fi
}

# Compare two version strings (semantic versioning)
# Returns: 0 if v1 >= v2, 1 if v1 < v2
version_compare() {
    local version1="$1"
    local version2="$2"

    # Handle special cases
    if [ "$version1" = "$version2" ]; then
        return "$EXIT_SUCCESS"
    fi

    if [ "$version1" = "not_installed" ] || [ "$version1" = "unknown" ]; then
        return "$EXIT_GENERAL_ERROR"
    fi

    if [ "$version2" = "not_installed" ] || [ "$version2" = "unknown" ]; then
        return "$EXIT_SUCCESS"
    fi

    # Clean versions (remove leading 'v' and non-numeric suffixes)
    version1=$(echo "$version1" | sed 's/^v//' | sed 's/[^0-9.].*//')
    version2=$(echo "$version2" | sed 's/^v//' | sed 's/[^0-9.].*//')

    # Split versions into arrays using read -a
    local v1_parts v2_parts
    IFS='.' read -ra v1_parts <<< "$version1"
    IFS='.' read -ra v2_parts <<< "$version2"

    # Compare each part
    local max_parts=${#v1_parts[@]}
    if [ ${#v2_parts[@]} -gt "$max_parts" ]; then
        max_parts=${#v2_parts[@]}
    fi

    for ((i=0; i<max_parts; i++)); do
        local v1_part=${v1_parts[i]:-0}
        local v2_part=${v2_parts[i]:-0}

        # Convert to integers for comparison using parameter expansion
        v1_part=${v1_part//[^0-9]/}
        v2_part=${v2_part//[^0-9]/}

        # Default to 0 if empty
        v1_part=${v1_part:-0}
        v2_part=${v2_part:-0}

        if [ "$v1_part" -gt "$v2_part" ]; then
            return "$EXIT_SUCCESS"
        elif [ "$v1_part" -lt "$v2_part" ]; then
            return "$EXIT_GENERAL_ERROR"
        fi
    done

    return "$EXIT_SUCCESS"
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

# Universal argument parsing for standard scripts
# Usage: parse_standard_arguments "help_function" "$@"
parse_standard_arguments() {
    local help_function="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                "$help_function"
                exit "$EXIT_SUCCESS"
                ;;
            *)
                print_error "Unknown parameter: $1"
                "$help_function"
                exit "$EXIT_GENERAL_ERROR"
                ;;
        esac
    done
}

# =============================================================================
# FILE OPERATIONS
# =============================================================================

# Safe file copy with error handling
safe_copy() {
    local source="$1"
    local destination="$2"
    local backup="${3:-false}"

    if [ ! -f "$source" ]; then
        print_error "Source file not found: $source"
        return "$EXIT_GENERAL_ERROR"
    fi

    # Create backup if requested and destination exists
    if [ "$backup" = "true" ] && [ -f "$destination" ]; then
        local backup_file="${destination}.backup"
        cp "$destination" "$backup_file" || {
            print_error "Failed to create backup: $backup_file"
            return "$EXIT_GENERAL_ERROR"
        }
        print_info "Created backup: $backup_file"
    fi

    cp "$source" "$destination" || {
        print_error "Failed to copy $source to $destination"
        return "$EXIT_GENERAL_ERROR"
    }

    return "$EXIT_SUCCESS"
}

# Safe file removal with confirmation
safe_remove() {
    local file_path="$1"
    local silent="${2:-false}"

    if [ ! -e "$file_path" ]; then
        if [ "$silent" != "true" ]; then
            print_warning "File not found: $file_path"
        fi
        return "$EXIT_SUCCESS"
    fi

    rm -f "$file_path" || {
        print_error "Failed to remove: $file_path"
        return "$EXIT_GENERAL_ERROR"
    }

    if [ "$silent" != "true" ]; then
        print_success "Removed: $file_path"
    fi

    return "$EXIT_SUCCESS"
}

# Check if file is writable
is_writable() {
    local file_path="$1"

    # Check if file exists and is writable
    if [ -f "$file_path" ] && [ -w "$file_path" ]; then
        return "$EXIT_SUCCESS"
    fi

    # Check if directory is writable (for new files)
    local dir_path
    dir_path=$(dirname "$file_path")
    if [ -d "$dir_path" ] && [ -w "$dir_path" ]; then
        return "$EXIT_SUCCESS"
    fi

    return "$EXIT_GENERAL_ERROR"
}

# =============================================================================
# USER CONFIRMATION FUNCTIONS
# =============================================================================

# Universal confirmation function with optional default
# Usage: confirm_action "message" [default]
# Defaults: "yes", "no", or omit for no default
confirm_action() {
    local message="$1"
    local default="${2:-}"
    local response
    local prompt

    # Build prompt based on default
    case "$default" in
        yes|y|Y)
            prompt="$(yellow "$message") ($(green 'Y')/N, default: $(green 'Yes')): "
            ;;
        no|n|N)
            prompt="$(yellow "$message") (Y/$(red 'N'), default: $(red 'No')): "
            ;;
        *)
            prompt="$(yellow "$message") (Y/N): "
            ;;
    esac

    echo -e "$prompt" >&2
    read -r response

    # Handle empty response (use default)
    if [ -z "$response" ] && [ -n "$default" ]; then
        response="$default"
    fi

    # Normalize response to lowercase for case-insensitive comparison
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

    case "$response" in
        y|yes)
            return "$EXIT_SUCCESS"
            ;;
        n|no)
            return "$EXIT_GENERAL_ERROR"
            ;;
        *)
            # Invalid response - treat as no
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# Legacy wrapper functions for backward compatibility
confirm_action_default_yes() {
    confirm_action "$1" "yes"
}

confirm_action_default_no() {
    confirm_action "$1" "no"
}
