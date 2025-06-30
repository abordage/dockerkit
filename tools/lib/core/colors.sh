#!/bin/bash

# =============================================================================
# COLOR DEFINITIONS
# =============================================================================
# ANSI color codes and formatting functions for terminal output
# Usage: source this file to access color variables and functions
# =============================================================================

set -euo pipefail

# Local ANSI color codes (not exported, only for this file)
readonly _RED='\033[0;31m'
readonly _GREEN='\033[0;32m'
readonly _YELLOW='\033[1;33m'
readonly _BLUE='\033[0;34m'
readonly _PURPLE='\033[0;35m'
readonly _CYAN='\033[0;36m'
readonly _WHITE='\033[1;37m'
readonly _RESET='\033[0m'

# Icons (only define if not already set)
if [ -z "${CHECK_ICON:-}" ]; then
    readonly CHECK_ICON="✓"
    readonly CROSS_ICON="✗"
    readonly DOWN_ARROW_UP_ARROW="↳"
fi

# Color wrapper functions for inline text coloring
green() { echo -e "${_GREEN}$1${_RESET}"; }
red() { echo -e "${_RED}$1${_RESET}"; }
yellow() { echo -e "${_YELLOW}$1${_RESET}"; }
cyan() { echo -e "${_CYAN}$1${_RESET}"; }
blue() { echo -e "${_BLUE}$1${_RESET}"; }
purple() { echo -e "${_PURPLE}$1${_RESET}"; }
white() { echo -e "${_WHITE}$1${_RESET}"; }

# Output formatting functions
print_header() {
    local message="$1"
    local box_width=62
    local msg_len=${#message}
    local padding_left=$(((box_width - msg_len) / 2))
    local padding_right=$((box_width - msg_len - padding_left))

    echo
    echo -e "$(purple '╔══════════════════════════════════════════════════════════════╗')"
    printf "${_PURPLE}║${_WHITE}%*s${_PURPLE}║${_RESET}\n" $box_width " "
    printf "${_PURPLE}║${_WHITE}%*s%s%*s${_PURPLE}║${_RESET}\n" $padding_left " " "$message" $padding_right " "
    printf "${_PURPLE}║${_WHITE}%*s${_PURPLE}║${_RESET}\n" $box_width " "
    echo -e "$(purple '╚══════════════════════════════════════════════════════════════╝')"
}

print_section() {
    echo -e "\n$(cyan "➤ $1")"
}

print_success() {
    echo -e "  $(green "${CHECK_ICON}") $1"
}

print_warning() {
    echo -e "$(yellow "$1")"
}

print_error() {
    echo -e "  $(red "${CROSS_ICON}") $1"
}

print_info() {
    echo -e "  $(blue "$1")"
}

print_tip() {
    echo -e " ${DOWN_ARROW_UP_ARROW} $1"
}
