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
if [ -z "$RED" ]; then
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
# USER CONFIRMATION FUNCTIONS
# =============================================================================

# Confirm action with user
confirm_action() {
    local message="$1"
    local response

    echo -e "${YELLOW}$message${NC} (Y/N): " >&2
    read -r response

    case "$response" in
        [yY]|[yY][eE][sS])
            return "$EXIT_SUCCESS"
            ;;
        *)
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# Confirm action with default Yes (Enter = Yes)
confirm_action_default_yes() {
    local message="$1"
    local response

    echo -e "${YELLOW}$message${NC} (${GREEN}Y${NC}/N, default: ${GREEN}Yes${NC}): " >&2
    read -r response

    # Default to Yes if empty response
    if [ -z "$response" ]; then
        response="Y"
    fi

    case "$response" in
        [yY]|[yY][eE][sS])
            return "$EXIT_SUCCESS"
            ;;
        *)
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# Confirm action with default No (Enter = No)
confirm_action_default_no() {
    local message="$1"
    local response

    echo -e "${YELLOW}$message${NC} (Y/${RED}N${NC}, default: ${RED}No${NC}): " >&2
    read -r response

    # Default to No if empty response
    if [ -z "$response" ]; then
        response="N"
    fi

    case "$response" in
        [yY]|[yY][eE][sS])
            return "$EXIT_SUCCESS"
            ;;
        *)
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}
