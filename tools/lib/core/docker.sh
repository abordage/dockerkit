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
    return "$EXIT_SUCCESS"
fi

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/base.sh"

# Ensure colors are loaded
if [ -z "${RED:-}" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

readonly DOCKERKIT_DOCKER_LOADED="true"

readonly DOCKER_COMPOSE_PROJECT_LABEL="com.docker.compose.project"
readonly DOCKER_COMPOSE_SERVICE_LABEL="com.docker.compose.service"

readonly DOCKER_NAME_FORMAT="{{.Name}}"
readonly DOCKER_ID_FORMAT="{{.ID}}"
readonly DOCKER_SIZE_FORMAT="{{.Size}}"
export DOCKER_COMPOSE_PROJECT_LABEL DOCKER_COMPOSE_SERVICE_LABEL
export DOCKER_NAME_FORMAT DOCKER_ID_FORMAT DOCKER_SIZE_FORMAT

# =============================================================================
# DOCKER AVAILABILITY AND PROJECT INFO
# =============================================================================

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

get_docker_project_name() {
    local project_dir="${1:-$DOCKERKIT_DIR}"

    if [ -n "${COMPOSE_PROJECT_NAME:-}" ]; then
        echo "$COMPOSE_PROJECT_NAME"
        return "$EXIT_SUCCESS"
    fi

    basename "$project_dir"
}

has_docker_desktop() {
    if command -v docker >/dev/null 2>&1; then
        docker info >/dev/null 2>&1
        return "$EXIT_SUCCESS"
    fi
    return "$EXIT_GENERAL_ERROR"
}

# =============================================================================
# DOCKER RESOURCE OPERATIONS
# =============================================================================

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

_execute_docker_command() {
    local resource_type="$1"
    local format="$2"  # empty string or format string
    shift 2
    local filter_args=("$@")

    local cmd_array
    read -ra cmd_array <<< "$(_get_docker_command "$resource_type")" || return "$EXIT_GENERAL_ERROR"

    if [ -n "$format" ]; then
        cmd_array+=(--format "$format")
    fi

    if [ ${#filter_args[@]} -gt 0 ]; then
        cmd_array+=("${filter_args[@]}")
    fi

    "${cmd_array[@]}" 2>/dev/null || echo ""
}

count_docker_resources() {
    local resource_type="$1"
    shift
    local filter_args=("$@")

    if [ ${#filter_args[@]} -gt 0 ]; then
        _execute_docker_command "$resource_type" "" "${filter_args[@]}" | wc -l | tr -d ' '
    else
        _execute_docker_command "$resource_type" "" | wc -l | tr -d ' '
    fi
}

get_docker_resources() {
    local resource_type="$1"
    local format="$2"
    shift 2
    local filter_args=("$@")

    if [ ${#filter_args[@]} -gt 0 ]; then
        _execute_docker_command "$resource_type" "$format" "${filter_args[@]}"
    else
        _execute_docker_command "$resource_type" "$format"
    fi
}

remove_docker_resources() {
    local resource_type="$1"
    local resource_ids="$2"

    if [ -z "$resource_ids" ]; then
        return "$EXIT_SUCCESS"
    fi

    # Show formatted output for each removed resource
    echo "$resource_ids" | while IFS= read -r resource_id; do
        if [ -n "$resource_id" ]; then
            print_success "$resource_id"
        fi
    done

    case "$resource_type" in
        containers)
            echo "$resource_ids" | xargs docker container rm -f >/dev/null 2>&1
            ;;
        volumes)
            echo "$resource_ids" | xargs docker volume rm >/dev/null 2>&1
            ;;
        images)
            echo "$resource_ids" | xargs docker rmi -f >/dev/null 2>&1
            ;;
        networks)
            echo "$resource_ids" | xargs docker network rm >/dev/null 2>&1
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

get_docker_cache_size() {
    if ! ensure_docker_available; then
        echo "0B"
        return "$EXIT_GENERAL_ERROR"
    fi

    local cache_size
    cache_size=$(docker system df --format "table {{.Type}}\t{{.Size}}" 2>/dev/null | grep "Build Cache" | sed 's/.*[[:space:]]\([^[:space:]]*\)$/\1/' || echo "")

    echo "${cache_size:-0B}"
}

has_unused_images() {
    if ! ensure_docker_available; then
        return "$EXIT_GENERAL_ERROR"
    fi

    local non_dangling_count
    non_dangling_count=$(docker images --filter "dangling=false" -q 2>/dev/null | wc -l | tr -d ' ')

    if [ "${non_dangling_count:-0}" -gt 3 ]; then
        return "$EXIT_SUCCESS"
    fi

    return "$EXIT_GENERAL_ERROR"
}
