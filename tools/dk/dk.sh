#!/bin/bash

# =============================================================================
# DOCKERKIT QUICK CONNECT - SYSTEM-WIDE INSTALLATION
# =============================================================================
# Quick connect to DockerKit workspace container from any .local project
# Compatible: macOS, Linux, WSL2
# Usage: dk [--help|--version|--uninstall]
# =============================================================================

set -euo pipefail

# =============================================================================
# SCRIPT METADATA
# =============================================================================

readonly DK_VERSION="__DK_VERSION__"  # Replaced during installation
readonly INSTALL_PATH="$HOME/.local/bin/dk"

# =============================================================================
# STANDARD EXIT CODES
# =============================================================================

readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_INVALID_CONFIG=3
readonly EXIT_PERMISSION_DENIED=4

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Print colored messages
print_error() { echo -e "\033[0;31m✗\033[0m $1" >&2; }
print_success() { echo -e "\033[0;32m✓\033[0m $1"; }
print_warning() { echo -e "\033[1;33m⚠\033[0m $1"; }
print_info() { echo -e "\033[0;34mℹ\033[0m $1"; }

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

# Validate project directory name
validate_project_name() {
    case "$1" in
        *[^a-zA-Z0-9._-]*) return 1 ;;
        *.local) return 0 ;;
        *) return 1 ;;
    esac
}

# Safe basename implementation
safe_basename() {
    printf '%s\n' "${1##*/}"
}

# Safe dirname implementation
safe_dirname() {
    case "$1" in
        */*) printf '%s\n' "${1%/*}" ;;
        *) printf '.\n' ;;
    esac
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

# Show help message
show_help() {
    cat << 'EOF'
DockerKit Quick Connect

USAGE:
    dk [OPTIONS]

DESCRIPTION:
    Quick connect to DockerKit workspace container from any .local project.
    Automatically detects current project and available DockerKit instances.

OPTIONS:
    --help          Show this help message
    --version       Show version information
    --uninstall     Remove dk command from system

EXAMPLES:
    dk                      # Connect to workspace or show available options
    dk --version            # Show version and installation info

REQUIREMENTS:
    • Must be run from a .local project directory
    • At least one DockerKit instance must be available
    • Docker and docker compose must be installed

MORE INFO:
    Documentation:      https://github.com/abordage/dockerkit
    Report Issues:      https://github.com/abordage/dockerkit/issues

EOF
}

# Show version information
show_version() {
    local install_location
    install_location="$(command -v dk 2>/dev/null || echo "not found")"

    cat << EOF
DockerKit Quick Connect ${DK_VERSION}
Compatible: macOS, Linux, WSL2
Installation: ${install_location}
Project: $(detect_current_project 2>/dev/null || echo "not in .local project")

Repository: https://github.com/abordage/dockerkit
EOF
}

# Handle self-uninstallation
handle_uninstall() {
    if test ! -f "${INSTALL_PATH}"; then
        print_error "dk command not found at ${INSTALL_PATH}"
        return "${EXIT_INVALID_CONFIG}"
    fi

    print_warning "This will remove dk command from ${INSTALL_PATH}"
    printf "Continue? (y/N): "
    read -r response

    case "${response}" in
        [yY]|[yY][eE][sS])
            if rm -f "${INSTALL_PATH}"; then
                print_success "dk command uninstalled"
                return "${EXIT_SUCCESS}"
            else
                print_error "Failed to remove ${INSTALL_PATH}"
                return "${EXIT_PERMISSION_DENIED}"
            fi
            ;;
        *)
            print_info "Uninstall cancelled"
            return "${EXIT_SUCCESS}"
            ;;
    esac
}

# Detect current project name from directory
detect_current_project() {
    local current_dir project_name
    current_dir="$(pwd)"
    project_name="$(safe_basename "${current_dir}")"

    if ! validate_project_name "${project_name}"; then
        print_error "Current directory is not a .local project: ${project_name}"
        print_info "Navigate to a project directory ending with .local"
        return "${EXIT_INVALID_CONFIG}"
    fi

    printf '%s\n' "${project_name}"
}

# Discover available DockerKit instances
discover_dockerkits() {
    local projects_dir
    projects_dir="$(safe_dirname "$(pwd)")"

    if test ! -d "${projects_dir}"; then
        return "${EXIT_INVALID_CONFIG}"
    fi

    find "${projects_dir}" -maxdepth 1 -type d 2>/dev/null | while IFS= read -r dir; do
        test -f "${dir}/docker-compose.yml" || continue
        if grep -q "workspace:" "${dir}/docker-compose.yml" 2>/dev/null; then
            safe_basename "${dir}"
        fi
    done | sort
}

# Check which DockerKit instances are running
check_running_dockerkits() {
    local projects_dir dockerkits_found running_dockerkits
    projects_dir="$(safe_dirname "$(pwd)")"
    dockerkits_found=""
    running_dockerkits=""

    dockerkits_found="$(discover_dockerkits)"
    test -n "${dockerkits_found}" || return "${EXIT_INVALID_CONFIG}"

    echo "${dockerkits_found}" | while IFS= read -r dockerkit; do
        local dockerkit_path="${projects_dir}/${dockerkit}"
        if docker compose -f "${dockerkit_path}/docker-compose.yml" ps --services --filter "status=running" 2>/dev/null | grep -q .; then
            printf '%s\n' "${dockerkit}"
        fi
    done
}

# Validate multiple running instances
validate_multiple_running() {
    local running_count
    running_count="$1"

    if test "${running_count}" -gt 1; then
        print_warning "Multiple DockerKit instances are running!"
        print_warning "This may cause port conflicts. Please stop unused instances."
        print_info "Example: cd ../dockerkit-XX && make stop"
        return "${EXIT_GENERAL_ERROR}"
    fi

    return "${EXIT_SUCCESS}"
}

# Show available DockerKit options when nothing is running
show_available_options() {
    local dockerkits_found
    dockerkits_found="$(discover_dockerkits)"

    if test -z "${dockerkits_found}"; then
        print_error "No DockerKit installations found"
        print_info "Expected directories with docker-compose.yml containing workspace service"
        return "${EXIT_INVALID_CONFIG}"
    fi

    print_info "No DockerKit instances running."
    print_info "Available DockerKit installations:"

    echo "${dockerkits_found}" | while IFS= read -r dockerkit; do
        echo "  • ${dockerkit}"
    done

    echo ""
    print_info "Start one with: cd ../<dockerkit-name> && make start"

    return "${EXIT_SUCCESS}"
}

# Connect to running workspace container
connect_to_workspace() {
    local running_dockerkit project_name projects_dir dockerkit_path workdir
    running_dockerkit="$1"
    project_name="$2"
    projects_dir="$(safe_dirname "$(pwd)")"
    dockerkit_path="${projects_dir}/${running_dockerkit}"
    workdir="/var/www/${project_name}"

    if test ! -d "${dockerkit_path}"; then
        print_error "DockerKit directory not found: ${dockerkit_path}"
        return "${EXIT_INVALID_CONFIG}"
    fi

    print_info "Connecting to ${running_dockerkit} workspace container..."
    print_info "Project: ${project_name}"
    print_info "Workdir: ${workdir}"

    # Change to dockerkit directory and execute
    cd "${dockerkit_path}" || {
        print_error "Cannot access DockerKit directory: ${dockerkit_path}"
        return "${EXIT_PERMISSION_DENIED}"
    }

    exec docker compose exec --workdir="${workdir}" workspace bash
}

# Parse command line arguments
parse_arguments() {
    while test $# -gt 0; do
        case "$1" in
            --help|-h)
                show_help
                exit "${EXIT_SUCCESS}"
                ;;
            --version|-v)
                show_version
                exit "${EXIT_SUCCESS}"
                ;;
            --uninstall)
                handle_uninstall
                exit $?
                ;;
            -*)
                print_error "Unknown option: $1"
                show_help
                exit "${EXIT_GENERAL_ERROR}"
                ;;
            *)
                print_error "Unexpected argument: $1"
                show_help
                exit "${EXIT_GENERAL_ERROR}"
                ;;
        esac
    done
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    local os_type project_name running_dockerkits running_count

    # Check OS compatibility
    os_type="$(detect_os)"
    if test "${os_type}" = "windows"; then
        print_error "Windows is not supported. Use WSL2 instead."
        exit "${EXIT_GENERAL_ERROR}"
    fi

    # Parse arguments
    parse_arguments "$@"

    # Detect current project
    if ! project_name="$(detect_current_project)"; then
        exit "${EXIT_INVALID_CONFIG}"
    fi

    # Check for running DockerKit instances
    running_dockerkits="$(check_running_dockerkits)"

    if test -z "${running_dockerkits}"; then
        # No running instances - show available options
        show_available_options
        exit "${EXIT_SUCCESS}"
    fi

    # Count running instances
    running_count="$(echo "${running_dockerkits}" | wc -l | tr -d ' ')"

    # Validate multiple running (but continue with first found)
    if ! validate_multiple_running "${running_count}"; then
        print_info "Connecting to first found instance..."
    fi

    # Get first running instance
    local first_running
    first_running="$(echo "${running_dockerkits}" | head -n 1)"

    # Connect to workspace
    connect_to_workspace "${first_running}" "${project_name}"
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Ensure docker is available
if ! command -v docker >/dev/null 2>&1; then
    print_error "docker command not found"
    print_info "Please install Docker and ensure it's in your PATH"
    exit "${EXIT_GENERAL_ERROR}"
fi

# Execute main function
main "$@"
