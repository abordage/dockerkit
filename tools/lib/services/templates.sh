#!/bin/bash

# =============================================================================
# TEMPLATE MANAGER
# =============================================================================
# Functions for managing nginx templates and template validation
# Usage: source this file and call template management functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"

source "$BASE_DIR/base.sh"

# Load dependencies
TEMPLATE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEMPLATE_SCRIPT_DIR/../core/utils.sh"
source "$TEMPLATE_SCRIPT_DIR/../core/config.sh"
source "$TEMPLATE_SCRIPT_DIR/../core/validation.sh"

validate_nginx_templates() {
    local templates_dir="$DOCKERKIT_DIR/$NGINX_TEMPLATES_DIR"
    local missing_templates=()
    local invalid_templates=()
    local valid_count=0

    if [ ! -d "$templates_dir" ]; then
        print_error "Templates directory not found: $templates_dir"
        return "$EXIT_GENERAL_ERROR"
    fi

    # Check for required templates
    for template in "${REQUIRED_NGINX_TEMPLATES[@]}"; do
        local template_path="$templates_dir/$template"

        if [ ! -f "$template_path" ]; then
            missing_templates+=("$template")
        elif validate_template_syntax "$template_path"; then
            ((valid_count++))
        else
            invalid_templates+=("$template")
        fi
    done

    # Only show detailed output if there are errors
    if [ ${#missing_templates[@]} -gt 0 ] || [ ${#invalid_templates[@]} -gt 0 ]; then
        print_section "Template Validation Issues"

        if [ ${#missing_templates[@]} -gt 0 ]; then
            print_error "Missing templates (${#missing_templates[@]}):"
            for template in "${missing_templates[@]}"; do
                print_tip "$template"
            done
        fi

        if [ ${#invalid_templates[@]} -gt 0 ]; then
            print_error "Invalid templates (${#invalid_templates[@]}):"
            for template in "${invalid_templates[@]}"; do
                print_tip "$template"
            done
        fi

        print_warning "Some templates have issues"
        return "$EXIT_GENERAL_ERROR"
    fi

    # If all templates are valid, return success silently
    return "$EXIT_SUCCESS"
}
