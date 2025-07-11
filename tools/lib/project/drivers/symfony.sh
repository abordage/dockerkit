#!/bin/bash

# =============================================================================
# SYMFONY PROJECT DRIVER
# =============================================================================
# Symfony project creation using Symfony CLI
# =============================================================================

# =============================================================================
# ENVIRONMENT VALIDATION
# =============================================================================

symfony_validate_environment() {
    debug_log "symfony" "Validating Symfony environment"

    # Test workspace container accessibility
    if ! workspace_exec echo "workspace test" >/dev/null 2>&1; then
        print_error "Workspace container is not accessible"
        print_tip "Start DockerKit containers first: make start"
        return "$EXIT_CONTAINER_NOT_FOUND"
    fi

    # Test Symfony CLI availability
    if ! workspace_exec symfony version >/dev/null 2>&1; then
        print_error "Symfony CLI not available in workspace"
        print_tip "Symfony CLI should be installed in the container"
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    debug_log "symfony" "Symfony environment validation successful"
    return "$EXIT_SUCCESS"
}

# =============================================================================
# PROJECT CREATION
# =============================================================================

symfony_create_project() {
    local project_name="$1"

    debug_log "symfony" "Creating Symfony project: $project_name"

    if workspace_exec bash -c "cd /var/www && symfony new --webapp '$project_name'"; then
        debug_log "symfony" "Symfony project created successfully"
        return "$EXIT_SUCCESS"
    else
        print_error "Failed to create Symfony project"
        return "$EXIT_GENERAL_ERROR"
    fi
}

# =============================================================================
# PROJECT INFORMATION
# =============================================================================

symfony_get_description() {
    echo "PHP web application framework for ambitious projects"
}

symfony_get_document_root() {
    local project_name="$1"
    echo "/var/www/${project_name}/public"
}

symfony_get_required_packages() {
    echo "symfony-cli"
}
