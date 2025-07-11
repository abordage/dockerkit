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
    return 0
fi
readonly DOCKERKIT_BASE_LOADED="true"

# =============================================================================
# STANDARD EXIT CODES
# =============================================================================
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_INVALID_USAGE=2
readonly EXIT_INVALID_CONFIG=3
readonly EXIT_INVALID_ARGS=4
readonly EXIT_MISSING_COMMAND=5
readonly EXIT_MISSING_DEPS=6
readonly EXIT_PERMISSION_DENIED=7
readonly EXIT_FILE_NOT_FOUND=8
readonly EXIT_TIMEOUT=9
readonly EXIT_CONNECTION_ERROR=10
readonly EXIT_CONTAINER_NOT_FOUND=11
readonly EXIT_CONTAINER_NOT_RUNNING=12
readonly EXIT_INVALID_INPUT=13
readonly EXIT_MISSING_DEPENDENCY=14
readonly EXIT_CONFIGURATION_ERROR=15
readonly EXIT_USER_CANCEL=16
readonly EXIT_INVALID_ARGUMENT=17

# Export exit codes for use in other modules
export EXIT_SUCCESS EXIT_GENERAL_ERROR EXIT_INVALID_USAGE EXIT_INVALID_CONFIG
export EXIT_INVALID_ARGS EXIT_MISSING_COMMAND EXIT_MISSING_DEPS EXIT_PERMISSION_DENIED
export EXIT_FILE_NOT_FOUND EXIT_TIMEOUT EXIT_CONNECTION_ERROR EXIT_CONTAINER_NOT_FOUND
export EXIT_CONTAINER_NOT_RUNNING EXIT_INVALID_INPUT EXIT_MISSING_DEPENDENCY
export EXIT_CONFIGURATION_ERROR EXIT_USER_CANCEL EXIT_INVALID_ARGUMENT
