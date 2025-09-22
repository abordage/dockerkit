#!/bin/bash

# =============================================================================
# USER PERMISSIONS MANAGER
# =============================================================================
# Functions for managing user permissions and system groups
# Usage: source this file and call permission management functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"

source "$BASE_DIR/base.sh"

# Load dependencies
PERMISSIONS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$PERMISSIONS_SCRIPT_DIR/../core/utils.sh"
source "$PERMISSIONS_SCRIPT_DIR/../core/config.sh"

setup_user_permissions() {
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        wsl2)
            setup_wsl2_user_permissions
            ;;
        linux)
            setup_linux_user_permissions
            ;;
        *)
            # No specific permissions setup needed for this platform
            return "$EXIT_SUCCESS"
            ;;
    esac
}

setup_wsl2_user_permissions() {
    print_section "WSL2 User Permissions Setup"
    setup_sudo_nopasswd
    setup_docker_group
}

setup_linux_user_permissions() {
    # For now, only setup docker group on Linux
    # In future: add more Linux-specific permissions
    setup_docker_group
}

setup_sudo_nopasswd() {
    local user="$USER"
    local sudoers_file="/etc/sudoers.d/dockerkit-$user"

    # Check if already configured
    if sudo test -f "$sudoers_file" && sudo grep -q "$user.*NOPASSWD.*ALL" "$sudoers_file" 2>/dev/null; then
        print_success "sudo NOPASSWD: Already configured for user $user"
        return "$EXIT_SUCCESS"
    fi

    print_info "Configuring sudo NOPASSWD for user $user..."

    # Create sudoers entry with full privileges
    echo "$user ALL=(ALL) NOPASSWD:ALL" | sudo tee "$sudoers_file" > /dev/null || {
        print_warning "Failed to configure sudo NOPASSWD"
        return "$EXIT_SUCCESS"  # Don't fail the whole process
    }

    # Set correct permissions
    sudo chmod 440 "$sudoers_file" || {
        print_warning "Failed to set sudoers file permissions"
        return "$EXIT_SUCCESS"
    }

    # Validate sudoers file
    if ! sudo visudo -c -f "$sudoers_file" >/dev/null 2>&1; then
        print_error "Invalid sudoers configuration, removing file"
        sudo rm -f "$sudoers_file"
        return "$EXIT_SUCCESS"
    fi

    print_success "sudo NOPASSWD configured for user $user"
}

setup_docker_group() {
    local user="$USER"

    # Check if docker group exists
    if ! getent group docker >/dev/null 2>&1; then
        print_info "docker group: Not found, skipping"
        return "$EXIT_SUCCESS"
    fi

    # Check if user is already in docker group
    if groups "$user" | grep -q '\bdocker\b' 2>/dev/null; then
        print_success "docker group: User $user already member"
        return "$EXIT_SUCCESS"
    fi

    print_info "Adding user $user to docker group..."

    # Add user to docker group
    sudo usermod -aG docker "$user" || {
        print_warning "Failed to add user to docker group"
        return "$EXIT_SUCCESS"  # Don't fail the whole process
    }

    print_success "User $user added to docker group"
    print_tip "Restart WSL2 session to apply group changes: wsl --shutdown"
}
