#!/bin/bash

# =============================================================================
# DOCKER UTILITIES MODULE
# =============================================================================
# Common Docker operations and utilities used across DockerKit scripts
#
# Features:
# • Docker availability checks and project name resolution
# • Resource listing, counting, and removal operations
# • System information (cache size, unused images detection)
# • Label-based filtering for Docker Compose projects
#
# Usage: source this file to access Docker utility functions
# =============================================================================

set -euo pipefail

# Prevent multiple inclusion
if [[ "${DOCKERKIT_DOCKER_LOADED:-}" == "true" ]]; then
    return 0
fi

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./base.sh
source "$BASE_DIR/base.sh"

# Ensure colors are loaded
if [ -z "${RED:-}" ]; then
    # shellcheck source=./colors.sh
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

readonly DOCKERKIT_DOCKER_LOADED="true"

# Docker label constants
readonly DOCKER_COMPOSE_PROJECT_LABEL="com.docker.compose.project"
readonly DOCKER_COMPOSE_SERVICE_LABEL="com.docker.compose.service"

# Docker format constants
readonly DOCKER_NAME_FORMAT="{{.Name}}"
readonly DOCKER_ID_FORMAT="{{.ID}}"
readonly DOCKER_SIZE_FORMAT="{{.Size}}"

# Export constants for use in other modules
export DOCKER_COMPOSE_PROJECT_LABEL DOCKER_COMPOSE_SERVICE_LABEL
export DOCKER_NAME_FORMAT DOCKER_ID_FORMAT DOCKER_SIZE_FORMAT

# =============================================================================
# DOCKER AVAILABILITY AND PROJECT INFO
# =============================================================================

# Check if Docker is available and running
ensure_docker_available() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        return "$EXIT_GENERAL_ERROR"
    fi

    return "$EXIT_SUCCESS"
}

# Get Docker Compose project name
get_docker_project_name() {
    local project_dir="${1:-$DOCKERKIT_DIR}"

    # Try environment variable first
    if [ -n "${COMPOSE_PROJECT_NAME:-}" ]; then
        echo "$COMPOSE_PROJECT_NAME"
        return "$EXIT_SUCCESS"
    fi

    # Fall back to directory basename
    basename "$project_dir"
}

# =============================================================================
# DOCKER RESOURCE OPERATIONS
# =============================================================================

# Internal: Get Docker command for resource type
_get_docker_command() {
    local resource_type="$1"

    case "$resource_type" in
        containers) echo "docker container ls -aq" ;;
        volumes)    echo "docker volume ls -q" ;;
        images)     echo "docker images -q" ;;
        networks)   echo "docker network ls -q" ;;
        *)
            print_error "Unsupported resource type: $resource_type"
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# Internal: Execute Docker command with optional format and filters
_execute_docker_command() {
    local resource_type="$1"
    local format="$2"  # empty string or format string
    shift 2
    local filter_args=("$@")

    # Build command array to avoid eval issues
    local cmd_array
    read -ra cmd_array <<< "$(_get_docker_command "$resource_type")" || return "$EXIT_GENERAL_ERROR"

    # Add format if provided
    if [ -n "$format" ]; then
        cmd_array+=(--format "$format")
    fi

    # Add filters
    cmd_array+=("${filter_args[@]+"${filter_args[@]}"}")

    # Execute command
    "${cmd_array[@]}" 2>/dev/null || echo ""
}

# Count Docker resources by filter
count_docker_resources() {
    local resource_type="$1"
    shift
    local filter_args=("$@")

    _execute_docker_command "$resource_type" "" "${filter_args[@]}" | wc -l | tr -d ' '
}

# Get Docker resources by filter
get_docker_resources() {
    local resource_type="$1"
    local format="$2"
    shift 2
    local filter_args=("$@")

    _execute_docker_command "$resource_type" "$format" "${filter_args[@]}"
}

# Remove Docker resources by IDs
remove_docker_resources() {
    local resource_type="$1"
    local resource_ids="$2"

    if [ -z "$resource_ids" ]; then
        return "$EXIT_SUCCESS"
    fi

    case "$resource_type" in
        containers)
            echo "$resource_ids" | xargs docker container rm -f 2>/dev/null
            ;;
        volumes)
            echo "$resource_ids" | xargs docker volume rm 2>/dev/null
            ;;
        images)
            echo "$resource_ids" | xargs docker rmi -f 2>/dev/null
            ;;
        networks)
            echo "$resource_ids" | xargs docker network rm 2>/dev/null
            ;;
        *)
            print_error "Unsupported resource type: $resource_type"
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# =============================================================================
# DOCKER SYSTEM INFORMATION
# =============================================================================

# Get Docker build cache size
get_docker_cache_size() {
    if ! ensure_docker_available; then
        echo "0B"
        return "$EXIT_GENERAL_ERROR"
    fi

    local cache_size
    cache_size=$(docker system df --format "table {{.Type}}\t{{.Size}}" 2>/dev/null | grep "Build Cache" | tr -s ' ' | cut -f2 || echo "")

    echo "${cache_size:-0B}"
}

# Check if there are unused images (non-dangling but not used by containers)
has_unused_images() {
    if ! ensure_docker_available; then
        return "$EXIT_GENERAL_ERROR"
    fi

    # Use docker system prune dry-run equivalent
    # Count non-dangling images
    local non_dangling_count
    non_dangling_count=$(docker images --filter "dangling=false" -q 2>/dev/null | wc -l | tr -d ' ')

    # If we have more than a few basic images, likely has unused ones
    if [ "${non_dangling_count:-0}" -gt 3 ]; then
        return "$EXIT_SUCCESS"  # Likely has unused images
    fi

    return "$EXIT_GENERAL_ERROR"  # Probably no unused images
}
