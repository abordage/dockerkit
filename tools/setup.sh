#!/bin/bash

# =============================================================================
# DOCKERKIT ENVIRONMENT SETUP
# =============================================================================
# Complete setup of DockerKit development environment
# Usage: ./setup.sh
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
source "$SCRIPT_DIR/lib/core/validation.sh"
source "$SCRIPT_DIR/lib/core/files.sh"
source "$SCRIPT_DIR/lib/core/input.sh"

# Load service libraries
source "$SCRIPT_DIR/lib/services/packages.sh"
source "$SCRIPT_DIR/lib/services/ssl.sh"
source "$SCRIPT_DIR/lib/services/hosts.sh"
source "$SCRIPT_DIR/lib/services/projects.sh"
source "$SCRIPT_DIR/lib/services/nginx.sh"
source "$SCRIPT_DIR/lib/services/templates.sh"
source "$SCRIPT_DIR/lib/services/aliases.sh"
source "$SCRIPT_DIR/lib/services/containers.sh"

# Load system libraries
source "$SCRIPT_DIR/lib/status/tools-status.sh"

# Parse command line arguments using universal function
parse_arguments() {
    parse_standard_arguments "show_help" "$@"
}

# Show help
show_help() {
    cat << EOF
DockerKit Environment Setup

USAGE:
    ./setup.sh [OPTIONS]

    DESCRIPTION:
    Complete setup of DockerKit development environment including:
    • System dependencies check (with installation instructions)
    • Git configuration generation
    • Project detection and analysis (.localhost domains only)
    • Network aliases generation for Docker Compose
    • Hosts file management
    • SSL certificate generation
    • nginx configuration generation

OPTIONS:
    -h, --help          Show this help message

EXAMPLES:
    ./setup.sh                  # Full environment setup

    PROCESS:
    1. Check system dependencies
    2. Scan for .localhost projects in parent directory
    3. Generate Docker Compose network aliases
    4. Set up hosts file entries for discovered projects
    5. Generate SSL certificates for HTTPS support
    6. Generate nginx configurations based on project types
    7. Validate all generated configurations

EOF
}

# Main setup function
main() {
    print_header "DOCKERKIT ENVIRONMENT SETUP"

    # Step 1: Create configuration files and directories
    create_managed_files

    # Step 2: Check system dependencies
    check_system_dependencies || {
        print_error "Missing required dependencies"
        print_tip "Please install the missing dependencies and run again"
        exit "$EXIT_MISSING_DEPENDENCY"
    }

    # Step 3: Scan for projects
    local projects
    if ! projects=$(scan_local_projects 2>/dev/null); then
        print ""
        print_warning "No .localhost projects found"
        print_tip "Create directories with .localhost suffix to get started"
        exit "$EXIT_SUCCESS"
    fi

    # Convert to array
    local projects_array=()
    while IFS= read -r project; do
        projects_array+=("$project")
    done <<< "$projects"

    # Step 4: Initialize SSL environment
    print_section "Initializing SSL environment"
    initialize_ssl_environment || print_warning " ◆ Skipped step: SSL initialization"

    # Step 5: Generate SSL certificates
    print_section "Generating SSL certificates"

    cleanup_ssl_certificates "${projects_array[@]}"
    generate_ssl_certificates "${projects_array[@]}" || print_warning " ◆ Skipped step: SSL generation"

    # Step 6: Generate nginx configurations
    print_section "Generating nginx configurations"

    # Validate templates (only show if there are issues)
    if ! validate_nginx_templates; then
        print_error "Template validation failed"
        exit "$EXIT_INVALID_CONFIG"
    fi

    # Cleanup obsolete configurations
    cleanup_nginx_configs "${projects_array[@]}"
    generate_nginx_configs "${projects_array[@]}" || true

    # Step 7: Generate network aliases
    print_section "Generating network aliases"
    setup_network_aliases "${projects_array[@]}" || print_warning " ◆ Skipped step: Network aliases generation"

    # Step 8: Show summary
    show_setup_summary "${projects_array[@]}"
}

# Show setup summary
show_setup_summary() {
    local projects=("$@")

    # Ask about container restart first
    ask_container_restart "${projects[@]}"
}

# Ask user about container restart
ask_container_restart() {
    local projects=("$@")
    local containers_restarted=false

    if confirm "Restart containers to apply new configuration?" "y"; then
        if manage_containers "smart"; then
            print_success "Containers restarted successfully"
            containers_restarted=true
            # Show available sites after successful restart
            show_available_sites "${projects[@]}"
        else
            print_error "Failed to restart containers"
            exit "$EXIT_GENERAL_ERROR"
        fi
    fi

    # Always show next steps, but conditionally show restart instruction
    show_next_steps "$containers_restarted"
}

# Show available sites
show_available_sites() {
    local projects=("$@")

    print_section "Available sites"
    for project in "${projects[@]}"; do
        local ssl_cert="$DOCKERKIT_DIR/$NGINX_SSL_DIR/${project}.crt"
        if [ -f "$ssl_cert" ]; then
            print_success "https://$project"
        else
            print_success "http://$project"
        fi
    done
}

# Show next steps
show_next_steps() {
    local containers_restarted="${1:-false}"
    local step_num=1

    print_section "Next steps:"
    echo -e " $(cyan "${step_num}.") Review $(green '.env') configuration"
    ((step_num++))

    # Show restart instruction only if containers were not restarted
    if [ "$containers_restarted" = "false" ]; then
        echo -e " $(cyan "${step_num}.") Restart containers: $(green 'make restart')"
        ((step_num++))
    fi

    echo -e " $(cyan "${step_num}.") View all commands: $(green 'make help')"
}

# Script entry point
parse_arguments "$@"
main
