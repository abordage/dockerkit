#!/bin/bash

# =============================================================================
# TOOLS CHECKER
# =============================================================================
# Functions for checking system tools and their versions
# Usage: source this file and call check_system_tools
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"
source "$BASE_DIR/base.sh"

# Load dependencies
TOOLS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TOOLS_SCRIPT_DIR/../core/utils.sh"
source "$TOOLS_SCRIPT_DIR/../core/config.sh"

# Global arrays to track version issues
OUTDATED_TOOLS=()
MISSING_TOOLS=()
UPGRADE_SUGGESTIONS=()

# dk command constants
readonly DK_INSTALL_PATH="$HOME/.dockerkit/bin/dk"

# =============================================================================
# DK COMMAND FUNCTIONS
# =============================================================================

# Function get_dk_current_version() moved to utils.sh as get_project_version() for reuse

# Get installed dk version
get_dk_installed_version() {
    if test -f "$DK_INSTALL_PATH"; then
        local version
        version=$(grep "readonly DK_VERSION=" "$DK_INSTALL_PATH" 2>/dev/null | \
        sed 's/.*DK_VERSION="\([^"]*\)".*/\1/' | \
        head -n 1)
        echo "${version#v}"
    else
        echo "not_installed"
    fi
}

# Compare dk versions (simplified)
compare_dk_versions() {
    local version1="$1" version2="$2"

    # Remove 'v' prefix if present
    version1="${version1#v}"
    version2="${version2#v}"

    if test "$version1" = "$version2"; then
        echo "equal"
    elif test "$version1" \< "$version2"; then
        echo "older"
    else
        echo "newer"
    fi
}

# Check and display system tools information
check_system_tools() {
    print_section "System Tools"

    # Reset arrays
    OUTDATED_TOOLS=()
    MISSING_TOOLS=()
    UPGRADE_SUGGESTIONS=()

    check_git_version
    check_bash_version
    check_make_version
    check_homebrew_version
    check_curl_version
}

# Individual tool version checkers with minimum version validation
check_git_version() {
    local version
    version=$(get_command_version "git")

    if [ "$version" = "not_installed" ]; then
        print_error "Git: Not installed"
        MISSING_TOOLS+=("git")
    else
        print_success "Git: v$version"

        # Check version requirements silently
        if ! version_compare "$version" "$GIT_MIN_VERSION"; then
            OUTDATED_TOOLS+=("git:$version:$GIT_MIN_VERSION")
        elif ! version_compare "$version" "$GIT_RECOMMENDED_VERSION"; then
            UPGRADE_SUGGESTIONS+=("git:$version:$GIT_RECOMMENDED_VERSION")
        fi
    fi
}

check_bash_version() {
    local version
    version=$(get_command_version "bash")

    print_success "Bash: v$version"

    # Check version requirements silently
    if ! version_compare "$version" "$BASH_MIN_VERSION"; then
        OUTDATED_TOOLS+=("bash:$version:$BASH_MIN_VERSION")
    elif ! version_compare "$version" "$BASH_RECOMMENDED_VERSION"; then
        UPGRADE_SUGGESTIONS+=("bash:$version:$BASH_RECOMMENDED_VERSION")
    fi
}

check_make_version() {
    local version
    version=$(get_command_version "make")

    print_success "Make: v$version"

    # Check version requirements silently
    if ! version_compare "$version" "$MAKE_MIN_VERSION"; then
        OUTDATED_TOOLS+=("make:$version:$MAKE_MIN_VERSION")
    elif ! version_compare "$version" "$MAKE_RECOMMENDED_VERSION"; then
        UPGRADE_SUGGESTIONS+=("make:$version:$MAKE_RECOMMENDED_VERSION")
    fi
}

check_homebrew_version() {
    local version
    version=$(get_command_version "brew")

    if [ "$version" = "not_installed" ]; then
        print_warning "Homebrew: Not installed"
        MISSING_TOOLS+=("homebrew")
    else
        print_success "Homebrew: v$version"
    fi
}

check_curl_version() {
    local version
    version=$(get_command_version "curl")

    if [ "$version" = "not_installed" ]; then
        print_error "cURL: Not installed"
        MISSING_TOOLS+=("curl")
    else
        print_success "cURL: v$version"
    fi
}

check_hostctl_tool() {
    local version
    version=$(get_command_version "hostctl")

    if [ "$version" = "not_installed" ]; then
        print_error "hostctl: Not installed"
        MISSING_TOOLS+=("hostctl")
    elif [ "$version" = "unknown" ]; then
        print_success "hostctl: Available"
    else
        print_success "hostctl: v$version"
    fi
}

check_mkcert_tool() {
    local version
    version=$(get_command_version "mkcert")

    if [ "$version" = "not_installed" ]; then
        print_error "mkcert: Not installed"
        MISSING_TOOLS+=("mkcert")
    elif [ "$version" = "unknown" ]; then
        print_success "mkcert: Available"
    else
        print_success "mkcert: v$version"
    fi
}

check_dk_tool() {
    local current_version installed_version version_comparison

    current_version="$(get_project_version)"
    installed_version="$(get_dk_installed_version)"

    if [ "$installed_version" = "not_installed" ]; then
        print_error "dk: Not installed"
        MISSING_TOOLS+=("dk")
    else
        print_success "dk: v$installed_version"

        # Check if version is outdated
        version_comparison="$(compare_dk_versions "$installed_version" "$current_version")"
        case "$version_comparison" in
            "older")
                OUTDATED_TOOLS+=("dk:$installed_version:$current_version")
                ;;
        esac
    fi
}

# Check if all tools are in good state (no issues or suggestions)
has_no_tool_issues() {
    [ ${#OUTDATED_TOOLS[@]} -eq 0 ] && \
    [ ${#MISSING_TOOLS[@]} -eq 0 ] && \
    [ ${#UPGRADE_SUGGESTIONS[@]} -eq 0 ]
}

# Show upgrade and installation recommendations
show_upgrade_recommendations() {
    # Only show recommendations if there are issues or suggestions
    if has_no_tool_issues; then
        return "$EXIT_SUCCESS"
    fi

    echo ""
    echo -e "$(yellow 'RECOMMENDATIONS')"

    local counter=1

    # Show missing critical tools first (mkcert, hostctl, dk)
    if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
        for tool in "${MISSING_TOOLS[@]}"; do
            case "$tool" in
                hostctl)
                    echo -e " $(cyan "${counter}.") Install hostctl $(yellow '(required)')"
                    counter=$((counter + 1))
                    ;;
                mkcert)
                    echo -e " $(cyan "${counter}.") Install mkcert $(yellow '(required)')"
                    counter=$((counter + 1))
                    ;;
                dk)
                    echo -e " $(cyan "${counter}.") Install dk command: $(green 'make dk-install')"
                    counter=$((counter + 1))
                    ;;
            esac
        done
    fi

    # Show outdated tools
    if [ ${#OUTDATED_TOOLS[@]} -gt 0 ]; then
        for tool_info in "${OUTDATED_TOOLS[@]}"; do
            local tool current_version min_version
            IFS=':' read -r tool current_version min_version <<< "$tool_info"

            case "$tool" in
                bash)
                    echo -e " $(cyan "${counter}.") Update Bash: $(green "v${current_version}") → $(green "v${min_version}+")"
                    counter=$((counter + 1))
                    ;;
                make)
                    echo -e " $(cyan "${counter}.") Update Make: $(green "v${current_version}") → $(green "v${min_version}+")"
                    counter=$((counter + 1))
                    ;;
                git)
                    echo -e " $(cyan "${counter}.") Update Git: $(green "v${current_version}") → $(green "v${min_version}+")"
                    counter=$((counter + 1))
                    ;;
                dk)
                    echo -e " $(cyan "${counter}.") Update dk command: $(green "v${current_version}") → $(green "v${min_version}") $(yellow 'make dk-install')"
                    counter=$((counter + 1))
                    ;;
            esac
        done
    fi

    # Show optional upgrades
    if [ ${#UPGRADE_SUGGESTIONS[@]} -gt 0 ]; then
        for tool_info in "${UPGRADE_SUGGESTIONS[@]}"; do
            local tool current_version recommended_version
            IFS=':' read -r tool current_version recommended_version <<< "$tool_info"
            echo -e " $(cyan "${counter}.") Update $tool: $(green "v${current_version}") → $(green "v${recommended_version}+")"
            counter=$((counter + 1))
        done
    fi

    # Show missing non-critical tools
    if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
        for tool in "${MISSING_TOOLS[@]}"; do
            case "$tool" in
                homebrew)
                    echo -e " $(cyan "${counter}.") Install Homebrew"
                    counter=$((counter + 1))
                    ;;
                git)
                    echo -e " $(cyan "${counter}.") Install Git $(yellow '(required)')"
                    counter=$((counter + 1))
                    ;;
                curl)
                    echo -e " $(cyan "${counter}.") Install cURL $(yellow '(required)')"
                    counter=$((counter + 1))
                    ;;
            esac
        done
    fi
}

# Check development tools
check_development_tools() {
    print_section "Development Tools"

    check_hostctl_tool
    check_mkcert_tool
    check_dk_tool
}

# Check if critical tools are available and exit with error if missing
check_critical_tools() {
    local missing_critical=()

    # Check for critical tools
    if ! command_exists "hostctl"; then
        missing_critical+=("hostctl")
    fi

    if ! command_exists "mkcert"; then
        missing_critical+=("mkcert")
    fi

    # Exit with error if critical tools are missing
    if [ ${#missing_critical[@]} -gt 0 ]; then
        echo ""
        print_error "Critical tools missing: ${missing_critical[*]}"
        print_warning "Cannot continue without required development tools"
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    return "$EXIT_SUCCESS"
}
