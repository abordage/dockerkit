#!/bin/bash

# =============================================================================
# LARAVEL PROJECT DRIVER
# =============================================================================
# Laravel project creation using Laravel installer
# =============================================================================

# =============================================================================
# CONSTANTS
# =============================================================================

readonly LARAVEL_INSTALLER_PACKAGE="laravel/installer"

# =============================================================================
# ENVIRONMENT VALIDATION
# =============================================================================

laravel_validate_environment() {
    debug_log "laravel" "Validating Laravel environment"

    # Test workspace container accessibility
    if ! workspace_exec echo "workspace test" >/dev/null 2>&1; then
        print_error "Workspace container is not accessible"
        print_tip "Start DockerKit containers first: make start"
        return "$EXIT_CONTAINER_NOT_FOUND"
    fi

    # Test Laravel installer availability
    if ! workspace_exec laravel --version >/dev/null 2>&1; then
        print_error "Laravel installer not available in workspace"
        print_tip "Laravel installer should be installed globally via composer"
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    debug_log "laravel" "Laravel environment validation successful"
    return "$EXIT_SUCCESS"
}

# =============================================================================
# PROJECT CREATION
# =============================================================================

laravel_create_project() {
    local project_name="$1"

    debug_log "laravel" "Creating Laravel project: $project_name"

    if workspace_exec bash -c "cd /var/www && laravel new '$project_name'"; then
        debug_log "laravel" "Laravel project created successfully"
        return "$EXIT_SUCCESS"
    else
        print_error "Failed to create Laravel project"
        return "$EXIT_GENERAL_ERROR"
    fi
}

# =============================================================================
# PROJECT INFORMATION
# =============================================================================

laravel_get_description() {
    echo "PHP web application framework for artisans"
}

laravel_get_document_root() {
    local project_name="$1"
    echo "/var/www/${project_name}/public"
}

laravel_get_required_packages() {
    echo "$LARAVEL_INSTALLER_PACKAGE"
}
