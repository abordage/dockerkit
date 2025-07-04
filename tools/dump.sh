#!/bin/bash

# =============================================================================
# DOCKERKIT DATABASE DUMP MANAGER
# =============================================================================
# Database backup and restore operations for DockerKit containers
# Usage: ./dump
# =============================================================================

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export DOCKERKIT_DIR

# Load core DockerKit libraries
source "$SCRIPT_DIR/lib/core/base.sh"
source "$SCRIPT_DIR/lib/core/colors.sh"
source "$SCRIPT_DIR/lib/core/utils.sh"
source "$SCRIPT_DIR/lib/core/validation.sh"

# Load dump-specific libraries
source "$SCRIPT_DIR/lib/dump/bootstrap.sh"

# Parse command line arguments
parse_arguments() {
    parse_standard_arguments "show_help" "$@"
}

# Show help
show_help() {
    cat << EOF
DockerKit Database Dump Manager

USAGE:
    ./dump [OPTIONS]

DESCRIPTION:
    Interactive database backup and restore operations for DockerKit containers.
    Supports MySQL and PostgreSQL with automatic Docker container detection.

OPTIONS:
    -h, --help          Show this help message

FEATURES:
    • Two-step workflow: Database type → Operation
    • Export: Create database dumps with optional compression
    • Import: Restore from existing dump files
    • Automatic timestamp generation with UTC timezone
    • Docker container integration (no system clients required)
    • File validation and error handling

EXAMPLES:
    ./dump                      # Interactive mode with menu selection

REQUIREMENTS:
    • DockerKit containers must be running
    • Database containers: dockerkit-mysql-1, dockerkit-postgres-1
    • Workspace container: dockerkit-workspace-1 (with DB clients)

EOF
}

# Main function
main() {
    print_header "DOCKERKIT DATABASE DUMP MANAGER"

    # Initialize dump environment
    initialize_dump_environment

    # Start interactive workflow
    run_interactive_workflow
}

# Script entry point
parse_arguments "$@"
main
