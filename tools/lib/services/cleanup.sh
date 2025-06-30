#!/bin/bash

# =============================================================================
# CLEANUP SERVICE MODULE
# =============================================================================
# Comprehensive cleanup operations for DockerKit project reset and maintenance
#
# Features:
# • Project-specific Docker resource cleanup (containers, volumes, images, networks)
# • System-wide Docker cleanup (dangling/unused images, build cache)
# • Host data cleanup (persistent volumes)
# • Configuration file cleanup (SSL certs, nginx configs, aliases)
# • Generic confirmation-based cleanup framework
#
# Usage: source this file and call cleanup functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"
# shellcheck source=../core/base.sh
source "$BASE_DIR/base.sh"

# Load dependencies
CLEANUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../core/utils.sh
source "$CLEANUP_SCRIPT_DIR/../core/utils.sh"
# shellcheck source=../core/config.sh
source "$CLEANUP_SCRIPT_DIR/../core/config.sh"
# shellcheck source=../core/docker.sh
source "$CLEANUP_SCRIPT_DIR/../core/docker.sh"

# =============================================================================
# GENERIC CLEANUP UTILITIES
# =============================================================================

# Generic optional cleanup with confirmation
optional_cleanup_with_confirmation() {
    local check_function="$1"
    local confirm_function="$2"
    local confirm_message="$3"
    local execute_function="$4"
    local section_title="$5"
    local skip_message="$6"

    # Check if cleanup is needed
    if ! "$check_function"; then
        return "$EXIT_SUCCESS"
    fi

    # Show warning and ask for confirmation
    if ! "$confirm_function" "$confirm_message"; then
        print_info "$skip_message"
        return "$EXIT_SUCCESS"
    fi

    # Execute cleanup
    print_section "$section_title"
    "$execute_function"
}

# =============================================================================
# DOCKER PROJECT CLEANUP
# =============================================================================

# Docker project cleanup (containers, volumes, images, networks)
cleanup_docker_project() {
    local project_name="$1"

    print_section "Docker cleanup"

    if ! ensure_docker_available; then
        print_warning "Docker not available, skipping Docker cleanup"
        return "$EXIT_GENERAL_ERROR"
    fi

    # Change to project directory for docker compose commands
    cd "$DOCKERKIT_DIR"

    # Stop and remove containers
    cleanup_docker_containers

    # Remove project-specific resources
    cleanup_docker_volumes "$project_name"
    cleanup_docker_images "$project_name"
    cleanup_docker_networks "$project_name"
}

# Stop and remove containers
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

# Remove project-specific Docker resources by type
cleanup_project_resources_by_type() {
    local resource_type="$1"
    local project_name="$2"
    local format="$3"
    local success_message="$4"
    local not_found_message="$5"

    local resources
    resources=$(get_docker_resources "$resource_type" "$format" --filter "label=$DOCKER_COMPOSE_PROJECT_LABEL=$project_name")

    if [ -n "$resources" ]; then
        if remove_docker_resources "$resource_type" "$resources"; then
            print_success "$success_message"
        else
            print_warning "Some $resource_type could not be removed"
        fi
    else
        print_success "$not_found_message"
    fi
}

# Remove project-specific volumes
cleanup_docker_volumes() {
    local project_name="$1"
    cleanup_project_resources_by_type "volumes" "$project_name" "$DOCKER_NAME_FORMAT" \
        "Removed project volumes" "No project volumes found"
}

# Remove project-specific images (built locally)
cleanup_docker_images() {
    local project_name="$1"
    cleanup_project_resources_by_type "images" "$project_name" "$DOCKER_ID_FORMAT" \
        "Removed project images" "No project-specific images found"
}

# Remove project networks
cleanup_docker_networks() {
    local project_name="$1"
    cleanup_project_resources_by_type "networks" "$project_name" "$DOCKER_NAME_FORMAT" \
        "Removed project networks" "No custom project networks found"
}

# =============================================================================
# DOCKER SYSTEM-WIDE CLEANUP
# =============================================================================

# Check if there are dangling images
check_dangling_images() {
    if ! ensure_docker_available; then
        return "$EXIT_GENERAL_ERROR"
    fi

    local dangling_count
    dangling_count=$(count_docker_resources "images" --filter "dangling=true")

    if [ "$dangling_count" -gt 0 ]; then
        print_warning "Found $dangling_count dangling images (unused/orphaned)"
        return "$EXIT_SUCCESS"
    fi

    return "$EXIT_GENERAL_ERROR"
}

# Execute dangling images cleanup
execute_dangling_cleanup() {
    if docker image prune -f 2>/dev/null; then
        print_success "Removed all dangling images"
    else
        print_warning "Failed to remove some dangling images"
    fi
}

# Clean dangling Docker images system-wide
cleanup_dangling_images() {
    optional_cleanup_with_confirmation \
        "check_dangling_images" \
        "confirm_action_default_yes" \
        "Do you want to remove all dangling images system-wide?" \
        "execute_dangling_cleanup" \
        "Removing dangling images" \
        "Dangling images cleanup skipped by user"
}

# Check if there are unused images
check_unused_images() {
    if ! ensure_docker_available; then
        return "$EXIT_GENERAL_ERROR"
    fi

    if has_unused_images; then
        local total_images
        total_images=$(count_docker_resources "images")
        print_warning "Found unused images among $total_images total images (tagged but not used by containers)"
        return "$EXIT_SUCCESS"
    fi

    return "$EXIT_GENERAL_ERROR"
}

# Execute unused images cleanup
execute_unused_cleanup() {
    if docker image prune -a -f 2>/dev/null; then
        print_success "Removed all unused images"
    else
        print_warning "Failed to remove some unused images"
    fi
}

# Clean unused Docker images system-wide
cleanup_unused_images() {
    optional_cleanup_with_confirmation \
        "check_unused_images" \
        "confirm_action_default_no" \
        "Do you want to remove all unused images system-wide?" \
        "execute_unused_cleanup" \
        "Removing unused images" \
        "Unused images cleanup skipped by user"
}

# Check if there is Docker build cache
check_docker_cache() {
    if ! ensure_docker_available; then
        return "$EXIT_GENERAL_ERROR"
    fi

    local cache_size
    cache_size=$(get_docker_cache_size)

    # Check if cache is empty (0B, 0, empty string, or "0 B")
    if [ -z "$cache_size" ] || [ "$cache_size" = "0B" ] || [ "$cache_size" = "0" ] || [ "$cache_size" = "0 B" ]; then
        return "$EXIT_GENERAL_ERROR"
    fi

    print_warning "Found Docker build cache: $cache_size"
    return "$EXIT_SUCCESS"
}

# Execute Docker cache cleanup
execute_cache_cleanup() {
    if docker builder prune -af >/dev/null 2>&1; then
        print_success "Removed all Docker build cache"
    else
        print_warning "Failed to remove Docker build cache"
    fi
}

# Clean Docker build cache system-wide
cleanup_docker_cache() {
    optional_cleanup_with_confirmation \
        "check_docker_cache" \
        "confirm_action_default_no" \
        "Do you want to remove all Docker build cache system-wide?" \
        "execute_cache_cleanup" \
        "Removing Docker build cache" \
        "Docker cache cleanup skipped by user"
}

# =============================================================================
# PROJECT FILE CLEANUP
# =============================================================================

# Helper: Remove files by pattern from directory
# Usage: remove_files_by_pattern "directory" "pattern" "success_msg" "not_found_msg" "dir_not_found_msg"
remove_files_by_pattern() {
    local directory="$1"
    local pattern="$2"
    local success_msg="$3"
    local not_found_msg="$4"
    local dir_not_found_msg="$5"

    if [ ! -d "$directory" ]; then
        print_info "$dir_not_found_msg"
        return "$EXIT_SUCCESS"
    fi

    # Check if files exist first
    local file_count
    file_count=$(find "$directory" -name "$pattern" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$file_count" -eq 0 ]; then
        print_info "$not_found_msg"
        return "$EXIT_SUCCESS"
    fi

    # Remove files
    if find "$directory" -name "$pattern" -delete 2>/dev/null; then
        print_success "$success_msg"
    else
        print_warning "Some files matching $pattern could not be removed"
    fi
}

# Remove SSL certificates
cleanup_ssl_certificates() {
    print_section "Removing SSL certificates"

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
        else
            print_info "No SSL certificates found"
        fi
    else
        print_info "SSL directory not found"
    fi
}

# Remove generated nginx configurations
cleanup_nginx_configs() {
    print_section "Removing generated nginx configurations"

    remove_files_by_pattern "$DOCKERKIT_DIR/nginx/conf.d" "*.local.conf" \
        "Removed generated nginx configurations" \
        "No generated nginx configurations found" \
        "Nginx conf.d directory not found"
}

# Remove network aliases file
cleanup_network_aliases() {
    print_section "Removing network aliases"

    local aliases_file="$DOCKERKIT_DIR/docker-compose.aliases.yml"

    if [ -f "$aliases_file" ]; then
        rm -f "$aliases_file"
        print_success "Removed network aliases file"
    else
        print_success "Network aliases file not found"
    fi
}
