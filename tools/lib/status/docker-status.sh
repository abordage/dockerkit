#!/bin/bash

# =============================================================================
# DOCKER ENVIRONMENT CHECKER
# =============================================================================
# Functions to check Docker environment and configuration
# Usage: source this file and call check_docker_environment
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"
# shellcheck source=../core/base.sh
source "$BASE_DIR/base.sh"

# Load dependencies
DOCKER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../core/utils.sh
source "$DOCKER_SCRIPT_DIR/../core/utils.sh"
# shellcheck source=../core/docker.sh
source "$DOCKER_SCRIPT_DIR/../core/docker.sh"

# Check and display Docker environment information
check_docker_environment() {
    print_section "Docker Environment"

    local docker_version compose_version
    docker_version=$(get_command_version "docker")
    compose_version=$(get_command_version "docker compose")

    if [ "$docker_version" = "not_installed" ]; then
        print_error "Docker: Not installed"
        return "$EXIT_MISSING_DEPENDENCY"
    else
        print_success "Docker: v$docker_version"
    fi

    if [ "$compose_version" = "not_installed" ]; then
        print_error "Docker Compose: Not installed"
    else
        print_success "Docker Compose: v$compose_version"
    fi

    check_docker_desktop
    check_docker_daemon

    # Add Docker resources check
    check_docker_resources

    # Add Docker system status check
    check_docker_system_status

    # Add Docker images check
    check_docker_images
}

# Check Docker Desktop status
check_docker_desktop() {
    ensure_docker_available || return "$EXIT_MISSING_DEPENDENCY"

    local docker_server_line
    docker_server_line=$(docker version 2>/dev/null | grep "Server: Docker Desktop" || echo "")

    if [ -n "$docker_server_line" ]; then
        local desktop_version
        desktop_version=$(echo "$docker_server_line" | sed -n 's/Server: Docker Desktop \([0-9.]*\).*/\1/p')
        print_success "Docker Desktop: v$desktop_version (running)"
    else
        local docker_context
        docker_context=$(docker context show 2>/dev/null || echo "")
        if echo "$docker_context" | grep -q "desktop"; then
            print_success "Docker Desktop: Running (version unknown)"
        else
            print_warning "Docker Desktop: Not detected"
        fi
    fi
}

# Check Docker daemon status
check_docker_daemon() {
    ensure_docker_available || return "$EXIT_MISSING_DEPENDENCY"

    if docker info >/dev/null 2>&1; then
        print_success "Docker daemon: Running"

        # Get active builder
        local active_builder
        active_builder=$(docker buildx ls 2>/dev/null | grep '\*' | head -1 | sed 's/\*/ /' | tr -s ' ' | cut -d' ' -f1 || echo "unknown")

        if [ "$active_builder" != "unknown" ] && [ -n "$active_builder" ]; then
            print_success "Active builder: $active_builder"
        else
            print_warning "Active builder: Unable to detect"
        fi

        # Check BuildKit availability
        if docker buildx version >/dev/null 2>&1; then
            print_success "BuildKit enabled: Yes"
        else
            print_warning "BuildKit enabled: No"
        fi

        # Get cache efficiency
        local cache_efficiency
        if docker system df >/dev/null 2>&1; then
            local active_cache total_cache
            active_cache=$(docker system df 2>/dev/null | grep "Build Cache" | tr -s ' ' | cut -d' ' -f3 || echo "0")
            total_cache=$(docker system df 2>/dev/null | grep "Build Cache" | tr -s ' ' | cut -d' ' -f2 || echo "0")

            if [ "$total_cache" = "0" ]; then
                cache_efficiency="None"
            elif [ "$active_cache" -gt 0 ]; then
                cache_efficiency="Active"
            else
                cache_efficiency="Available"
            fi

            print_success "Cache efficiency: $cache_efficiency"
        fi
    else
        print_error "Docker daemon: Not running"
    fi
}



# Check Docker resources allocation
check_docker_resources() {
    ensure_docker_available || return "$EXIT_MISSING_DEPENDENCY"

    print_section "Docker Resources"

        # Get CPU info from docker info
    local cpu_info memory_info
    if docker info >/dev/null 2>&1; then
        # Get CPUs (from Docker info)
        cpu_info=$(docker info 2>/dev/null | grep "CPUs:" | sed 's/^[ \t]*//' | tr -s ' ' | cut -d' ' -f2 || echo "unknown")

        # Get Memory (from Docker info)
        raw_value=$(docker info 2>/dev/null | grep "Total Memory:" | sed 's/^[ \t]*//' | tr -s ' ' | cut -d' ' -f3 | sed 's/GiB$//')
        if [ -n "$raw_value" ]; then
            memory_info=$(printf "%.1fGiB" "$raw_value" 2>/dev/null || echo "unknown")
        else
            memory_info="unknown"
        fi

        # Display results
        if [ "$cpu_info" != "unknown" ]; then
            print_success "CPU cores allocated: $cpu_info"
        else
            print_warning "CPU cores: Unable to detect"
        fi

        if [ "$memory_info" != "unknown" ]; then
            print_success "Memory allocated: $memory_info"
        else
            print_warning "Memory: Unable to detect"
        fi
    else
        print_error "Unable to get Docker resource information"
    fi
}

# Check Docker system status
check_docker_system_status() {
    ensure_docker_available || return "$EXIT_MISSING_DEPENDENCY"

    print_section "Docker System Status"

    # Get container status for the project
    local running_containers total_containers
    if docker compose ps >/dev/null 2>&1; then
        running_containers=$(docker compose ps --format "{{.State}}" 2>/dev/null | grep -c "running" || echo "0")
        total_containers=$(docker compose ps --format "{{.State}}" 2>/dev/null | grep -c -v "^$" || echo "0")

        # Ensure total_containers is a valid number
        if [[ "$total_containers" =~ ^[0-9]+$ ]] && [ "$total_containers" -gt 0 ]; then
            print_success "Containers running: $running_containers"
        else
            print_success "Containers running: 0"
        fi
    else
        print_warning "Containers: Unable to get project status"
    fi

    # Get system usage information
    if docker system df >/dev/null 2>&1; then
        # Volume usage (column 5 is SIZE)
        local volume_usage
        volume_usage=$(docker system df 2>/dev/null | grep "Local Volumes" | tr -s ' ' | cut -d' ' -f5 || echo "unknown")
        if [ "$volume_usage" != "unknown" ] && [ -n "$volume_usage" ]; then
            print_success "Volume usage: $volume_usage"
        else
            print_success "Volume usage: 0B"
        fi
    else
        print_warning "System usage: Unable to get information"
    fi

    # Get networks count
    local networks_count
    networks_count=$(docker network ls 2>/dev/null | tail -n +2 | wc -l | tr -d ' ' || echo "unknown")
    if [ "$networks_count" != "unknown" ]; then
        print_success "Networks: $networks_count"
    else
        print_warning "Networks: Unable to count"
    fi
}

# Check Docker images status
check_docker_images() {
    ensure_docker_available || return "$EXIT_MISSING_DEPENDENCY"

    print_section "Docker Images"

    # Get total images count
    local total_images
    total_images=$(docker images --format "table {{.Repository}}" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ' || echo "unknown")
    if [ "$total_images" != "unknown" ]; then
        print_success "Total images: $total_images"
    else
        print_warning "Total images: Unable to count"
    fi

    # Get total size from docker system df
    local total_size
    if docker system df >/dev/null 2>&1; then
        total_size=$(docker system df 2>/dev/null | grep "Images" | tr -s ' ' | cut -d' ' -f4 | sed 's/\([0-9.]*\)\([A-Z]*\)/\1 \2/' | xargs printf "%.1f%s" 2>/dev/null || echo "unknown")
        if [ "$total_size" != "unknown" ] && [ -n "$total_size" ]; then
            print_success "Total size: $total_size"
        else
            print_success "Total size: 0B"
        fi
    fi

    # Get dangling images count
    local dangling_images
    dangling_images=$(docker images --filter "dangling=true" --format "table {{.Repository}}" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ' || echo "unknown")
    if [ "$dangling_images" != "unknown" ]; then
        print_success "Dangling images: $dangling_images"
    else
        print_warning "Dangling images: Unable to count"
    fi

    # Get recent build time
    local recent_build
    recent_build=$(docker images --format "{{.CreatedSince}}" 2>/dev/null | head -n 1 || echo "unknown")
    if [ "$recent_build" != "unknown" ] && [ -n "$recent_build" ]; then
        print_success "Recent build: $recent_build"
    else
        print_warning "Recent build: Unable to detect"
    fi
}

