#!/bin/bash

# =============================================================================
# PROJECT DETECTOR
# =============================================================================
# Functions for detecting project types and scanning project directories
# Usage: source this file and call project detection functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"
# shellcheck source=../core/base.sh
source "$BASE_DIR/base.sh"

# Load dependencies
DETECTOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../core/colors.sh
source "$DETECTOR_SCRIPT_DIR/../core/colors.sh"
# shellcheck source=../core/utils.sh
source "$DETECTOR_SCRIPT_DIR/../core/utils.sh"
# shellcheck source=../core/config.sh
source "$DETECTOR_SCRIPT_DIR/../core/config.sh"
# shellcheck source=../core/validation.sh
source "$DETECTOR_SCRIPT_DIR/../core/validation.sh"

# Scan for local projects in projects directory
scan_local_projects() {
    local projects_dir="${PROJECTS_DIR:-$(dirname "$DOCKERKIT_DIR")}"
    local projects=()

    if [ ! -d "$projects_dir" ]; then
        print_warning "Projects directory not found: $projects_dir"
        return "$EXIT_INVALID_CONFIG"
    fi

    # Look for directories with .local suffix
    for dir in "$projects_dir"/*.local; do
        if [ -d "$dir" ]; then
            local project_name
            project_name=$(basename "$dir")
            projects+=("$project_name")
        fi
    done

    if [ ${#projects[@]} -eq 0 ]; then
        print_info "No .local projects found in $projects_dir"
        return "$EXIT_GENERAL_ERROR"
    fi

    printf '%s\n' "${projects[@]}"
}

# Detect project type based on files and structure
detect_project_type() {
    local project_path="$1"

    if [ ! -d "$project_path" ]; then
        echo "unknown"
        return "$EXIT_INVALID_CONFIG"
    fi

    # Laravel detection - artisan file is the key indicator
    if [ -f "$project_path/artisan" ] && [ -f "$project_path/composer.json" ]; then
        # Double-check it's Laravel by looking for Laravel-specific files
        if grep -q "laravel/framework" "$project_path/composer.json" 2>/dev/null; then
            echo "laravel"
            return "$EXIT_SUCCESS"
        fi
    fi

    # Symfony detection - multiple indicators
    if [ -f "$project_path/bin/console" ] && [ -f "$project_path/composer.json" ]; then
        if grep -q "symfony/framework-bundle\|symfony/console" "$project_path/composer.json" 2>/dev/null; then
            echo "symfony"
            return "$EXIT_SUCCESS"
        fi
    fi

    # Alternative Symfony detection
    if [ -f "$project_path/symfony.lock" ]; then
        echo "symfony"
        return "$EXIT_SUCCESS"
    fi

    # WordPress detection - multiple indicators
    if [ -f "$project_path/wp-config.php" ] || [ -f "$project_path/wp-config-sample.php" ]; then
        echo "wordpress"
        return "$EXIT_SUCCESS"
    fi

    if [ -f "$project_path/wp-content/index.php" ] || [ -f "$project_path/wp-includes/version.php" ]; then
        echo "wordpress"
        return "$EXIT_SUCCESS"
    fi

    # Static HTML detection - has index.html but no PHP
    if [ -f "$project_path/index.html" ] && [ ! -f "$project_path/index.php" ]; then
        # Check if it's really static (no server-side processing)
        if [ ! -f "$project_path/composer.json" ] && [ ! -f "$project_path/package.json" ]; then
            echo "static"
            return "$EXIT_SUCCESS"
        fi
    fi

    # Simple PHP detection - has PHP files but no framework
    if find "$project_path" -name "*.php" -type f | head -1 | grep -q "\.php$"; then
        echo "simple"
        return "$EXIT_SUCCESS"
    fi

    # Default fallback
    echo "simple"
    return "$EXIT_SUCCESS"
}

# Get document root based on project type and name
get_document_root() {
    local project_type="$1"
    local project_name="$2"

    case "$project_type" in
        laravel|symfony)
            echo "/var/www/${project_name}/public"
            ;;
        wordpress|static|simple|*)
            echo "/var/www/${project_name}"
            ;;
    esac
}

# Get project path from name
get_project_path() {
    local project_name="$1"
    local projects_dir="${PROJECTS_DIR:-$(dirname "$DOCKERKIT_DIR")}"

    echo "$projects_dir/$project_name"
}

# Validate project exists and is accessible
validate_project() {
    local project_name="$1"
    local project_path

    project_path=$(get_project_path "$project_name")

    validate_project_directory "$project_path"
    local exit_code=$?

    if [ $exit_code -eq "$EXIT_INVALID_CONFIG" ]; then
        print_error "Project directory not found: $project_path"
    elif [ $exit_code -eq "$EXIT_PERMISSION_DENIED" ]; then
        print_error "Project directory not readable: $project_path"
    fi

    return $exit_code
}
