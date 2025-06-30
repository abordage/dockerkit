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
        macos|linux)
            check_required_tools
            ;;
        *)
            print_warning "Unsupported operating system: $os_type"
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# Universal function to check required development tools
check_required_tools() {
    local required_tools=("hostctl" "mkcert")
    local missing_tools=()
    local all_ok=true

    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            print_error "$tool: Not installed"
            missing_tools+=("$tool")
            all_ok=false
        fi
    done

    if [ "$all_ok" = false ]; then
        return "$EXIT_GENERAL_ERROR"
    fi

    return "$EXIT_SUCCESS"
}
