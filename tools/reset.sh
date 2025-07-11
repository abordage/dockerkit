#!/bin/bash

# =============================================================================
# DOCKERKIT PROJECT RESET
# =============================================================================
# Reset project to initial state with comprehensive cleanup options
#
# Features:
# • Full project cleanup (containers, volumes, configs, certificates)
# • Optional persistent data removal with confirmation
# • Optional system-wide Docker cleanup (dangling/unused images, cache)
# • Modular architecture with cleanup functions from services/cleanup.sh
#
# Usage: ./reset.sh [OPTIONS]
# =============================================================================

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export DOCKERKIT_DIR

# Load core libraries
source "$SCRIPT_DIR/lib/core/base.sh"
source "$SCRIPT_DIR/lib/core/colors.sh"
source "$SCRIPT_DIR/lib/core/utils.sh"
source "$SCRIPT_DIR/lib/core/config.sh"
source "$SCRIPT_DIR/lib/core/files.sh"
source "$SCRIPT_DIR/lib/core/docker.sh"
source "$SCRIPT_DIR/lib/core/input.sh"

# Load service libraries
source "$SCRIPT_DIR/lib/services/cleanup.sh"

# Parse command line arguments using universal function
parse_arguments() {
    parse_standard_arguments "show_help" "$@"
}

# Show help
show_help() {
    cat << EOF
DockerKit Project Reset

USAGE:
    ./reset.sh [OPTIONS]

DESCRIPTION:
    Reset project to initial state by cleaning:
    • Docker containers, images, volumes and networks
    • Configuration files created from examples
    • Generated SSL certificates and nginx configs
    • Network aliases file
    • Persistent data (optional, with confirmation)
    • System-wide dangling Docker images (optional)
    • System-wide unused Docker images (optional)
    • System-wide Docker build cache (optional)

OPTIONS:
    -h, --help          Show this help message

EXAMPLES:
    ./reset.sh                              # Full project reset

WARNING:
    This operation will remove all project data and cannot be undone!
    Persistent data removal is optional and requires separate confirmation.
    System-wide Docker cleanup affects all Docker projects on your machine.

EOF
}


# Main reset function
main() {
    print_header "DOCKERKIT PROJECT RESET"

    # Load environment variables
    if [ -f "$DOCKERKIT_DIR/.env" ]; then
                source "$DOCKERKIT_DIR/.env"
    fi

    print_warning "This will reset the project to initial state!"
    print "Project containers, volumes, configs, and certificates will be removed."
    print "Additional system-wide cleanup steps will require separate confirmation."

    # Confirm reset operation
    if ! input_yesno "Do you want to continue with the reset?" "y"; then
        print_tip "Reset cancelled by user"
        exit "$EXIT_SUCCESS"
    fi

    # =================================================================
    # PLANNING: CHECK WHAT CAN BE CLEANED
    # =================================================================

    local cleanup_dangling=false
    local cleanup_unused=false
    local cleanup_cache=false

    # Check for dangling images
    if ensure_docker_available; then
        local dangling_count
        dangling_count=$(count_docker_resources "images" --filter "dangling=true")
        if [ "$dangling_count" -gt 0 ]; then
            print_warning "Found $dangling_count dangling images (unused/orphaned)"
            if input_yesno "Do you want to remove all dangling images system-wide?" "y"; then
                cleanup_dangling=true
            fi
        fi

        # Check for unused images
        if has_unused_images; then
            #local total_images
            # total_images=$(count_docker_resources "images")
            # print "Found unused images among $total_images total images (tagged but not used by containers)"
            if input_yesno "Do you want to remove all unused images system-wide?" "n"; then
                cleanup_unused=true
            fi
        fi

        # Check for Docker cache
        local cache_size
        cache_size=$(get_docker_cache_size)
        if [ -n "$cache_size" ] && [ "$cache_size" != "0B" ] && [ "$cache_size" != "0" ] && [ "$cache_size" != "0 B" ]; then
            # print "Found Docker build cache: $cache_size"
            if input_yesno "Do you want to remove all Docker build cache system-wide?" "n"; then
                cleanup_cache=true
            fi
        fi
    fi

    # =================================================================
    # EXECUTION: PERFORM CLEANUP WITHOUT QUESTIONS
    # =================================================================

    # Core project cleanup
    print_section "Removing SSL certificates"
    remove_ssl_certificates

    print_section "Removing nginx configurations"
    remove_nginx_configs

    print_section "Removing network aliases"
    remove_network_aliases

    print_section "Docker cleanup"
    local project_name
    project_name=$(get_docker_project_name "$DOCKERKIT_DIR")
    remove_docker_project "$project_name"

    # Optional system-wide cleanup
    if [ "$cleanup_dangling" = true ]; then
        print_section "Removing dangling images"
        remove_dangling_images
    fi

    if [ "$cleanup_unused" = true ]; then
        print_section "Removing unused images"
        remove_unused_images
    fi

    if [ "$cleanup_cache" = true ]; then
        print_section "Removing Docker build cache"
        remove_docker_cache
    fi

    # Summary
    print_header "RESET COMPLETED SUCCESSFULLY!"
    print_section "Next steps:"
    local step_num=1
    echo -e " $(cyan "${step_num}.") Run setup: $(green 'make setup')"
    ((step_num++))
    echo -e " $(cyan "${step_num}.") Start containers: $(green 'make start')"
    echo ""
}

# Script entry point
parse_arguments "$@"
main
