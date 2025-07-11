#!/bin/bash

# =============================================================================
# HOSTS MANAGER
# =============================================================================
# Functions for managing hosts file entries
# Usage: source this file and call hosts management functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"

source "$BASE_DIR/base.sh"

# Load dependencies
HOSTS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$HOSTS_SCRIPT_DIR/../core/utils.sh"
source "$HOSTS_SCRIPT_DIR/../core/config.sh"

setup_hosts_entries() {
    local sites=("$@")

    if [ ${#sites[@]} -eq 0 ]; then
        print_warning "No sites provided for hosts setup"
        return "$EXIT_GENERAL_ERROR"
    fi

    if ! command_exists "hostctl"; then
        print_error "hostctl is required but not installed"
        print_tip "Run dependency installation first"
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    # Remove entire profile to clean up old entries
    sudo hostctl remove "$PROFILE_NAME" >/dev/null 2>&1 || true

    # Add all current sites to the profile
    for site in "${sites[@]}"; do
        # Add IPv4 domain to profile
        if ! sudo hostctl add domains "$PROFILE_NAME" "$site" >/dev/null 2>&1; then
            print_error "Failed to add IPv4 host entry for $site"
            exit "$EXIT_GENERAL_ERROR"
        fi

        # Add IPv6 domain to profile (fixes 5-second DNS delay on macOS)
        if ! sudo hostctl add domains "$PROFILE_NAME" "$site" --ip ::1 >/dev/null 2>&1; then
            print_error "Failed to add IPv6 host entry for $site"
            exit "$EXIT_GENERAL_ERROR"
        fi
    done

    # Enable profile
    if ! sudo hostctl enable "$PROFILE_NAME" >/dev/null 2>&1; then
        print_error "Failed to enable profile $PROFILE_NAME"
        exit "$EXIT_GENERAL_ERROR"
    fi
}




