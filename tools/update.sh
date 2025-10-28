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

    if test "$current" = "unknown" || test "$latest" = "unknown"; then
        return "$EXIT_GENERAL_ERROR"
    fi

    if test "$current" = "$latest"; then
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

    return "$EXIT_SUCCESS"
}

check_versions() {
    local current_version latest_version

    print_info "Checking DockerKit version" >&2

    current_version=$(get_current_version)

    if ! latest_version=$(get_latest_version); then
        print_error "Failed to fetch updates from repository"
        print_tip "Please check your internet connection and try again"
        return "$EXIT_CONNECTION_ERROR"
    fi

    if is_version_newer "$current_version" "$latest_version"; then
        printf " %b → %b\n\n" "$(gray "$current_version")" "$(green "$latest_version")" >&2
        echo "$current_version:$latest_version"
        return "$EXIT_SUCCESS"
    else
        printf " %b\n\n" "$(green "$current_version (up to date)")" >&2
        return "$EXIT_GENERAL_ERROR"
    fi
}

perform_git_update() {
    print_info "[1/2] Updating from repository"

    if git pull "$REMOTE_NAME" "$MAIN_BRANCH" >/dev/null 2>&1; then
        print_success "Repository updated successfully"
        echo ""
        return "$EXIT_SUCCESS"
    else
        print_error "Failed to update from repository"
        return "$EXIT_GENERAL_ERROR"
    fi
}

reinstall_dk_command() {
    print_info "[2/2] Reinstalling dk command"

    if "$SCRIPT_DIR/dk/manager.sh" install >/dev/null 2>&1; then
        print_success "dk command reinstalled"
        echo ""
        return "$EXIT_SUCCESS"
    else
        echo ""
        return "$EXIT_GENERAL_ERROR"
    fi
}

perform_update() {
    # Git update
    if ! perform_git_update; then
        return "$EXIT_GENERAL_ERROR"
    fi

    # Reinstall dk command
    if ! reinstall_dk_command; then
        echo ""
        print_warning "dk command reinstallation failed"
        print_tip "Please run manually: $(green "./tools/dk/manager.sh install")"
        echo ""
    fi

    # Show completion message
    printf '%b\n' "$(green "Update completed successfully")"
    printf '%s%b\n' "$(gray "If you need to rebuild containers, run: ")" "$(green "make rebuild")"

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
    updates from the repository with automatic dk command reinstallation.

OPTIONS:
    -h, --help          Show this help message
    -f, --force         Force update even if already up to date (for testing)

FEATURES:
    • Smart version checking using Git tags
    • Conditional updates (only when new version available)
    • Automatic dk command reinstallation
    • Network fetch error handling with user guidance

EXAMPLES:
    ./update.sh                     # Check and update if new version available
    ./update.sh --force             # Force update (for testing)

REQUIREMENTS:
    • Clean Git working directory (no uncommitted changes)
    • Internet connection for fetching updates

EOF
}

# Main function
main() {
    local force_update=false

    # Parse arguments
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                show_help
                exit "$EXIT_SUCCESS"
                ;;
            -f|--force)
                force_update=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo ""
                show_help
                exit "$EXIT_GENERAL_ERROR"
                ;;
        esac
    done

    print_header "DOCKERKIT UPDATE MANAGER"

    # Check prerequisites
    if ! check_update_prerequisites; then
        exit "$EXIT_INVALID_CONFIG"
    fi

    # Check versions
    local update_available=false

    if check_versions >/dev/null; then
        update_available=true
    fi

    # Perform update if new version available or forced
    if test "$update_available" = "true" || test "$force_update" = "true"; then
        if perform_update; then
            exit "$EXIT_SUCCESS"
        else
            exit "$EXIT_GENERAL_ERROR"
        fi
    else
        # Already up to date and not forced
        exit "$EXIT_SUCCESS"
    fi
}

# Script entry point
main "$@"
