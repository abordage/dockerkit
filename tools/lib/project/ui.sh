#!/bin/bash

# =============================================================================
# USER INTERFACE COMPONENTS
# =============================================================================
# Interactive menu and input functions for project creation operations
# =============================================================================

# Load universal input system
UI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${UI_SCRIPT_DIR}/../core/input.sh"

# =============================================================================
# WORKFLOW FUNCTIONS
# =============================================================================

# Step 1: Select project type
select_project_type() {
    local project_types=()
    local project_type

    while IFS= read -r project_type; do
        project_types+=("$project_type")
    done < <(get_supported_project_types)

    input_menu "Select project type:" "${project_types[@]}"
}

# Step 2: Input project name (safe version with host validation)
input_project_name_safe() {
    local project_name

    while true; do
        echo >&2
        printf '%b' "$(yellow "Enter project name (must end with .localhost): ")" >&2
        read -r project_name

        # 1. Check if empty
        if [ -z "$project_name" ]; then
            echo " ✗ Project name cannot be empty" >&2
            continue
        fi

        # 2. Check valid characters (letters, numbers, hyphens, underscores, dots)
        if [[ ! "$project_name" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
            echo " ✗ Invalid characters. Use only letters, numbers, hyphens, underscores, and dots" >&2
            continue
        fi

        # 3. Check starts with letter or number
        if [[ ! "$project_name" =~ ^[a-zA-Z0-9] ]]; then
            echo " ✗ Project name must start with a letter or number" >&2
            continue
        fi

        # 4. Check ends with .localhost
        if [[ ! "$project_name" =~ \.localhost$ ]]; then
            echo " ✗ Project name must end with '.localhost'" >&2
            continue
        fi

        # 5. Check directory doesn't exist on host
        if validate_project_directory_host "$project_name"; then
            echo "$project_name"
            return 0
        fi
        # If validation failed, continue loop
    done
}

# Step 2: Input project name (legacy version - kept for compatibility)
input_project_name() {
    local project_name

    while true; do
        echo >&2
        printf '%b' "$(yellow "Enter project name (must end with .localhost): ")" >&2
        read -r project_name

        if validate_project_name "$project_name"; then
            echo "$project_name"
            return 0
        else
            print_error "Invalid project name: $project_name"
            print_tip "Project name must end with '.localhost' and use only letters, numbers, hyphens and underscores"
        fi
    done
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_project_directory_host() {
    local project_name="$1"
    local projects_dir="${PROJECTS_DIR:-$(dirname "$DOCKERKIT_DIR")}"
    local project_path="$projects_dir/${project_name}"

    if [ -d "$project_path" ]; then
        echo " ✗ Project directory already exists: ${project_name}" >&2
        echo " ↳ Choose a different name or remove the existing project" >&2
        return 1
    fi

    return 0
}

validate_project_name() {
    local project_name="$1"

    # Check if name is not empty
    if [ -z "$project_name" ]; then
        return 1
    fi

    # Check if name ends with .localhost
    if [[ ! "$project_name" =~ \.localhost$ ]]; then
        print_error "Project name must end with '.localhost'"
        return 1
    fi

    # Check for valid characters (letters, numbers, hyphens, underscores, dots)
    if [[ ! "$project_name" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        print_error "Project name contains invalid characters"
        return 1
    fi

    # Check if project directory already exists
    local projects_dir="${PROJECTS_DIR:-$(dirname "$DOCKERKIT_DIR")}"
    local project_path="$projects_dir/${project_name}"

    if [ -d "$project_path" ]; then
        print_error "Project directory already exists: ${project_name}"
        return 1
    fi

    return 0
}
