#!/bin/bash

# =============================================================================
# DOCKERKIT PROJECT CREATOR
# =============================================================================
# Interactive project creation tool for Laravel, Symfony and other frameworks
# =============================================================================

set -euo pipefail

# =============================================================================
# BOOTSTRAP
# =============================================================================

# Get script directory and load bootstrap
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/project/bootstrap.sh"

# =============================================================================
# CONSTANTS
# =============================================================================

readonly SCRIPT_NAME="DockerKit Project Creator"
readonly SCRIPT_VERSION="1.0.0"

# =============================================================================
# HELP FUNCTIONS
# =============================================================================

show_help() {
    cat << EOF
${SCRIPT_NAME} v${SCRIPT_VERSION}

Interactive project creation tool for development frameworks.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help      Show this help message
    -V, --version   Show version information
    -v, --verbose   Enable verbose output

EXAMPLES:
    $0                          # Interactive mode - choose type and enter name
    make project                # Same as above via Makefile

SUPPORTED PROJECT TYPES:
$(get_supported_project_types | sed 's/^/    /')

EOF
}

show_version() {
    echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit "$EXIT_SUCCESS"
                ;;
            -V|--version)
                show_version
                exit "$EXIT_SUCCESS"
                ;;
            -v|--verbose)
                export DEBUG_MODE=true
                shift
                ;;
            *)
                print_error "Unknown argument: $1"
                print_tip "Use --help for usage information"
                exit "$EXIT_INVALID_ARGUMENT"
                ;;
        esac
    done

    # Initialize bootstrap
    if ! project_bootstrap; then
        exit "$EXIT_CONFIGURATION_ERROR"
    fi

    debug_log "main" "Running interactive project workflow"
    interactive_project_workflow

    local exit_code=$?
    debug_log "main" "Workflow completed with exit code: $exit_code"

    return $exit_code
}

# =============================================================================
# ENTRY POINT
# =============================================================================

# Ignore additional arguments passed by Make for argument handling
export MAKEFLAGS=""

# Run main function with all arguments
main "$@"
