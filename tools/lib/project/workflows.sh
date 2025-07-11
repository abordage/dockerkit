#!/bin/bash

# =============================================================================
# PROJECT CREATION WORKFLOWS
# =============================================================================
# Main business logic for project creation operations
# =============================================================================

# =============================================================================
# UNIVERSAL PROJECT WORKFLOW
# =============================================================================

project_workflow() {
    local project_type="$1"
    local project_name="$2"
    local driver_name

    if ! driver_name=$(get_project_driver "$project_type"); then
        print_error "No driver found for project type: $project_type"
        return "$EXIT_CONFIGURATION_ERROR"
    fi

    debug_log "workflow" "Using driver: $driver_name for type: $project_type"

    local validate_function="${driver_name}_validate_environment"
    if ! "$validate_function"; then
        print_error "Environment validation failed for $project_type"
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    local create_function="${driver_name}_create_project"
    if ! "$create_function" "$project_name"; then
        print_error "Project creation failed"
        return "$EXIT_GENERAL_ERROR"
    fi

    return "$EXIT_SUCCESS"
}

# =============================================================================
# FULL INTERACTIVE WORKFLOW
# =============================================================================

interactive_project_workflow() {
    local project_type
    local project_name

    print_header "NEW PROJECT"

    if ! project_type=$(select_project_type) || [ -z "$project_type" ]; then
        print_error "No project type selected"
        return "$EXIT_USER_CANCEL"
    fi

    debug_log "workflow" "Selected project type: $project_type"

    # Step 2: Input project name
    if ! project_name=$(input_project_name_safe) || [ -z "$project_name" ]; then
        print_error "No project name provided"
        return "$EXIT_USER_CANCEL"
    fi

    debug_log "workflow" "Project name: $project_name"

    # Step 3: Create project
    if ! project_workflow "$project_type" "$project_name"; then
        return "$EXIT_GENERAL_ERROR"
    fi

    # Step 4: Setup development environment
    setup_development_environment "$project_name"

    return "$EXIT_SUCCESS"
}

# =============================================================================
# POST-CREATION SETUP
# =============================================================================

setup_development_environment() {
    local project_name="$1"

    # Ask about running setup first
    ask_setup_execution "$project_name"
}

# Ask user about setup execution
ask_setup_execution() {
    local project_name="$1"
    local setup_executed=false

    if confirm "Run setup to configure the new project?" "y"; then
        if "${DOCKERKIT_DIR}/tools/setup.sh"; then
            setup_executed=true
        else
            print_error "Setup execution failed"
        fi
    fi

    # Always show success message after setup (or after declining setup)
    print_section "Project Created Successfully!"
    print_success "Location: /var/www/$project_name"
    print_success "URL: https://${project_name}"

    # Show next steps only if setup was not executed
    if [ "$setup_executed" = "false" ]; then
        show_project_next_steps
    fi
}

# Show next steps for project creation
show_project_next_steps() {
    print_section "Next steps:"
    local step_num=1

    echo -e " $(cyan "${step_num}.") Configure environment: $(green 'make setup')"
    ((step_num++))
    echo -e " $(cyan "${step_num}.") Open the project directory in your IDE to start development"
}
