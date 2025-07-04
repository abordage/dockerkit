#!/bin/bash

# =============================================================================
# CLEANUP SERVICE MODULE
# =============================================================================
# Comprehensive cleanup operations for DockerKit project reset and maintenance
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"

source "$BASE_DIR/base.sh"

# Load dependencies
CLEANUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$CLEANUP_SCRIPT_DIR/../core/utils.sh"
source "$CLEANUP_SCRIPT_DIR/../core/config.sh"
source "$CLEANUP_SCRIPT_DIR/../core/docker.sh"

# =============================================================================
# DOCKER PROJECT CLEANUP
# =============================================================================

remove_docker_project() {
    local project_name="$1"

    if ! ensure_docker_available; then
        print_warning "Docker not available, skipping Docker cleanup"
        return "$EXIT_GENERAL_ERROR"
    fi

    cd "$DOCKERKIT_DIR"

    cleanup_docker_containers
    cleanup_docker_volumes "$project_name"
    cleanup_docker_images "$project_name"
    cleanup_docker_networks "$project_name"
}

cleanup_docker_containers() {
    if docker compose down --remove-orphans 2>/dev/null; then
        print_success "Stopped and removed containers"
    else
        print_warning "Failed to stop containers (may not be running)"
    fi
}

# =============================================================================
# GENERALIZED PROJECT RESOURCE CLEANUP
# =============================================================================

cleanup_project_resources_by_type() {
    local resource_type="$1"
    local project_name="$2"
    local format="$3"
    local success_message="$4"

    local resources
    resources=$(get_docker_resources "$resource_type" "$format" --filter "label=$DOCKER_COMPOSE_PROJECT_LABEL=$project_name")

    if [ -n "$resources" ]; then
        if remove_docker_resources "$resource_type" "$resources"; then
            print_success "$success_message"
        else
            print_warning "Some $resource_type could not be removed"
        fi
    fi
}

cleanup_docker_volumes() {
    local project_name="$1"
    cleanup_project_resources_by_type "volumes" "$project_name" "$DOCKER_NAME_FORMAT" "Removed project volumes"
}

cleanup_docker_images() {
    local project_name="$1"
    cleanup_project_resources_by_type "images" "$project_name" "$DOCKER_ID_FORMAT" "Removed project images"
}

cleanup_docker_networks() {
    local project_name="$1"
    cleanup_project_resources_by_type "networks" "$project_name" "$DOCKER_NAME_FORMAT" "Removed project networks"
}

# =============================================================================
# DOCKER SYSTEM-WIDE CLEANUP
# =============================================================================

remove_dangling_images() {
    if docker image prune -f 2>/dev/null; then
        print_success "Removed all dangling images"
    else
        print_warning "Failed to remove some dangling images"
    fi
}

remove_unused_images() {
    if docker image prune -a -f 2>/dev/null; then
        print_success "Removed all unused images"
    else
        print_warning "Failed to remove some unused images"
    fi
}

remove_docker_cache() {
    if docker builder prune -af >/dev/null 2>&1; then
        print_success "Removed all Docker build cache"
    else
        print_warning "Failed to remove Docker build cache"
    fi
}

# =============================================================================
# PROJECT FILE CLEANUP
# =============================================================================

remove_files_by_pattern() {
    local directory="$1"
    local pattern="$2"
    local success_msg="$3"

    if [ ! -d "$directory" ]; then
        return "$EXIT_SUCCESS"
    fi

    # Check if files exist first
    local file_count
    file_count=$(find "$directory" -name "$pattern" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$file_count" -eq 0 ]; then
        return "$EXIT_SUCCESS"
    fi

    # Remove files
    if find "$directory" -name "$pattern" -delete 2>/dev/null; then
        print_success "$success_msg"
    fi
}

remove_ssl_certificates() {
    local ssl_dir="$DOCKERKIT_DIR/nginx/ssl"
    local removed=false

    if [ -d "$ssl_dir" ]; then
        # Remove certificate files
        if find "$ssl_dir" -name "*.crt" -delete 2>/dev/null; then
            removed=true
        fi
        if find "$ssl_dir" -name "*.key" -delete 2>/dev/null; then
            removed=true
        fi

        if $removed; then
            print_success "Removed SSL certificates"
        fi
    fi
}

remove_nginx_configs() {
    remove_files_by_pattern "$DOCKERKIT_DIR/nginx/conf.d" "*.local.conf" "Removed generated nginx configurations"
}

remove_network_aliases() {
    local aliases_file="$DOCKERKIT_DIR/docker-compose.aliases.yml"

    if [ -f "$aliases_file" ]; then
        rm -f "$aliases_file"
        print_success "Removed network aliases file"
    fi
}
