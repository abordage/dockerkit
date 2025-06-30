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
# shellcheck source=lib/core/base.sh
source "$SCRIPT_DIR/lib/core/base.sh"
# shellcheck source=lib/core/colors.sh
source "$SCRIPT_DIR/lib/core/colors.sh"
# shellcheck source=lib/core/utils.sh
source "$SCRIPT_DIR/lib/core/utils.sh"
# shellcheck source=lib/core/config.sh
source "$SCRIPT_DIR/lib/core/config.sh"
# shellcheck source=lib/core/files.sh
source "$SCRIPT_DIR/lib/core/files.sh"
# shellcheck source=lib/core/docker.sh
source "$SCRIPT_DIR/lib/core/docker.sh"

# Load service libraries
# shellcheck source=lib/services/cleanup.sh
source "$SCRIPT_DIR/lib/services/cleanup.sh"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit "$EXIT_SUCCESS"
                ;;
            *)
                print_error "Unknown parameter: $1"
                show_help
                exit "$EXIT_GENERAL_ERROR"
                ;;
        esac
    done
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



# Note: All cleanup functions are now in lib/services/cleanup.sh









# Main reset function
main() {
    print_header "DOCKERKIT PROJECT RESET"

    # Load environment variables
    if [ -f "$DOCKERKIT_DIR/.env" ]; then
        # shellcheck source=/dev/null
        source "$DOCKERKIT_DIR/.env"
    fi

    print_warning "This will reset the project to initial state!"
    print_warning "Project containers, volumes, configs, and certificates will be removed."
    print_warning "Additional system-wide cleanup steps will require separate confirmation."
    echo ""

    # Confirm reset operation
    if ! confirm_action_default_yes "Do you want to continue with the reset?"; then
        print_info "Reset cancelled by user"
        exit "$EXIT_SUCCESS"
    fi

    # =================================================================
    # CORE PROJECT CLEANUP (automatic)
    # =================================================================

    # Step 1: Remove SSL certificates
    cleanup_ssl_certificates

    # Step 2: Remove nginx configurations
    cleanup_nginx_configs

    # Step 3: Remove network aliases
    cleanup_network_aliases

    # Step 4: Docker project cleanup (containers, volumes, images, networks)
    local project_name
    project_name=$(get_docker_project_name "$DOCKERKIT_DIR")
    cleanup_docker_project "$project_name"

    # =================================================================
    # OPTIONAL CLEANUP (with confirmations)
    # =================================================================

    # Step 5: Clean dangling Docker images system-wide (optional, default: Yes)
    cleanup_dangling_images

    # Step 6: Clean unused Docker images system-wide (optional, default: No)
    cleanup_unused_images

    # Step 7: Clean Docker build cache system-wide (optional, default: No)
    cleanup_docker_cache

    # Summary
    print_header "RESET COMPLETED SUCCESSFULLY!"
    print_section "Next steps:"
    echo -e "  $(cyan '1.') Run setup: $(green 'make setup')"
    echo -e "  $(cyan '2.') Start containers: $(green 'make start')"
    echo ""
}

# Script entry point
parse_arguments "$@"
main
