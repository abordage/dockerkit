#!/bin/bash

# =============================================================================
# NGINX GENERATOR
# =============================================================================
# Functions for generating nginx configurations from templates
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"

source "$BASE_DIR/base.sh"

# Load dependencies
NGINX_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$NGINX_SCRIPT_DIR/../core/utils.sh"
source "$NGINX_SCRIPT_DIR/../core/config.sh"
source "$NGINX_SCRIPT_DIR/projects.sh"

generate_nginx_configs() {
    local projects=("$@")

    if [ ${#projects[@]} -eq 0 ]; then
        local discovered_projects
        if ! discovered_projects=$(scan_local_projects 2>/dev/null); then
            print_warning "No projects found for nginx config generation"
            return "$EXIT_GENERAL_ERROR"
        fi

        while IFS= read -r project; do
            projects+=("$project")
        done <<< "$discovered_projects"
    fi

    local generated_count=0
    ensure_project_directory "$NGINX_SITES_DIR"

    for project in "${projects[@]}"; do
        if process_project_config "$project"; then
            ((generated_count++))
        fi
    done

    if [ $generated_count -gt 0 ]; then
        return "$EXIT_SUCCESS"
    else
        return "$EXIT_GENERAL_ERROR"
    fi
}

process_project_config() {
    local project_name="$1"
    local config_file="$DOCKERKIT_DIR/$NGINX_SITES_DIR/${project_name}.conf"

    if [ -f "$config_file" ]; then
        print_success "Configuration already exists for: $project_name"
        return "$EXIT_INVALID_USAGE"
    fi

    local project_path project_type document_root
    project_path=$(get_project_path "$project_name")
    project_type=$(detect_project_type "$project_path")
    document_root=$(get_document_root "$project_type" "$project_name")

    local template_file
    template_file=$(select_template "$project_type")

    if [ ! -f "$template_file" ]; then
        print_error "Template not found: $(basename "$template_file")"
        return "$EXIT_GENERAL_ERROR"
    fi

    if generate_from_template "$template_file" "$config_file" "$project_name" "$document_root"; then
        print_success "Configuration generated for $project_name"
        return "$EXIT_SUCCESS"
    else
        print_error "Failed to generate configuration for: $project_name"
        return "$EXIT_GENERAL_ERROR"
    fi
}

select_template() {
    local project_type="$1"
    local templates_dir="$DOCKERKIT_DIR/$NGINX_TEMPLATES_DIR"

    # Always use unified template (contains both HTTP and HTTPS server blocks)
    echo "$templates_dir/${project_type}.conf"
}

generate_from_template() {
    local template_file="$1"
    local config_file="$2"
    local site_name="$3"
    local document_root="$4"

    if [ ! -f "$template_file" ]; then
        print_error "Template not found: $template_file"
        return "$EXIT_GENERAL_ERROR"
    fi

    local ssl_cert="$DOCKERKIT_DIR/$NGINX_SSL_DIR/${site_name}.crt"
    local ssl_key="$DOCKERKIT_DIR/$NGINX_SSL_DIR/${site_name}.key"

    # Read template and replace variables
    local content
    content=$(sed -e "s|{{SITE_NAME}}|$site_name|g" \
                  -e "s|{{DOCUMENT_ROOT}}|$document_root|g" \
                  "$template_file")

    # Remove HTTPS block if SSL certificates don't exist
    if [ ! -f "$ssl_cert" ] || [ ! -f "$ssl_key" ]; then
        content=$(echo "$content" | sed '/# HTTPS_BLOCK_START/,/# HTTPS_BLOCK_END/d')
    fi

    # Write result to config file
    if echo "$content" > "$config_file"; then
        return "$EXIT_SUCCESS"
    else
        return "$EXIT_GENERAL_ERROR"
    fi
}

cleanup_nginx_configs() {
    local current_projects=("$@")
    local configs_dir="$DOCKERKIT_DIR/$NGINX_SITES_DIR"
    local removed_configs=()

    # Check if configs directory exists
    if [ ! -d "$configs_dir" ]; then
        return 0
    fi

    # Get all .localhost.conf files
    local existing_configs=()
    while IFS= read -r -d '' config_file; do
        if [[ "$(basename "$config_file")" == *.localhost.conf ]]; then
            existing_configs+=("$config_file")
        fi
    done < <(find "$configs_dir" -name "*.localhost.conf" -print0 2>/dev/null)

    # Check each configuration only if there are any
    if [ ${#existing_configs[@]} -gt 0 ]; then
        for config_file in "${existing_configs[@]}"; do
            local config_name
            config_name=$(basename "$config_file" .conf)

            # Check if project exists
            if ! project_exists_in_list "$config_name" "${current_projects[@]}"; then
                if rm "$config_file"; then
                    removed_configs+=("$config_name")
                else
                    print_error "Failed to remove: $config_name"
                fi
            fi
        done
    fi
}

project_exists_in_list() {
    local search_project="$1"
    shift
    local projects=("$@")

    for project in "${projects[@]}"; do
        if [[ "$project" == "$search_project" ]]; then
            return 0
        fi
    done
    return 1
}

