#!/bin/bash

# =============================================================================
# DOCKERKIT UPDATE MANAGER
# =============================================================================
# Intelligent DockerKit update system with version checking and conditional rebuild
# Usage: ./update.sh [OPTIONS]
# =============================================================================

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export DOCKERKIT_DIR

# Load core DockerKit libraries
source "$SCRIPT_DIR/lib/core/base.sh"
source "$SCRIPT_DIR/lib/core/colors.sh"
source "$SCRIPT_DIR/lib/core/utils.sh"
source "$SCRIPT_DIR/lib/core/docker.sh"

# =============================================================================
# CONSTANTS
# =============================================================================

readonly REMOTE_NAME="origin"
readonly MAIN_BRANCH="main"

# =============================================================================
# VERSION MANAGEMENT
# =============================================================================

get_current_version() {
    git describe --tags --abbrev=0 2>/dev/null || echo "unknown"
}

get_latest_version() {
    if ! git fetch --tags "$REMOTE_NAME" >/dev/null 2>&1; then
        return "$EXIT_CONNECTION_ERROR"
    fi

    git describe --tags --abbrev=0 "$REMOTE_NAME/$MAIN_BRANCH" 2>/dev/null || echo "unknown"
}

is_version_newer() {
    local current="$1"
    local latest="$2"

    if [ "$current" = "unknown" ] || [ "$latest" = "unknown" ]; then
        return "$EXIT_GENERAL_ERROR"
    fi

    if [ "$current" = "$latest" ]; then
        return "$EXIT_GENERAL_ERROR"  # Not newer
    fi

    # Use version_compare from utils.sh
    if version_compare "$latest" "$current"; then
        return "$EXIT_SUCCESS"  # Latest is newer
    else
        return "$EXIT_GENERAL_ERROR"  # Current is newer or equal
    fi
}

# =============================================================================
# UPDATE WORKFLOW
# =============================================================================

check_update_prerequisites() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a Git repository"
        return "$EXIT_INVALID_CONFIG"
    fi

    # Check if working directory is clean
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        print_error "Working directory has uncommitted changes"
        print_tip "Commit or stash your changes before updating"
        return "$EXIT_INVALID_CONFIG"
    fi

    # Check Docker availability
    if ! ensure_docker_available; then
        print_error "Docker is not available"
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    return "$EXIT_SUCCESS"
}

check_versions() {
    local current_version latest_version

    print_info "Checking DockerKit version..."

    current_version=$(get_current_version)
    print_success "Current version: $(green "$current_version")"

    print_info "Fetching latest version..."
    if ! latest_version=$(get_latest_version); then
        print_error "Failed to fetch updates from repository"
        print_tip "Please check your internet connection and try again"
        return "$EXIT_CONNECTION_ERROR"
    fi

    print_success "Latest version:  $(green "$latest_version")"

    if is_version_newer "$current_version" "$latest_version"; then
        echo "$current_version:$latest_version"
        return "$EXIT_SUCCESS"
    else
        echo "$current_version:$current_version"
        return "$EXIT_GENERAL_ERROR"
    fi
}

perform_git_update() {
    print_info "Step 1: Updating from repository..."

    if git pull "$REMOTE_NAME" "$MAIN_BRANCH"; then
        print_success "Repository updated successfully"
        return "$EXIT_SUCCESS"
    else
        print_error "Failed to update from repository"
        return "$EXIT_GENERAL_ERROR"
    fi
}

reinstall_dk_command() {
    print_info "Step 2: Reinstalling dk command..."

    if make dk-install >/dev/null 2>&1; then
        print_success "dk command reinstalled"
        return "$EXIT_SUCCESS"
    else
        print_warning "dk command reinstallation failed"
        return "$EXIT_GENERAL_ERROR"
    fi
}

rebuild_containers() {
    print_info "Step 3: Stopping containers..."
    if docker compose stop workspace php-fpm >/dev/null 2>&1; then
        print_success "Containers stopped"
    else
        print_warning "Failed to stop some containers"
    fi

    print_info "Step 4: Removing containers..."
    if docker compose rm -f workspace php-fpm >/dev/null 2>&1; then
        print_success "Containers removed"
    else
        print_warning "Failed to remove some containers"
    fi

    print_info "Step 5: Building images (with cache)..."
    if docker compose build workspace php-fpm >/dev/null 2>&1; then
        print_success "Images built successfully"
    else
        print_error "Failed to build images"
        return "$EXIT_GENERAL_ERROR"
    fi

    print_info "Step 6: Starting services..."
    if make start >/dev/null 2>&1; then
        print_success "Services started"
        return "$EXIT_SUCCESS"
    else
        print_error "Failed to start services"
        return "$EXIT_GENERAL_ERROR"
    fi
}

perform_update() {
    local version_info="$1"
    local current_version latest_version

    IFS=':' read -r current_version latest_version <<< "$version_info"

    print_section "Starting DockerKit update: $current_version → $latest_version"

    # Step 1: Git update
    if ! perform_git_update; then
        return "$EXIT_GENERAL_ERROR"
    fi

    # Step 2: Reinstall dk command
    reinstall_dk_command

    # Step 3-6: Rebuild containers
    if ! rebuild_containers; then
        return "$EXIT_GENERAL_ERROR"
    fi

    print_success "Update completed successfully: $current_version → $latest_version"
    return "$EXIT_SUCCESS"
}


# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

show_help() {
    cat << EOF
DockerKit Update Manager

USAGE:
    ./update.sh [OPTIONS]

DESCRIPTION:
    Intelligent update system that checks for new DockerKit versions and performs
    conditional updates with container rebuilds only when necessary.

OPTIONS:
    -h, --help          Show this help message

FEATURES:
    • Smart version checking using Git tags
    • Conditional updates (only when new version available)
    • Automatic dk command reinstallation
    • Container rebuild with cache optimization
    • Network fetch error handling with user guidance

EXAMPLES:
    ./update.sh                     # Check and update if new version available

REQUIREMENTS:
    • Clean Git working directory (no uncommitted changes)
    • Docker and docker compose must be running
    • Internet connection for fetching updates

EOF
}

# Main function
main() {
    # Parse help argument
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit "$EXIT_SUCCESS"
    fi

    print_header "DOCKERKIT UPDATE MANAGER"

    # Check prerequisites
    if ! check_update_prerequisites; then
        exit "$EXIT_INVALID_CONFIG"
    fi

    # Check versions
    local version_info
    if version_info=$(check_versions); then
        # New version available
        if perform_update "$version_info"; then
            exit "$EXIT_SUCCESS"
        else
            exit "$EXIT_GENERAL_ERROR"
        fi
    else
        # Already up to date
        print_success "DockerKit is already up to date!"
        exit "$EXIT_SUCCESS"
    fi
}

# Script entry point
main "$@"
