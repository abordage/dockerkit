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
# shellcheck source=../lib/core/base.sh
source "$SCRIPT_DIR/../lib/core/base.sh"
# shellcheck source=../lib/core/colors.sh
source "$SCRIPT_DIR/../lib/core/colors.sh"
# shellcheck source=../lib/core/utils.sh
source "$SCRIPT_DIR/../lib/core/utils.sh"

# =============================================================================
# CONSTANTS
# =============================================================================

readonly DK_SOURCE_SCRIPT="$SCRIPT_DIR/dk.sh"
readonly DK_INSTALL_PATH="$HOME/.local/bin/dk"
readonly DK_INSTALL_DIR="$HOME/.local/bin"

# Shell integration markers
readonly DK_MARKER_BEGIN="# BEGIN DockerKit dk-manager"
readonly DK_MARKER_END="# END DockerKit dk-manager"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)
            if test -f /proc/version && grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl2"
            else
                echo "linux"
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# Get current git version/tag
get_current_version() {
    local version
    if version="$(git describe --tags --exact-match 2>/dev/null)"; then
        # On exact tag
        echo "$version" | tr -d '\n'
    elif version="$(git describe --tags 2>/dev/null)"; then
        # Post-tag commit
        echo "$version" | tr -d '\n'
    else
        # No tags, use commit hash
        version="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
        echo "$version" | tr -d '\n'
    fi
}

# Get installed dk version
get_installed_version() {
    if test -f "$DK_INSTALL_PATH"; then
        grep "readonly DK_VERSION=" "$DK_INSTALL_PATH" 2>/dev/null | \
        sed 's/.*DK_VERSION="\([^"]*\)".*/\1/' | \
        head -n 1
    else
        echo "not installed"
    fi
}

# Compare semantic versions
compare_versions() {
    local version1="$1" version2="$2"

    # Remove 'v' prefix if present
    version1="${version1#v}"
    version2="${version2#v}"

    # Simple string comparison for now
    # For production, implement proper semver comparison
    if test "$version1" = "$version2"; then
        echo "equal"
    elif test "$version1" \< "$version2"; then
        echo "older"
    else
        echo "newer"
    fi
}



# Detect user shell configuration file
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

# Generate shell integration function
generate_shell_integration() {
    local version="$1"
    cat << EOF
$DK_MARKER_BEGIN v${version}
# This block was added automatically by DockerKit
# Safe to remove if DockerKit is uninstalled
dk() {
    if [ -x "\$HOME/.local/bin/dk" ]; then
        "\$HOME/.local/bin/dk" "\$@"
    else
        echo "dk command not installed."
        echo "Run 'make dk-install' in your DockerKit directory."
        return 1
    fi
}
$DK_MARKER_END
EOF
}

# Ensure shell config file exists and is writable
ensure_shell_config() {
    local config_file="$1"
    local config_dir
    config_dir="$(dirname "$config_file")"

    # Create directory if needed
    if test ! -d "$config_dir"; then
        if ! mkdir -p "$config_dir" 2>/dev/null; then
            print_error "Cannot create directory: $config_dir"
            return "$EXIT_PERMISSION_DENIED"
        fi
    fi

    # Create file if not exists
    if test ! -f "$config_file"; then
        if ! touch "$config_file" 2>/dev/null; then
            print_error "Cannot create file: $config_file"
            return "$EXIT_PERMISSION_DENIED"
        fi
        echo -e "Created shell configuration: $config_file"
    fi

    # Check write permission
    if test ! -w "$config_file"; then
        print_error "No write permission to: $config_file"
        return "$EXIT_PERMISSION_DENIED"
    fi

    return "$EXIT_SUCCESS"
}

# Add shell integration to config file
add_shell_integration() {
    local config_file="$1"
    local version="$2"

    # Ensure config exists and is writable
    if ! ensure_shell_config "$config_file"; then
        return "$EXIT_PERMISSION_DENIED"
    fi

    # Create backup if file has content
    if test -s "$config_file"; then
        local backup_file
        backup_file="${config_file}.dk-backup-$(date +%Y%m%d-%H%M%S)"
        cp "$config_file" "$backup_file"
        print_success "backup created: $backup_file"
    fi

    # Remove old integration blocks
    remove_shell_integration "$config_file" "silent"

    # Add new integration block
    {
        echo ""
        generate_shell_integration "$version"
    } >> "$config_file"

    print_success "shell integration added to $config_file"
    return "$EXIT_SUCCESS"
}

# Remove shell integration from config file
remove_shell_integration() {
    local config_file="$1"
    local mode="${2:-verbose}"

    if test ! -f "$config_file"; then
        test "$mode" = "verbose" && echo -e "Config file not found: $config_file"
        return "$EXIT_SUCCESS"
    fi

    # Check if our integration exists
    if ! grep -q "$DK_MARKER_BEGIN" "$config_file"; then
        test "$mode" = "verbose" && echo -e "No DockerKit integration found in $config_file"
        return "$EXIT_SUCCESS"
    fi

    # Create backup before removal
    if test "$mode" = "verbose"; then
        cp "$config_file" "${config_file}.dk-removal-backup-$(date +%Y%m%d-%H%M%S)"
    fi

    # Remove integration blocks
    sed -i.tmp "/$DK_MARKER_BEGIN/,/$DK_MARKER_END/d" "$config_file"
    rm -f "${config_file}.tmp"

    test "$mode" = "verbose" && print_success "removed integration from $config_file"
    return "$EXIT_SUCCESS"
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

# Check system prerequisites
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
        print_error "Source script not found: $DK_SOURCE_SCRIPT"
        return "$EXIT_INVALID_CONFIG"
    fi

    # Check if source script is readable
    if test ! -r "$DK_SOURCE_SCRIPT"; then
        print_error "Source script not readable: $DK_SOURCE_SCRIPT"
        return "$EXIT_PERMISSION_DENIED"
    fi

    return "$EXIT_SUCCESS"
}

# Setup installation directory
setup_installation_directory() {
    if test ! -d "$DK_INSTALL_DIR"; then
        print_info "Creating installation directory: $DK_INSTALL_DIR"
        if ! mkdir -p "$DK_INSTALL_DIR"; then
            print_error "Failed to create directory: $DK_INSTALL_DIR"
            return "$EXIT_PERMISSION_DENIED"
        fi
    fi

    # Check write permissions
    if test ! -w "$DK_INSTALL_DIR"; then
        print_error "No write permission to: $DK_INSTALL_DIR"
        return "$EXIT_PERMISSION_DENIED"
    fi

    return "$EXIT_SUCCESS"
}

# Check if shell integration is configured
check_shell_integration() {
    local config_file
    config_file="$(detect_shell_config)"

    if test -f "$config_file" && grep -q "$DK_MARKER_BEGIN" "$config_file"; then
        return 0  # Integration found
    else
        return 1  # Integration not found
    fi
}

# Install dk command
install_dk_command() {
    local current_version installed_version version_comparison

    # Check prerequisites
    if ! check_prerequisites; then
        return "$EXIT_GENERAL_ERROR"
    fi

    # Setup installation directory
    if ! setup_installation_directory; then
        return "$EXIT_PERMISSION_DENIED"
    fi

    # Get versions
    current_version="$(get_current_version)"
    installed_version="$(get_installed_version)"

    # Check if already installed
    if test "$installed_version" != "not installed"; then
        version_comparison="$(compare_versions "$installed_version" "$current_version")"

        case "$version_comparison" in
            "equal")
                print_success "dk command already installed in $DK_INSTALL_PATH (${installed_version})"
                # Still setup shell integration in case it's missing
                local config_file
                config_file="$(detect_shell_config)"
                add_shell_integration "$config_file" "$current_version"
                return "$EXIT_SUCCESS"
                ;;
            "newer")
                print_warning "Installed version (${installed_version}) is newer than current (${current_version})"
                printf "Downgrade to current version? (y/N): "
                read -r response
                case "$response" in
                    [yY]|[yY][eE][sS]) ;;
                    *)
                        print_info "Installation cancelled"
                        return "$EXIT_SUCCESS"
                        ;;
                esac
                ;;
            "older")
                print_info "Updating from ${installed_version} to ${current_version}"
                ;;
        esac
    fi

        # Create temporary file with version replacement
    local temp_file
    temp_file="$(mktemp)"

    # Cleanup temp file on exit
    trap 'rm -f "$temp_file"' EXIT

    # Replace version placeholder
    sed "s/__DK_VERSION__/${current_version}/g" "$DK_SOURCE_SCRIPT" > "$temp_file"

    # Copy to installation path
    if cp "$temp_file" "$DK_INSTALL_PATH"; then
        chmod +x "$DK_INSTALL_PATH"
        print_success "dk command installed successfully"
        print_info "Version: $current_version"
        print_info "Location: $DK_INSTALL_PATH"
    else
        print_error "Failed to install dk command"
        return "$EXIT_GENERAL_ERROR"
    fi

    # Setup shell integration
    local config_file
    config_file="$(detect_shell_config)"
    add_shell_integration "$config_file" "$current_version"

    return "$EXIT_SUCCESS"
}

# Uninstall dk command
uninstall_dk_command() {
    if test ! -f "$DK_INSTALL_PATH"; then
        print_warning "dk command not found at $DK_INSTALL_PATH"
        echo -e "already uninstalled or was never installed"
        return "$EXIT_SUCCESS"
    fi

    local installed_version
    installed_version="$(get_installed_version)"

    print_warning "This will remove dk command (${installed_version}) from system"
    printf "Continue? (y/N): "
    read -r response

    case "$response" in
        [yY]|[yY][eE][sS])
            # Remove executable file
            if rm -f "$DK_INSTALL_PATH"; then
                print_success "removed dk command"
            else
                print_error "Failed to remove $DK_INSTALL_PATH"
                return "$EXIT_PERMISSION_DENIED"
            fi

            # Remove shell integration
            local config_file
            config_file="$(detect_shell_config)"
            remove_shell_integration "$config_file" "verbose"

            print_success "dk command completely uninstalled"
            ;;
        *)
            echo -e "Uninstall cancelled"
            ;;
    esac

    return "$EXIT_SUCCESS"
}

# Show dk command status
show_dk_status() {
    local current_version installed_version os_type version_comparison

    print_header "DK COMMAND STATUS"

    # System information
    os_type="$(detect_os)"
    echo -e  "Operating System: $os_type"
    echo -e "Shell: $(basename "$SHELL")"

    # Version information
    current_version="$(get_current_version)"
    installed_version="$(get_installed_version)"

    echo -e "Current DockerKit version: $current_version"

    # Installation status
    if test "$installed_version" = "not installed"; then
        print_warning "dk command: Not installed"
        print_tip "Install with: make dk-install"
    else
        print_success "dk command: Installed (${installed_version})"
        echo -e "Installation path: $DK_INSTALL_PATH"

        # Version comparison
        version_comparison="$(compare_versions "$installed_version" "$current_version")"
        case "$version_comparison" in
            "equal")
                print_success "Version: Up to date"
                ;;
            "older")
                print_warning "Version: Update available"
                print_tip "Update with: make dk-install"
                ;;
            "newer")
                echo -e "Version: Newer than current DockerKit"
                ;;
        esac
    fi

    # Shell integration
    if check_shell_integration; then
        print_success "Shell integration: Configured"
        local config_file
        config_file="$(detect_shell_config)"
        echo -e "Location: $config_file"
    else
        print_warning "Shell integration: Not configured"
        print_tip "Run: make dk-install"
    fi

    # Docker availability
    if command -v docker >/dev/null 2>&1; then
        print_success "Docker: Available"
    else
        print_error "Docker: Not found in PATH"
    fi

    return "$EXIT_SUCCESS"
}

# Show help
show_help() {
    cat << EOF
DockerKit dk Command Manager

USAGE:
    ./manager.sh {install|uninstall|status}

COMMANDS:
    install     Install dk command to ~/.local/bin/
    uninstall   Remove dk command from system
    status      Show installation status and version information

EXAMPLES:
    ./manager.sh install     # Install or update dk command
    ./manager.sh status      # Check current status
    ./manager.sh uninstall   # Remove dk command

REQUIREMENTS:
    • macOS, Linux, or WSL2 (Windows not supported)
    • Write access to ~/.local/bin/ directory
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
        status)
            show_dk_status
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
