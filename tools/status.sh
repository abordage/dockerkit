#!/bin/bash

# =============================================================================
# SYSTEM DIAGNOSTICS SCRIPT
# =============================================================================
# Main script for running comprehensive system diagnostics
# Usage: ./system-diagnostics.sh
# =============================================================================

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
DOCKERKIT_DIR="$(dirname "$SCRIPT_DIR")"
readonly DOCKERKIT_DIR

# Export DOCKERKIT_DIR for use in modules
export DOCKERKIT_DIR

# Change to project root directory
cd "$DOCKERKIT_DIR"

# Load the main diagnostics module
# shellcheck source=./lib/status/system-status.sh
source "$SCRIPT_DIR/lib/status/system-status.sh"

# Main execution
main() {
    # Run system diagnostics
    run_system_diagnostics
}

# Execute main function
main "$@"
