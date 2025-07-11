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

# Load service libraries
source "$SCRIPT_DIR/lib/services/packages.sh"
source "$SCRIPT_DIR/lib/services/ssl.sh"
source "$SCRIPT_DIR/lib/services/hosts.sh"
source "$SCRIPT_DIR/lib/services/projects.sh"
source "$SCRIPT_DIR/lib/services/nginx.sh"
source "$SCRIPT_DIR/lib/services/templates.sh"
source "$SCRIPT_DIR/lib/services/aliases.sh"
source "$SCRIPT_DIR/lib/services/git.sh"

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
    • Project detection and analysis (.local domains only)
    • Network aliases generation for Docker Compose
    • Hosts file management
    • SSL certificate generation
    • nginx configuration generation

OPTIONS:
    -h, --help          Show this help message

EXAMPLES:
    ./setup.sh                  # Full environment setup

    PROCESS:
    1. Check system dependencies (homebrew, hostctl, mkcert)
    2. Scan for .local projects in parent directory
    3. Generate Docker Compose network aliases
    4. Set up hosts file entries for discovered projects
    5. Generate SSL certificates for HTTPS support
    6. Generate nginx configurations based on project types
    7. Validate all generated configurations

REQUIREMENTS:
    • macOS: homebrew, hostctl, mkcert
    • Linux: hostctl, mkcert
    • All projects must have .local suffix in directory names

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
        print_warning "No .local projects found"
        print_tip "Create directories with .local suffix to get started"
        exit "$EXIT_SUCCESS"
    fi

    # Convert to array
    local projects_array=()
    while IFS= read -r project; do
        projects_array+=("$project")
    done <<< "$projects"

    # Step 4: Initialize SSL environment
    print_section "Initializing SSL environment"
    initialize_ssl_environment || print_warning "  ◆ Skipped step: SSL initialization"

    # Step 5: Generate SSL certificates
    print_section "Generating SSL certificates"
    generate_ssl_certificates "${projects_array[@]}" || print_warning "  ◆ Skipped step: SSL generation"

    # Step 6: Generate nginx configurations
    print_section "Generating nginx configurations"

    # Validate templates (only show if there are issues)
    if ! validate_nginx_templates; then
        print_error "Template validation failed"
        exit "$EXIT_INVALID_CONFIG"
    fi

    generate_nginx_configs "${projects_array[@]}" || true

    # Step 7: Generate network aliases
    print_section "Generating network aliases"
    setup_network_aliases "${projects_array[@]}" || print_warning "  ◆ Skipped step: Network aliases generation"

    # Step 8: Set up hosts entries
    # Request sudo privileges first with user warning
    echo ""
    print_warning "◆ Administrator password required for hosts file modification"
    if ! request_sudo; then
        print_error "Failed to obtain administrator privileges"
        exit "$EXIT_PERMISSION_DENIED"
    fi

    print_section "Setting up hosts entries"
    setup_hosts_entries "${projects_array[@]}" || print_warning "  ◆ Skipped step: Hosts setup"

    # Step 9: Show summary
    show_setup_summary "${projects_array[@]}"
}

# Show setup summary
show_setup_summary() {
    local projects=("$@")

    print_header "SETUP COMPLETED SUCCESSFULLY!"

    print_section "Available sites:"
    for project in "${projects[@]}"; do
        local ssl_cert="$DOCKERKIT_DIR/$NGINX_SSL_DIR/${project}.crt"
        if [ -f "$ssl_cert" ]; then
            print_success "https://$project"
        else
            print_success "http://$project"
        fi
    done

    print_section "Next steps:"
    echo -e "  $(cyan '1.') Review $(green '.env') configuration"
    echo -e "  $(cyan '2.') Start containers: $(green 'make start')"
    echo -e "  $(cyan '3.') View all commands: $(green 'make help')"
    echo ""
}

# Script entry point
parse_arguments "$@"
main
