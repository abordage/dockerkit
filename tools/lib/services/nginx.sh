#!/bin/bash

# =============================================================================
# NGINX GENERATOR
# =============================================================================
# Functions for generating nginx configurations from templates
# Usage: source this file and call nginx generation functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"
# shellcheck source=../core/base.sh
source "$BASE_DIR/base.sh"

# Load dependencies
NGINX_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../core/colors.sh
source "$NGINX_SCRIPT_DIR/../core/colors.sh"
# shellcheck source=../core/utils.sh
source "$NGINX_SCRIPT_DIR/../core/utils.sh"
# shellcheck source=../core/config.sh
source "$NGINX_SCRIPT_DIR/../core/config.sh"
# shellcheck source=./projects.sh
source "$NGINX_SCRIPT_DIR/projects.sh"

# Generate nginx configurations for projects
generate_nginx_configs() {
    local projects=("$@")

    if [ ${#projects[@]} -eq 0 ]; then
        # Auto-discover projects
        local discovered_projects
        if ! discovered_projects=$(scan_local_projects 2>/dev/null); then
            print_warning "No projects found for nginx config generation"
            return "$EXIT_GENERAL_ERROR"
        fi

        # Convert to array
        while IFS= read -r project; do
            projects+=("$project")
        done <<< "$discovered_projects"
    fi

    local generated_count=0

    # Ensure sites-available directory exists
    local sites_dir="$DOCKERKIT_DIR/$NGINX_SITES_DIR"
    ensure_directory "$sites_dir"

    # Process each project
    for project in "${projects[@]}"; do
        if process_project_config "$project"; then
            ((generated_count++))
        fi
    done

    # Show summary


    if [ $generated_count -gt 0 ]; then
        return "$EXIT_SUCCESS"
    else
        # Don't show warning if nothing was generated (likely all configs exist)
        return "$EXIT_GENERAL_ERROR"
    fi
}

# Process single project configuration
process_project_config() {
    local project_name="$1"
    local config_file="$DOCKERKIT_DIR/$NGINX_SITES_DIR/${project_name}.conf"

    # Skip if config already exists
    if [ -f "$config_file" ]; then
        print_success "Configuration already exists for: $project_name"
        return 2  # Special return code for skipped
    fi

    # Get project information
    local project_path project_type document_root
    project_path=$(get_project_path "$project_name")
    project_type=$(detect_project_type "$project_path")
    document_root=$(get_document_root "$project_type" "$project_name")

    # Select appropriate template
    local template_file
    template_file=$(select_template "$project_type" "$project_name")

    if [ ! -f "$template_file" ]; then
        print_error "Template not found: $(basename "$template_file")"
        return "$EXIT_GENERAL_ERROR"
    fi

    # Generate configuration

    if generate_from_template "$template_file" "$config_file" "$project_name" "$document_root"; then
        print_success "Configuration generated for: $project_name"
        return "$EXIT_SUCCESS"
    else
        print_error "Failed to generate configuration for: $project_name"
        return "$EXIT_GENERAL_ERROR"
    fi
}

# Select appropriate template based on project type and SSL availability
select_template() {
    local project_type="$1"
    local project_name="$2"
    local templates_dir="$DOCKERKIT_DIR/$NGINX_TEMPLATES_DIR"

    # Check if SSL certificates exist
    local ssl_cert="$DOCKERKIT_DIR/$NGINX_SSL_DIR/${project_name}.crt"
    local ssl_key="$DOCKERKIT_DIR/$NGINX_SSL_DIR/${project_name}.key"

    if [ -f "$ssl_cert" ] && [ -f "$ssl_key" ]; then
        # Use SSL template
        echo "$templates_dir/${project_type}-ssl.conf"
    else
        # Use non-SSL template
        echo "$templates_dir/${project_type}.conf"
    fi
}

# Generate configuration from template
generate_from_template() {
    local template_file="$1"
    local config_file="$2"
    local site_name="$3"
    local document_root="$4"

    if [ ! -f "$template_file" ]; then
        print_error "Template not found: $template_file"
        return "$EXIT_GENERAL_ERROR"
    fi

    # Replace placeholders in template
    if sed -e "s|{{SITE_NAME}}|$site_name|g" \
           -e "s|{{DOCUMENT_ROOT}}|$document_root|g" \
           "$template_file" > "$config_file"; then
        print_success "Generated config for: $site_name"
        return "$EXIT_SUCCESS"
    else
        print_error "Failed to generate config for: $site_name"
        return "$EXIT_GENERAL_ERROR"
    fi
}


