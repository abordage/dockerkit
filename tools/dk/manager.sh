#!/bin/bash

# =============================================================================
# DOCKERKIT DK COMMAND MANAGER
# =============================================================================
# Handles installation, removal and status of dk system command
# Usage: ./manager.sh {install|uninstall|status}
# =============================================================================

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
export DOCKERKIT_DIR

# Load core libraries
source "$SCRIPT_DIR/../lib/core/base.sh"
source "$SCRIPT_DIR/../lib/core/utils.sh"
source "$SCRIPT_DIR/../lib/core/colors.sh"

# =============================================================================
# CONSTANTS
# =============================================================================

readonly DK_SOURCE_SCRIPT="$SCRIPT_DIR/dk.sh"
readonly DK_INSTALL_PATH="$HOME/.dockerkit/bin/dk"
readonly DK_INSTALL_DIR="$HOME/.dockerkit/bin"

# Shell integration markers
readonly DK_MARKER_BEGIN="# BEGIN DockerKit dk-manager"
readonly DK_MARKER_END="# END DockerKit dk-manager"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

validate_dependencies() {
    local missing_deps=()

    # Check Docker
    if ! command_exists "docker"; then
        missing_deps+=("docker")
    fi

    # Check Git
    if ! command_exists "git"; then
        missing_deps+=("git")
    fi

    # Report missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_tip "Please install missing dependencies and try again"
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    return "$EXIT_SUCCESS"
}

ensure_dockerkit_path() {
    local config_file="$1"
    local dockerkit_bin="$HOME/.dockerkit/bin"

    # Check if already in PATH
    if [[ ":$PATH:" == *":$dockerkit_bin:"* ]]; then
        return "$EXIT_SUCCESS"
    fi

    # Auto-add to PATH without asking
    if ! ensure_shell_config "$config_file"; then
        return "$EXIT_PERMISSION_DENIED"
    fi

    # Add PATH export to shell config
    {
        echo ""
        echo "# DockerKit PATH"
        echo "export PATH=\"$dockerkit_bin:\$PATH\""
    } >> "$config_file"

    print_success "Added $(purple "$dockerkit_bin") to PATH in $(gray "$config_file")"
    print_warning "  Restart your terminal or run: source $(gray "$config_file")"

    return "$EXIT_SUCCESS"
}

detect_shell_config() {
    local user_shell="${SHELL:-/bin/bash}"
    local shell_name
    shell_name="$(basename "$user_shell")"

    case "$shell_name" in
        zsh)
            echo "$HOME/.zshrc"
            ;;
        bash)
            # macOS prefers .bash_profile, Linux .bashrc
            if test "$(uname)" = "Darwin" && test -f "$HOME/.bash_profile"; then
                echo "$HOME/.bash_profile"
            else
                echo "$HOME/.bashrc"
            fi
            ;;
        fish)
            echo "$HOME/.config/fish/config.fish"
            ;;
        *)
            echo "$HOME/.profile"
            ;;
    esac
}

generate_shell_integration() {
    cat << EOF
$DK_MARKER_BEGIN
# This block was added automatically by DockerKit
# Safe to remove if DockerKit is uninstalled
dk() {
    if [ -x "\$HOME/.dockerkit/bin/dk" ]; then
        "\$HOME/.dockerkit/bin/dk" "\$@"
    else
        echo "dk command not installed."
        echo "Run 'make dk-install' in your DockerKit directory."
        return 1
    fi
}
$DK_MARKER_END
EOF
}

ensure_shell_config() {
    local config_file="$1"
    local config_dir
    config_dir="$(dirname "$config_file")"

    # Create directory if needed
    if test ! -d "$config_dir"; then
        if ! mkdir -p "$config_dir" 2>/dev/null; then
            print_error "Cannot create directory: $(gray "$config_dir")"
            return "$EXIT_PERMISSION_DENIED"
        fi
    fi

    # Create file if not exists
    if test ! -f "$config_file"; then
        if ! touch "$config_file" 2>/dev/null; then
            print_error "Cannot create file: $(gray "$config_file")"
            return "$EXIT_PERMISSION_DENIED"
        fi
        printf '%b\n' "Created shell configuration: $(gray "$config_file")"
    fi

    # Check write permission
    if test ! -w "$config_file"; then
        print_error "No write permission to: $(gray "$config_file")"
        return "$EXIT_PERMISSION_DENIED"
    fi

    return "$EXIT_SUCCESS"
}

needs_shell_integration_update() {
    local config_file="$1"

    # No config file - needs setup
    test ! -f "$config_file" && return 0

    # No integration - needs setup
    ! grep -q "$DK_MARKER_BEGIN" "$config_file" && return 0

    # Integration exists - no update needed
    return 1
}

add_shell_integration() {
    local config_file="$1"

    if ! ensure_shell_config "$config_file"; then
        return "$EXIT_PERMISSION_DENIED"
    fi

    if ! needs_shell_integration_update "$config_file"; then
        print_success "Shell integration already up to date"
        return "$EXIT_SUCCESS"
    fi

    # Only backup when making changes
    if test -s "$config_file"; then
        local backup_file
        backup_file="${config_file}.dk-backup-$(date +%Y%m%d-%H%M%S)"
        cp "$config_file" "$backup_file"
                print_success "Backup created: $(gray "$backup_file")"
    fi

    remove_shell_integration "$config_file" "silent"
    {
        echo ""
        generate_shell_integration
    } >> "$config_file"

    print_success "Shell integration updated in $(gray "$config_file")"

    # Ensure DockerKit bin is in PATH
    ensure_dockerkit_path "$config_file"

    return "$EXIT_SUCCESS"
}

remove_shell_integration() {
    local config_file="$1"
    local mode="${2:-verbose}"

    if test ! -f "$config_file"; then
        test "$mode" = "verbose" && printf '%b\n' "Config file not found: $(gray "$config_file")"
        return "$EXIT_SUCCESS"
    fi

    # Check if our integration exists
    if ! grep -q "$DK_MARKER_BEGIN" "$config_file"; then
        test "$mode" = "verbose" && printf '%b\n' "No DockerKit integration found in $(gray "$config_file")"
        return "$EXIT_SUCCESS"
    fi

    # Create backup before removal
    if test "$mode" = "verbose"; then
        cp "$config_file" "${config_file}.dk-removal-backup-$(date +%Y%m%d-%H%M%S)"
    fi

    # Remove integration blocks
    sed -i.tmp "/$DK_MARKER_BEGIN/,/$DK_MARKER_END/d" "$config_file"
    rm -f "${config_file}.tmp"

    test "$mode" = "verbose" && print_success "removed integration from $(gray "$config_file")"
    return "$EXIT_SUCCESS"
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

check_prerequisites() {
    local os_type
    os_type="$(detect_os)"

    # Block Windows
    if test "$os_type" = "windows"; then
        print_error "Windows is not supported"
        print_tip "Please use WSL2 for Docker development"
        return "$EXIT_GENERAL_ERROR"
    fi

    # Check if source script exists
    if test ! -f "$DK_SOURCE_SCRIPT"; then
        print_error "Source script not found: $(gray "$DK_SOURCE_SCRIPT")"
        return "$EXIT_INVALID_CONFIG"
    fi

    # Check if source script is readable
    if test ! -r "$DK_SOURCE_SCRIPT"; then
        print_error "Source script not readable: $(gray "$DK_SOURCE_SCRIPT")"
        return "$EXIT_PERMISSION_DENIED"
    fi

    return "$EXIT_SUCCESS"
}

setup_installation_directory() {
    if test ! -d "$DK_INSTALL_DIR"; then
        if ! mkdir -p "$DK_INSTALL_DIR"; then
            print_error "Failed to create directory: $(gray "$DK_INSTALL_DIR")"
            return "$EXIT_PERMISSION_DENIED"
        fi
    fi

    # Check write permissions
    if test ! -w "$DK_INSTALL_DIR"; then
        print_error "No write permission to: $(gray "$DK_INSTALL_DIR")"
        return "$EXIT_PERMISSION_DENIED"
    fi

    return "$EXIT_SUCCESS"
}

check_shell_integration() {
    local config_file
    config_file="$(detect_shell_config)"

    if test -f "$config_file" && grep -q "$DK_MARKER_BEGIN" "$config_file"; then
        return 0  # Integration found
    else
        return 1  # Integration not found
    fi
}

install_dk_command() {
    # Validate system dependencies
    if ! validate_dependencies; then
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    # Check prerequisites
    if ! check_prerequisites; then
        return "$EXIT_GENERAL_ERROR"
    fi

    # Setup installation directory
    if ! setup_installation_directory; then
        return "$EXIT_PERMISSION_DENIED"
    fi

    # Copy dk script to installation path
    if cp "$DK_SOURCE_SCRIPT" "$DK_INSTALL_PATH"; then
        chmod +x "$DK_INSTALL_PATH"
        print_success "dk command installed successfully"
        print_success "Location: $(purple "$DK_INSTALL_PATH")"
    else
        print_error "Failed to install dk command"
        return "$EXIT_GENERAL_ERROR"
    fi

    # Setup shell integration
    local config_file
    config_file="$(detect_shell_config)"
    add_shell_integration "$config_file"

    return "$EXIT_SUCCESS"
}

uninstall_dk_command() {
    if test ! -f "$DK_INSTALL_PATH"; then
        print_success "dk command not installed"
        return "$EXIT_SUCCESS"
    fi

    # Remove executable file
    if rm -f "$DK_INSTALL_PATH"; then
        print_success "removed dk command"
    else
        print_error "Failed to remove $(gray "$DK_INSTALL_PATH")"
        return "$EXIT_PERMISSION_DENIED"
    fi

    # Remove shell integration
    local config_file
    config_file="$(detect_shell_config)"
    remove_shell_integration "$config_file" "verbose"

    return "$EXIT_SUCCESS"
}

show_help() {
    cat << EOF
DockerKit dk Command Manager

USAGE:
    ./manager.sh {install|uninstall}

COMMANDS:
    install     Install dk command to ~/.dockerkit/bin/
    uninstall   Remove dk command from system

EXAMPLES:
    ./manager.sh install     # Install or update dk command
    ./manager.sh uninstall   # Remove dk command

REQUIREMENTS:
    • macOS, Linux, or WSL2 (Windows not supported)
    • Write access to ~/.dockerkit/bin/ directory
    • Docker and docker compose installed

EOF
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    local command="${1:-}"

    if test -z "$command"; then
        print_error "No command specified"
        show_help
        exit "$EXIT_GENERAL_ERROR"
    fi

    case "$command" in
        install)
            install_dk_command
            ;;
        uninstall)
            uninstall_dk_command
            ;;
        -h|--help|help)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# Script entry point
main "$@"
