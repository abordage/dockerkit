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

    # Process each site individually
    for site in "${sites[@]}"; do
        # Add IPv4 domain to profile
        if sudo hostctl add domains "$PROFILE_NAME" "$site" >/dev/null 2>&1; then
            print_success "Host entry added for: $site"
        else
            print_success "Host entry already exists for: $site"
        fi

        # Add IPv6 domain to profile (fixes 5-second DNS delay on macOS)
        sudo hostctl add domains "$PROFILE_NAME" "$site" --ip ::1 >/dev/null 2>&1
    done

    # Enable profile
    if sudo hostctl enable "$PROFILE_NAME" >/dev/null 2>&1; then
        print_success "Profile $PROFILE_NAME enabled"
    else
        print_success "Profile $PROFILE_NAME already enabled"
    fi
}




