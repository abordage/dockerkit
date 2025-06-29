#!/bin/bash

# =============================================================================
# COLOR DEFINITIONS
# =============================================================================
# ANSI color codes and formatting functions for terminal output
# Usage: source this file to access color variables and functions
# =============================================================================

set -euo pipefail

# Color constants (only define if not already set)
if [ -z "${RED:-}" ]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly PURPLE='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly WHITE='\033[1;37m'
    readonly NC='\033[0m' # No Color
fi

# Icons (only define if not already set)
if [ -z "${CHECK_ICON:-}" ]; then
    readonly CHECK_ICON="✓"
    readonly CROSS_ICON="✗"
    readonly DOWN_ARROW_UP_ARROW="↳"
fi

# Output formatting functions
print_header() {
    local message="$1"
    local box_width=62
    local msg_len=${#message}
    local padding_left=$(((box_width - msg_len) / 2))
    local padding_right=$((box_width - msg_len - padding_left))

    echo
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    printf "${PURPLE}║${WHITE}%*s${PURPLE}║${NC}\n" $box_width " "
    printf "${PURPLE}║${WHITE}%*s%s%*s${PURPLE}║${NC}\n" $padding_left " " "$message" $padding_right " "
    printf "${PURPLE}║${WHITE}%*s${PURPLE}║${NC}\n" $box_width " "
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

print_section() {
    local message="$1"
    echo -e "\n${CYAN}➤ $message${NC}"
}

print_success() {
    local message="$1"
    echo -e "  ${GREEN}${CHECK_ICON}${NC} $message"
}

print_warning() {
    local message="$1"
    echo -e "${YELLOW}$message${NC}"
}

print_error() {
    local message="$1"
    echo -e "  ${RED}${CROSS_ICON}${NC} $message"
}

print_info() {
    local message="$1"
    echo -e "  ${BLUE}$message${NC}"
}

print_tip() {
    local message="$1"
    echo -e "  ${WHITE}${DOWN_ARROW_UP_ARROW}${NC} ${WHITE}$message${NC}"
}
