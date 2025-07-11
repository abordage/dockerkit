#!/bin/bash

# =============================================================================
# CONTAINER MANAGER
# =============================================================================
# Functions for managing Docker containers in DockerKit
# Usage: source this file and call container management functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"

source "$BASE_DIR/base.sh"

# Load dependencies
CONTAINERS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$CONTAINERS_SCRIPT_DIR/../core/utils.sh"
source "$CONTAINERS_SCRIPT_DIR/../core/config.sh"
source "$CONTAINERS_SCRIPT_DIR/../core/docker.sh"

# =============================================================================
# CONTAINER MANAGEMENT FUNCTIONS
# =============================================================================

manage_containers() {
    local action="${1:-smart}"  # smart, start, restart, stop

    # Ensure Docker is available
    if ! ensure_docker_available; then
        print_error "Docker is not available"
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    # Load environment variables
    load_env_variables

    # Determine action based on container state
    if [ "$action" = "smart" ]; then
        if containers_are_running; then
            action="restart"
        else
            action="start"
        fi
    fi

    # Execute Docker Compose command
    execute_docker_compose "$action"
}

containers_are_running() {
    local running_count
    running_count=$(docker compose ps --format "{{.State}}" 2>/dev/null | grep -c "running" || echo "0")
    [ "$running_count" -gt 0 ]
}

load_env_variables() {
    if [ -f ".env" ]; then
        source .env
    else
        print_error "No .env file found"
        return "$EXIT_INVALID_CONFIG"
    fi

    if [ -z "${ENABLE_SERVICES:-}" ]; then
        print_error "ENABLE_SERVICES variable not found in .env"
        return "$EXIT_INVALID_CONFIG"
    fi
}

execute_docker_compose() {
    local action="$1"
    local compose_files="-f docker-compose.yml"

    # Add aliases file if it exists
    if [ -f "docker-compose.aliases.yml" ]; then
        compose_files="$compose_files -f docker-compose.aliases.yml"
    fi

    case "$action" in
        start)
            if ! docker compose $compose_files up -d $ENABLE_SERVICES; then
                print_error "Failed to start containers"
                return "$EXIT_GENERAL_ERROR"
            fi
            ;;
        restart)
            if ! docker compose $compose_files restart $ENABLE_SERVICES; then
                print_error "Failed to restart containers"
                return "$EXIT_GENERAL_ERROR"
            fi
            ;;
        stop)
            if ! docker compose $compose_files stop $ENABLE_SERVICES; then
                print_error "Failed to stop containers"
                return "$EXIT_GENERAL_ERROR"
            fi
            ;;
        *)
            print_error "Unknown action: $action"
            return "$EXIT_INVALID_INPUT"
            ;;
    esac
}
