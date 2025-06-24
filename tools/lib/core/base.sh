#!/bin/bash
# =============================================================================
# BASE CONSTANTS AND FUNCTIONS
# =============================================================================
# Essential constants and basic functions used across all modules
# Usage: source this file before other modules to access shared functionality
# =============================================================================

set -euo pipefail

# Prevent multiple inclusion
if [[ "${DOCKERKIT_BASE_LOADED:-}" == "true" ]]; then
    return "$EXIT_SUCCESS"
fi
readonly DOCKERKIT_BASE_LOADED="true"

# =============================================================================
# STANDARD EXIT CODES
# =============================================================================
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_MISSING_DEPENDENCY=2
readonly EXIT_INVALID_CONFIG=3
readonly EXIT_PERMISSION_DENIED=4

# Export exit codes for use in other modules
export EXIT_SUCCESS EXIT_GENERAL_ERROR EXIT_MISSING_DEPENDENCY EXIT_INVALID_CONFIG EXIT_PERMISSION_DENIED
