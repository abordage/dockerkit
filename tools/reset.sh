#!/bin/bash

# =============================================================================
# DOCKERKIT PROJECT RESET
# =============================================================================
# Reset project to initial state (clean containers, volumes, configs)
# Usage: ./reset.sh
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
    • Logs directory contents
    • Network aliases file

OPTIONS:
    -h, --help          Show this help message

EXAMPLES:
    ./reset.sh                              # Full project reset

WARNING:
    This operation will remove all project data and cannot be undone!

EOF
}

# Docker cleanup
cleanup_docker() {
    print_section "Docker cleanup"

    # Check if docker compose is available
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not found, skipping Docker cleanup"
        return 0
    fi

    # Change to project directory for docker compose commands
    cd "$DOCKERKIT_DIR"

    if docker compose down --rmi local --volumes --remove-orphans 2>/dev/null; then
        print_success "Docker cleanup completed"
    else
        print_warning "Docker cleanup had some issues (this is usually normal)"
    fi
}

# Remove SSL certificates
cleanup_ssl_certificates() {
    print_section "Removing SSL certificates"

    local ssl_dir="$DOCKERKIT_DIR/nginx/ssl"
    local removed=false

    if [ -d "$ssl_dir" ]; then
        # Remove certificate files
        if find "$ssl_dir" -name "*.crt" -delete 2>/dev/null; then
            removed=true
        fi
        if find "$ssl_dir" -name "*.key" -delete 2>/dev/null; then
            removed=true
        fi

        if $removed; then
            print_success "Removed SSL certificates"
        else
            print_info "No SSL certificates found"
        fi
    else
        print_info "SSL directory not found"
    fi
}

# Remove generated nginx configurations
cleanup_nginx_configs() {
    print_section "Removing generated nginx configurations"

    local nginx_conf_dir="$DOCKERKIT_DIR/nginx/conf.d"
    local removed=false

    if [ -d "$nginx_conf_dir" ]; then
        # Remove .local.conf files
        if find "$nginx_conf_dir" -name "*.local.conf" -delete 2>/dev/null; then
            removed=true
        fi

        if $removed; then
            print_success "Removed generated nginx configurations"
        else
            print_info "No generated nginx configurations found"
        fi
    else
        print_info "Nginx conf.d directory not found"
    fi
}

# Remove network aliases file
cleanup_network_aliases() {
    print_section "Removing network aliases"

    local aliases_file="$DOCKERKIT_DIR/docker-compose.aliases.yml"

    if [ -f "$aliases_file" ]; then
        rm -f "$aliases_file"
        print_success "Removed network aliases file"
    else
        print_success "Network aliases file not found"
    fi
}

# Main reset function
main() {
    print_header "DOCKERKIT PROJECT RESET"

    print_warning "This will reset the project to initial state!"
    print_warning "All containers, volumes, and configuration files will be removed."
    echo ""

    # Confirm reset operation
    if ! confirm_action "Do you want to continue with the reset?"; then
        print_info "Reset cancelled by user"
        exit "$EXIT_SUCCESS"
    fi

    echo ""

    # Step 1: Docker cleanup
    cleanup_docker

    # Step 2: Remove configuration files
    # remove step

    # Step 3: Clean directories
    clean_logs_directory

    # Step 4: Remove SSL certificates
    cleanup_ssl_certificates

    # Step 5: Remove generated nginx configurations
    cleanup_nginx_configs

    # Step 6: Remove network aliases
    cleanup_network_aliases

    # Summary
    print_header "RESET COMPLETED SUCCESSFULLY!"
    print_section "Next steps:"
    echo -e "  ${CYAN}1.${NC} Run setup: ${GREEN}make setup${NC}"
    echo -e "  ${CYAN}2.${NC} Start containers: ${GREEN}make start${NC}"
    echo ""
}

# Script entry point
parse_arguments "$@"
main
