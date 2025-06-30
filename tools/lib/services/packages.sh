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
# shellcheck source=../core/base.sh
source "$BASE_DIR/base.sh"

# Load dependencies
PKG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../core/utils.sh
source "$PKG_SCRIPT_DIR/../core/utils.sh"
# shellcheck source=../core/config.sh
source "$PKG_SCRIPT_DIR/../core/config.sh"

# Check dependencies and show installation instructions
check_system_dependencies() {
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        macos)
            check_macos_dependencies
            ;;
        linux)
            check_linux_dependencies
            ;;
        *)
            print_warning "Unsupported operating system: $os_type"
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# Check macOS dependencies
check_macos_dependencies() {
    local missing_deps=()
    local all_ok=true

    # Check hostctl
    if ! command_exists "hostctl"; then
        print_error "hostctl: Not installed"
        missing_deps+=("hostctl")
        all_ok=false
    fi

    # Check mkcert
    if ! command_exists "mkcert"; then
        print_error "mkcert: Not installed"
        missing_deps+=("mkcert")
        all_ok=false
    fi

    if [ "$all_ok" = false ]; then
        return "$EXIT_GENERAL_ERROR"
    fi

    return "$EXIT_SUCCESS"
}

# Check Linux dependencies
check_linux_dependencies() {
    local missing_deps=()
    local all_ok=true

    # Check hostctl
    if ! command_exists "hostctl"; then
        print_error "hostctl: Not installed"
        missing_deps+=("hostctl")
        all_ok=false
    fi

    # Check mkcert
    if ! command_exists "mkcert"; then
        print_error "mkcert: Not installed"
        missing_deps+=("mkcert")
        all_ok=false
    fi

    if [ "$all_ok" = false ]; then
        return "$EXIT_GENERAL_ERROR"
    fi

    return "$EXIT_SUCCESS"
}
