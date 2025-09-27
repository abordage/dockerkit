#!/bin/bash

# =============================================================================
# COMMON UTILITIES
# =============================================================================
# Common utility functions used across multiple scripts
# =============================================================================

set -euo pipefail

# Prevent multiple inclusion
if [[ "${DOCKERKIT_UTILS_LOADED:-}" == "true" ]]; then
    return 0
fi

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/base.sh"

# Ensure colors are loaded
if ! command -v red >/dev/null 2>&1; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

# Mark as loaded
readonly DOCKERKIT_UTILS_LOADED="true"

# =============================================================================
# DEBUG FUNCTIONS
# =============================================================================

readonly DEBUG="${DEBUG:-0}"

debug_log() {
    local component="${1:-general}"
    local message="$2"

    if [[ "$DEBUG" == "1" ]]; then
        printf "DEBUG[%s]: %s\n" "$component" "$message" >&2
    fi
}

# =============================================================================
# SYSTEM UTILITIES
# =============================================================================

detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)
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

command_exists() {
    local command_name="$1"

    if [ "$command_name" = "docker compose" ]; then
        docker compose version >/dev/null 2>&1
    else
        command -v "$command_name" >/dev/null 2>&1
    fi
}

get_command_version() {
    local command_name="$1"
    local version_flag="${2:---version}"

    if ! command_exists "$command_name"; then
        echo "not_installed"
        return "$EXIT_GENERAL_ERROR"
    fi

    case "$command_name" in
        git)
            git --version | tr -s ' ' | cut -d' ' -f3
            ;;
        docker)
            docker --version | cut -d' ' -f3 | tr -d ','
            ;;
        "docker compose")
            if docker compose version --short >/dev/null 2>&1; then
                docker compose version --short
            else
                echo "not_installed"
                return "$EXIT_GENERAL_ERROR"
            fi
            ;;
        make)
            make --version | head -1 | tr -s ' ' | cut -d' ' -f3
            ;;
        bash)
            bash --version | head -1 | tr -s ' ' | cut -d' ' -f4 | cut -d'(' -f1
            ;;
        curl)
            curl --version | head -1 | tr -s ' ' | cut -d' ' -f2
            ;;
        brew)
            brew --version | head -1 | tr -s ' ' | cut -d' ' -f2 | cut -d'-' -f1
            ;;
        mkcert)
            mkcert --version 2>/dev/null | head -1 | tr -d ' \t' | sed 's/^v//' || echo "unknown"
            ;;
        *)
            $command_name "$version_flag" 2>/dev/null | head -1 || echo "unknown"
            ;;
    esac
}

version_compare() {
    local version1="$1"
    local version2="$2"

    if [ "$version1" = "$version2" ]; then
        return "$EXIT_SUCCESS"
    fi

    if [ "$version1" = "not_installed" ] || [ "$version1" = "unknown" ]; then
        return "$EXIT_GENERAL_ERROR"
    fi

    if [ "$version2" = "not_installed" ] || [ "$version2" = "unknown" ]; then
        return "$EXIT_SUCCESS"
    fi

    version1=$(echo "$version1" | sed 's/^v//' | sed 's/[^0-9.].*//')
    version2=$(echo "$version2" | sed 's/^v//' | sed 's/[^0-9.].*//')

    if command -v sort >/dev/null 2>&1; then
        local sorted_versions
        sorted_versions=$(printf '%s\n%s\n' "$version1" "$version2" | sort -V)

        if [ "$(echo "$sorted_versions" | tail -1)" = "$version1" ]; then
            return "$EXIT_SUCCESS"
        else
            return "$EXIT_GENERAL_ERROR"
        fi
    else
        # Fallback to simple string comparison for systems without sort -V
        if [ "$version1" = "$version2" ]; then
            return "$EXIT_SUCCESS"
        elif [ "$(printf '%s\n%s\n' "$version1" "$version2" | sort | tail -1)" = "$version1" ]; then
            return "$EXIT_SUCCESS"
        else
            return "$EXIT_GENERAL_ERROR"
        fi
    fi
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_standard_arguments() {
    local help_function="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                "$help_function"
                exit "$EXIT_SUCCESS"
                ;;
            *)
                print_error "Unknown parameter: $1"
                "$help_function"
                exit "$EXIT_GENERAL_ERROR"
                ;;
        esac
    done
}
