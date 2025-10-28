#!/bin/bash

# =============================================================================
# DOCKERKIT QUICK CONNECT - SYSTEM-WIDE INSTALLATION
# =============================================================================
# Quick connect to DockerKit workspace container from any project directory
# Projects can be located alongside DockerKit (sibling directories)
# Supports nested project structures and automatic detection
# Compatible: macOS, Linux, WSL2
# Usage: dk [--help]
# =============================================================================

set -euo pipefail

# =============================================================================
# SCRIPT METADATA
# =============================================================================

# Cache for projects root directory (to avoid repeated searches)
_CACHED_PROJECTS_ROOT=""

# Update check constants
readonly LAST_CHECK_FILE="$HOME/.dockerkit/last-update-check"
readonly GITHUB_API_URL="https://api.github.com/repos/abordage/dockerkit/releases/latest"

# =============================================================================
# STANDARD EXIT CODES
# =============================================================================

readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1

# =============================================================================
# COLOR CONSTANTS
# =============================================================================

readonly _RED='\033[0;31m'
readonly _GREEN='\033[0;32m'
readonly _YELLOW='\033[1;33m'
readonly _GRAY='\033[2;37m'
readonly _RESET='\033[0m'

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Print colored messages (POSIX compatible)
print_error() { printf '%b\n' "${_RED}$1${_RESET}" >&2; }
print_warning() { printf '%b\n' "${_YELLOW}$1${_RESET}"; }
print_info() { printf '%s\n' "$1"; }

# Fail with error and optional hint (unified error handling)
fail_with_hint() {
    local error_msg="$1"
    local hint_msg="${2:-}"

    print_error "${error_msg}"
    test -n "${hint_msg}" && print_info "${hint_msg}" >&2
    return "${EXIT_ERROR}"
}

# Color wrapper functions for inline text coloring
green() { printf '%b' "${_GREEN}$1${_RESET}"; }
yellow() { printf '%b' "${_YELLOW}$1${_RESET}"; }
gray() { printf '%b' "${_GRAY}$1${_RESET}"; }

# Detect operating system (improved WSL2 detection)
detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)
            # Check multiple WSL indicators for better detection
            if test -f /proc/version && grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl2"
            elif test -n "${WSL_DISTRO_NAME:-}" || test -n "${WSLENV:-}"; then
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
    local name="$1"

    # Empty name is invalid
    test -z "$name" && return 1

    # Name must contain only safe characters
    case "$name" in
        *[^a-zA-Z0-9._/-]*) return 1 ;;
        *) return 0 ;;
    esac
}

# Check if directory is a DockerKit installation
is_dockerkit_directory() {
    local dir="$1"

    # Must have docker-compose.yml with workspace service
    test -f "${dir}/docker-compose.yml" || return 1
    grep -q "workspace:" "${dir}/docker-compose.yml" 2>/dev/null || return 1

    # Must have DockerKit-specific files
    test -f "${dir}/tools/dk/dk.sh" || test -f "${dir}/tools/dk/manager.sh" || return 1

    return 0
}

# Find projects root directory (parent directory where DockerKit and projects are located)
find_projects_root() {
    local current_dir="${1:-$(pwd)}"
    local max_depth=10
    local depth=0

    while test "${depth}" -lt "${max_depth}"; do
        # Check if current directory contains a DockerKit installation
        if test -d "${current_dir}"; then
            for dir in "${current_dir}"/*; do
                if test -d "$dir" && is_dockerkit_directory "$dir"; then
                    printf '%s\n' "${current_dir}"
                    return 0
                fi
            done
        fi

        # Reached filesystem root
        if test "${current_dir}" = "/" || test "${current_dir}" = "."; then
            return 1
        fi

        # Move one level up (inline dirname implementation)
        case "${current_dir}" in
            */*) current_dir="${current_dir%/*}" ;;
            *) current_dir="." ;;
        esac
        depth=$((depth + 1))
    done

    return 1
}

# Calculate relative path from projects root to current directory
get_relative_path_from_projects_root() {
    local projects_root="$1"
    local current_dir
    current_dir="$(pwd)"

    # Remove projects root prefix and leading slash
    local relative_path="${current_dir#"${projects_root}"}"
    relative_path="${relative_path#/}"

    printf '%s\n' "${relative_path}"
}

# Get projects root with caching (performance optimization)
get_projects_root_cached() {
    if test -z "${_CACHED_PROJECTS_ROOT}"; then
        _CACHED_PROJECTS_ROOT="$(find_projects_root)" || return 1
    fi
    printf '%s\n' "${_CACHED_PROJECTS_ROOT}"
}

# Get projects root or fail with error (convenience wrapper)
require_projects_root() {
    get_projects_root_cached || {
        print_error "Projects root not found"
        return "${EXIT_ERROR}"
    }
}

# =============================================================================
# UPDATE CHECK FUNCTIONS
# =============================================================================

# Check if we need to check for updates today
should_check_today() {
    local today last_check_date
    today=$(date +%Y-%m-%d)

    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$LAST_CHECK_FILE")" 2>/dev/null
    last_check_date=$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo "")

    # Check if date is different
    test "$today" != "$last_check_date"
}

# Mark that we checked today
mark_check_completed() {
    mkdir -p "$(dirname "$LAST_CHECK_FILE")" 2>/dev/null
    date +%Y-%m-%d > "$LAST_CHECK_FILE"
}

# Get current DockerKit version from git tags
get_current_dockerkit_version() {
    local projects_root dockerkit_dir

    # Find projects root directory
    projects_root="$(require_projects_root)" || {
        echo "unknown"
        return 1
    }

    # Find first DockerKit directory
    for dir in "${projects_root}"/*; do
        if test -d "$dir" && is_dockerkit_directory "$dir"; then
            dockerkit_dir="$dir"
            break
        fi
    done

    if test -n "${dockerkit_dir}"; then
        (cd "$dockerkit_dir" && git describe --tags --abbrev=0 2>/dev/null) || echo "unknown"
    else
        echo "unknown"
    fi
}

# Get latest version from GitHub API
get_latest_version_from_api() {
    curl -s --connect-timeout 3 --max-time 5 "$GITHUB_API_URL" 2>/dev/null |
        grep '"tag_name"' |
        cut -d'"' -f4
}

# Show colored update notification
show_update_notification() {
    local current="$1"
    local latest="$2"

    echo ""
    printf '%b\n' "⚡ DockerKit $(yellow "${latest}") available! Current: $(yellow "${current}")"
    printf '%b\n' "   $(gray "Run 'make update' in DockerKit directory to upgrade")"
    echo ""
}

# Main update check function
perform_daily_update_check() {
    # Check if update check is disabled
    if test "${DOCKERKIT_DISABLE_UPDATE_CHECK:-0}" = "1"; then
        return 0
    fi

    # Check only once per day
    if ! should_check_today; then
        return 0
    fi

    # Get current version
    local current_version latest_version
    current_version=$(get_current_dockerkit_version)

    # Skip if version is unknown
    if test "$current_version" = "unknown"; then
        return 0
    fi

    # Get latest version and compare
    if latest_version=$(get_latest_version_from_api); then
        if test -n "$latest_version" && test "$current_version" != "$latest_version"; then
            show_update_notification "$current_version" "$latest_version"
        fi
    fi

    # Mark that we checked today (regardless of result)
    mark_check_completed
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

# Validate project location (not in root or DockerKit directory)
validate_project_location() {
    local projects_root="$1"
    local relative_path="$2"

    # Check not in projects root
    if test -z "${relative_path}"; then
        fail_with_hint "You are in projects root directory" \
                       "Navigate to a project directory"
    fi

    # Check not inside DockerKit directory
    local project_first_dir="${relative_path%%/*}"
    if is_dockerkit_directory "${projects_root}/${project_first_dir}"; then
        fail_with_hint "You are inside DockerKit directory" \
                       "Navigate to a project directory (not DockerKit)"
    fi

    return 0
}

# Show help message
show_help() {
    cat << EOF
DockerKit Quick Connect

USAGE:
    dk [OPTIONS]

DESCRIPTION:
    Quick connect to DockerKit workspace container from any project directory.
    Projects should be located alongside DockerKit (as sibling directories).
    Automatically detects DockerKit instances and calculates correct workdir.

OPTIONS:
    --help          Show this help message

EXAMPLES:
    # Directory structure:
    # /projects/
    # ├── dockerkit-82/        ← DockerKit
    # ├── project.localhost/   ← Your projects
    # └── abordage/
    #     └── project-2/

    cd project.localhost && dk     # workdir: /var/www/project.localhost
    cd abordage/project-2 && dk    # workdir: /var/www/abordage/project-2

REQUIREMENTS:
    • Must be run from a project directory (sibling of DockerKit folder)
    • At least one DockerKit instance must be running
    • Docker and docker compose must be installed

INSTALLATION:
    dk command is automatically installed during 'make setup'
    and removed during 'make reset' from DockerKit directory.
    Compatible:         macOS, Linux, WSL2

MORE INFO:
    Documentation:      https://github.com/abordage/dockerkit
    Report Issues:      https://github.com/abordage/dockerkit/issues

EOF
}

# Detect current project path relative to projects root
detect_current_project() {
    local projects_root relative_path

    # Find projects root directory
    if ! projects_root="$(get_projects_root_cached)"; then
        fail_with_hint "Projects root not found" \
                       "Navigate to a project directory (sibling of DockerKit folder)"
    fi

    # Get relative path from projects root
    relative_path="$(get_relative_path_from_projects_root "${projects_root}")"

    # Validate location (not in root or DockerKit)
    validate_project_location "${projects_root}" "${relative_path}" || return "${EXIT_ERROR}"

    # Validate path contains only safe characters
    if ! validate_project_name "${relative_path}"; then
        fail_with_hint "Invalid project path: ${relative_path}" \
                       "Path contains invalid characters"
    fi

    printf '%s\n' "${relative_path}"
}

# Discover available DockerKit instances
discover_dockerkits() {
    local projects_root

    # Find projects root directory
    projects_root="$(require_projects_root)" || return "${EXIT_ERROR}"

    if test ! -d "${projects_root}"; then
        return "${EXIT_ERROR}"
    fi

    # Find all DockerKit directories
    for dir in "${projects_root}"/*; do
        if test -d "$dir" && is_dockerkit_directory "$dir"; then
            # Print basename (inline implementation)
            printf '%s\n' "${dir##*/}"
        fi
    done | sort
}

# Check which DockerKit instances are running
check_running_dockerkits() {
    local projects_root dockerkits_found

    # Find projects root directory
    projects_root="$(require_projects_root)" || return "${EXIT_ERROR}"

    dockerkits_found="$(discover_dockerkits)"
    test -n "${dockerkits_found}" || return "${EXIT_ERROR}"

    echo "${dockerkits_found}" | while IFS= read -r dockerkit; do
        local dockerkit_path="${projects_root}/${dockerkit}"
        if docker compose -f "${dockerkit_path}/docker-compose.yml" ps --services --filter "status=running" 2>/dev/null | grep -q .; then
            printf '%s\n' "${dockerkit}"
        fi
    done
}

# Show available DockerKit options when nothing is running
show_available_options() {
    local dockerkits_found
    dockerkits_found="$(discover_dockerkits)"

    if test -z "${dockerkits_found}"; then
        fail_with_hint "No DockerKit installations found" \
                       "Expected directories with docker-compose.yml containing workspace service"
    fi

    print_warning "No DockerKit instances running."

    return "${EXIT_SUCCESS}"
}

# Connect to running workspace container
connect_to_workspace() {
    local running_dockerkit project_path projects_root dockerkit_path workdir
    running_dockerkit="$1"
    project_path="$2"

    # Find projects root directory
    projects_root="$(require_projects_root)" || return "${EXIT_ERROR}"

    # Construct path to running dockerkit
    dockerkit_path="${projects_root}/${running_dockerkit}"

    # Construct workdir path - use relative path from projects root
    workdir="/var/www/${project_path}"

    if test ! -d "${dockerkit_path}"; then
        print_error "DockerKit directory not found: ${dockerkit_path}"
        return "${EXIT_ERROR}"
    fi

    printf '%b\n' "Service: $(green "${running_dockerkit}") $(gray "workspace")"
    printf '%b\n' "Project: $(gray "${project_path}")"
    printf '%b\n' "Workdir: $(gray "${workdir}")"

    # Change to dockerkit directory and execute
    cd "${dockerkit_path}" || {
        print_error "Cannot access DockerKit directory: ${dockerkit_path}"
        return "${EXIT_ERROR}"
    }

    exec docker compose exec -it --workdir="${workdir}" workspace bash
}

# Parse command line arguments
parse_arguments() {
    while test $# -gt 0; do
        case "$1" in
            --help|-h)
                show_help
                exit "${EXIT_SUCCESS}"
                ;;
            -*)
                print_error "Unknown option: $1"
                show_help
                exit "${EXIT_ERROR}"
                ;;
            *)
                print_error "Unexpected argument: $1"
                show_help
                exit "${EXIT_ERROR}"
                ;;
        esac
    done
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

# Validate environment (OS compatibility and update check)
validate_environment() {
    perform_daily_update_check

    local -r os_type="$(detect_os)"
    if test "${os_type}" = "windows"; then
        print_error "Windows is not supported. Use WSL2 instead."
        exit "${EXIT_ERROR}"
    fi
}

# Find running DockerKit instance or exit with message
find_running_instance() {
    local -r running_dockerkits="$(check_running_dockerkits)"

    if test -z "${running_dockerkits}"; then
        show_available_options
        exit "${EXIT_SUCCESS}"
    fi

    local -r running_count="$(echo "${running_dockerkits}" | wc -l | tr -d ' ')"

    if test "${running_count}" -gt 1; then
        print_warning "Multiple DockerKit instances are running!"
        print_warning "This may cause port conflicts. Please stop unused instances."
        print_info "Connecting to first found instance"
    fi

    echo "${running_dockerkits}" | head -n 1
}

# Main entry point
main() {
    validate_environment
    parse_arguments "$@"

    local project_path first_running
    project_path="$(detect_current_project)" || exit "${EXIT_ERROR}"
    first_running="$(find_running_instance)"

    connect_to_workspace "${first_running}" "${project_path}"
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Ensure docker is available
if ! command -v docker >/dev/null 2>&1; then
    print_error "docker command not found"
    print_info "Please install Docker and ensure it's in your PATH"
    exit "${EXIT_ERROR}"
fi

# Execute main function
main "$@"
