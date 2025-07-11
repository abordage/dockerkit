#!/bin/bash

# =============================================================================
# PROJECT CREATOR BOOTSTRAP
# =============================================================================
# Bootstrap script that loads all required modules and initializes the system
# =============================================================================

# =============================================================================
# SCRIPT DIRECTORY DETECTION
# =============================================================================

PROJECT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOCKERKIT_DIR="$(cd "$PROJECT_SCRIPT_DIR/../../.." && pwd)"
readonly DOCKERKIT_DIR

export DOCKERKIT_DIR

# =============================================================================
# CORE LIBRARIES
# =============================================================================

source "${PROJECT_SCRIPT_DIR}/../core/base.sh"
source "${PROJECT_SCRIPT_DIR}/../core/colors.sh"
source "${PROJECT_SCRIPT_DIR}/../core/config.sh"
source "${PROJECT_SCRIPT_DIR}/../core/docker.sh"
source "${PROJECT_SCRIPT_DIR}/../core/files.sh"
source "${PROJECT_SCRIPT_DIR}/../core/input.sh"
source "${PROJECT_SCRIPT_DIR}/../core/math.sh"
source "${PROJECT_SCRIPT_DIR}/../core/platform.sh"
source "${PROJECT_SCRIPT_DIR}/../core/utils.sh"
source "${PROJECT_SCRIPT_DIR}/../core/validation.sh"

# =============================================================================
# PROJECT-SPECIFIC MODULES
# =============================================================================

source "${PROJECT_SCRIPT_DIR}/registry.sh"
source "${PROJECT_SCRIPT_DIR}/ui.sh"
source "${PROJECT_SCRIPT_DIR}/workflows.sh"

# =============================================================================
# DRIVER MODULES
# =============================================================================

source "${PROJECT_SCRIPT_DIR}/drivers/laravel.sh"
source "${PROJECT_SCRIPT_DIR}/drivers/symfony.sh"

# =============================================================================
# INITIALIZATION
# =============================================================================

project_bootstrap() {
    if [ ! -d "$DOCKERKIT_DIR" ]; then
        print_error "DockerKit directory not found: $DOCKERKIT_DIR"
        print_tip "Make sure you're running this script from DockerKit root directory"
        return "$EXIT_CONFIGURATION_ERROR"
    fi

    debug_log "project" "Bootstrap initialization completed"
    return "$EXIT_SUCCESS"
}
