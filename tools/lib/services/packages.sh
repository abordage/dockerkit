#!/bin/bash

# =============================================================================
# PACKAGE MANAGER
# =============================================================================
# Functions for managing system packages and dependencies
# Usage: source this file and call package management functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"

source "$BASE_DIR/base.sh"

# Load dependencies
PKG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$PKG_SCRIPT_DIR/../core/utils.sh"
source "$PKG_SCRIPT_DIR/../core/config.sh"

check_system_dependencies() {
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        macos|linux|wsl2)
            check_required_tools
            ;;
        *)
            print_warning "Unsupported operating system: $os_type"
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

check_required_tools() {
    local required_tools=("mkcert")
    local all_ok=true

    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            print_info "$tool: not found, installing..."
            if ! install_missing_tool "$tool"; then
                print_error "$tool: installation failed"
                all_ok=false
            else
                print_success "$tool: installed successfully"
            fi
        else
            print_success "$tool: already installed"
        fi
    done

    if [ "$all_ok" = false ]; then
        return "$EXIT_GENERAL_ERROR"
    fi


    return "$EXIT_SUCCESS"
}

install_missing_tool() {
    local tool_name="$1"
    local os_type
    os_type=$(detect_os)

    case "$tool_name" in
        mkcert)
            install_mkcert_for_platform "$os_type"
            ;;
        *)
            print_error "Unknown tool: $tool_name"
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

install_mkcert_for_platform() {
    local os_type="$1"

    case "$os_type" in
        linux|wsl2)
            install_mkcert_linux
            ;;
        macos)
            install_mkcert_macos_stub
            ;;
        *)
            print_error "Unsupported platform for mkcert installation: $os_type"
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

install_mkcert_linux() {
    local temp_dir="/tmp/mkcert-install"
    local mkcert_url="https://dl.filippo.io/mkcert/latest?for=linux/amd64"
    local install_path="/usr/local/bin/mkcert"

    # Check sudo access
    if ! check_sudo_access; then
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    # Create temporary directory
    mkdir -p "$temp_dir" || {
        print_error "Failed to create temporary directory"
        return "$EXIT_GENERAL_ERROR"
    }

    # Download mkcert
    print_info "Downloading mkcert latest version..."
    if ! curl "$mkcert_url" -o "$temp_dir/mkcert"; then
        print_error "Failed to download mkcert"
        rm -rf "$temp_dir" 2>/dev/null || true
        return "$EXIT_GENERAL_ERROR"
    fi

    # Set executable permissions and move to install path
    chmod +x "$temp_dir/mkcert" || {
        rm -rf "$temp_dir" 2>/dev/null || true
        return "$EXIT_GENERAL_ERROR"
    }

    sudo mv "$temp_dir/mkcert" "$install_path" || {
        rm -rf "$temp_dir" 2>/dev/null || true
        return "$EXIT_GENERAL_ERROR"
    }

    # Verify installation
    if ! command_exists "mkcert"; then
        print_error "mkcert installation verification failed"
        rm -rf "$temp_dir" 2>/dev/null || true
        return "$EXIT_GENERAL_ERROR"
    fi

    # Clean up temporary files
    rm -rf "$temp_dir" 2>/dev/null || true

    return "$EXIT_SUCCESS"
}

install_mkcert_macos_stub() {
    print_warning "Automatic mkcert installation for macOS not implemented yet"
    print_tip "Please install mkcert manually:"
    print_tip "  brew install mkcert"

    return "$EXIT_MISSING_DEPENDENCY"
}

check_sudo_access() {
    if sudo -n true 2>/dev/null; then
        return "$EXIT_SUCCESS"
    else
        print_info "sudo access required for mkcert installation"
        print_tip "Please enter your password when prompted"
        # Try sudo with password prompt
        if sudo true 2>/dev/null; then
            return "$EXIT_SUCCESS"
        else
            print_error "sudo access denied"
            return "$EXIT_PERMISSION_DENIED"
        fi
    fi
}



