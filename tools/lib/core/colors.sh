#!/bin/bash

# =============================================================================
# COLOR DEFINITIONS
# =============================================================================
# ANSI color codes and formatting functions for terminal output
# Usage: source this file to access color variables and functions
# =============================================================================

set -euo pipefail

# Prevent multiple inclusion
if [[ "${DOCKERKIT_COLORS_LOADED:-}" == "true" ]]; then
    return 0
fi

readonly _RED='\033[0;31m'
readonly _GREEN='\033[0;32m'
readonly _YELLOW='\033[1;33m'
readonly _BLUE='\033[0;34m'
readonly _PURPLE='\033[0;35m'
readonly _CYAN='\033[0;36m'
readonly _WHITE='\033[1;37m'
readonly _GRAY='\033[2;37m'
readonly _RESET='\033[0m'

if [ -z "${CHECK_ICON:-}" ]; then
    readonly CHECK_ICON="✓"
    readonly CROSS_ICON="✗"
    readonly DOWN_ARROW_UP_ARROW="↳"
fi

readonly DOCKERKIT_COLORS_LOADED="true"

green() { printf '%b' "${_GREEN}$1${_RESET}"; }
red() { printf '%b' "${_RED}$1${_RESET}"; }
yellow() { printf '%b' "${_YELLOW}$1${_RESET}"; }
cyan() { printf '%b' "${_CYAN}$1${_RESET}"; }
blue() { printf '%b' "${_BLUE}$1${_RESET}"; }
purple() { printf '%b' "${_PURPLE}$1${_RESET}"; }
white() { printf '%b' "${_WHITE}$1${_RESET}"; }
gray() { printf '%b' "${_GRAY}$1${_RESET}"; }

print() {
    printf '%b\n' "$1"
}

print_header() {
    local message="$1"
    local box_width=62
    local msg_len=${#message}
    local padding_left=$(((box_width - msg_len) / 2))
    local padding_right=$((box_width - msg_len - padding_left))

    echo
    printf '%b\n' "$(purple '╔══════════════════════════════════════════════════════════════╗')"
    printf "${_PURPLE}║${_WHITE}%*s${_PURPLE}║${_RESET}\n" $box_width " "
    printf "${_PURPLE}║${_WHITE}%*s%s%*s${_PURPLE}║${_RESET}\n" $padding_left " " "$message" $padding_right " "
    printf "${_PURPLE}║${_WHITE}%*s${_PURPLE}║${_RESET}\n" $box_width " "
    printf '%b\n' "$(purple '╚══════════════════════════════════════════════════════════════╝')"
}

print_section() {
    printf '\n%b\n' "$(cyan "➤ $1")"
}

print_success() {
    printf '  %b %s\n' "$(green "${CHECK_ICON}")" "$1"
}

print_warning() {
    printf '%b\n' "$(yellow "$1")"
}

print_error() {
    printf '  %b %s\n' "$(red "${CROSS_ICON}")" "$1"
}

print_info() {
    printf '  %b\n' "$(blue "$1")"
}

print_tip() {
    printf '  %s %s\n' "${DOWN_ARROW_UP_ARROW}" "$1"
}
