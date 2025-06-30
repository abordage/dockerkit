#!/bin/bash

# =============================================================================
# CROSS-PLATFORM COMPATIBILITY MODULE
# =============================================================================
# Unified functions for cross-platform operations (macOS, Linux, WSL2)
# =============================================================================

set -euo pipefail

# Prevent multiple inclusion
if [[ "${DOCKERKIT_PLATFORM_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly DOCKERKIT_PLATFORM_LOADED="true"

# Load base utilities
PLATFORM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./utils.sh
source "$PLATFORM_SCRIPT_DIR/utils.sh"

# =============================================================================
# SYSTEM INFORMATION FUNCTIONS
# =============================================================================

# Get CPU information in a cross-platform way
get_cpu_info() {
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        macos)
            if command_exists "sysctl"; then
                local cpu_brand cores
                cpu_brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")
                cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "unknown")
                if [ "$cpu_brand" != "unknown" ] && [ "$cores" != "unknown" ]; then
                    print_success "CPU: $cpu_brand ($cores cores)"
                else
                    print_error "CPU: Unable to detect"
                fi
            else
                print_error "CPU: Unable to detect"
            fi
            ;;
        linux|wsl2)
            if [ -f "/proc/cpuinfo" ]; then
                local cpu_model cores
                cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//' 2>/dev/null || echo "unknown")
                cores=$(nproc 2>/dev/null || grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "unknown")
                if [ "$cpu_model" != "unknown" ] && [ "$cores" != "unknown" ]; then
                    print_success "CPU: $cpu_model ($cores cores)"
                else
                    print_error "CPU: Unable to detect"
                fi
            else
                print_error "CPU: Unable to detect"
            fi
            ;;
        *)
            print_error "CPU: Unsupported platform"
            ;;
    esac
}

# Get memory information in a cross-platform way
get_memory_info() {
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        macos)
            if command_exists "sysctl"; then
                local total_bytes total_gb
                total_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")

                if [ "$total_bytes" != "0" ]; then
                    total_gb=$((total_bytes / 1024 / 1024 / 1024))
                    print_success "Memory: ${total_gb}GB total"
                else
                    print_warning "Memory: Unable to detect total"
                fi

                if command_exists "vm_stat"; then
                    local memory_pressure
                    memory_pressure=$(vm_stat 2>/dev/null | grep "Pages free:" | tr -s ' ' | cut -d' ' -f3 | sed 's/\.//' || echo "unknown")

                    if [ "$memory_pressure" != "unknown" ] && [ "$memory_pressure" -gt 0 ]; then
                        local free_mb=$((memory_pressure * 4 / 1024))
                        print_success "Memory: ${free_mb}MB free"
                    fi
                fi
            else
                print_warning "Memory: Unable to detect (sysctl not available)"
            fi
            ;;
        linux|wsl2)
            if [ -f "/proc/meminfo" ]; then
                local total_kb available_kb total_gb available_gb
                total_kb=$(grep "MemTotal:" /proc/meminfo | tr -s ' ' | cut -d' ' -f2 2>/dev/null || echo "0")
                available_kb=$(grep "MemAvailable:" /proc/meminfo | tr -s ' ' | cut -d' ' -f2 2>/dev/null || echo "0")

                if [ "$total_kb" != "0" ]; then
                    total_gb=$((total_kb / 1024 / 1024))
                    print_success "Memory: ${total_gb}GB total"
                fi

                if [ "$available_kb" != "0" ]; then
                    available_gb=$((available_kb / 1024 / 1024))
                    print_success "Memory: ${available_gb}GB available"
                fi

                if [ "$total_kb" = "0" ] && [ "$available_kb" = "0" ]; then
                    print_warning "Memory: Unable to parse /proc/meminfo"
                fi
            else
                print_warning "Memory: Unable to detect (/proc/meminfo not available)"
            fi
            ;;
        *)
            print_warning "Memory: Unsupported platform"
            ;;
    esac
}

# Get disk information in a cross-platform way
get_disk_info() {
    local os_type
    os_type=$(detect_os)

    if command_exists "df"; then
        local disk_info
        disk_info=$(df -h / 2>/dev/null | tail -1)

        if [ -n "$disk_info" ]; then
            case "$os_type" in
                macos)
                    local total_disk free_disk
                    total_disk=$(echo "$disk_info" | tr -s ' ' | cut -d' ' -f2 | sed 's/Gi$/GB/' || echo "unknown")
                    free_disk=$(echo "$disk_info" | tr -s ' ' | cut -d' ' -f4 | sed 's/Gi$/GB/' || echo "unknown")

                    if [ "$total_disk" != "unknown" ] && [ "$free_disk" != "unknown" ]; then
                        local free_num total_num free_percent
                        free_num=${free_disk%GB}
                        total_num=${total_disk%GB}

                        if [ "$total_num" != "0" ]; then
                            free_percent=$(( free_num * 100 / total_num ))
                            print_success "Disk space: ${free_disk} free / ${total_disk} total (${free_percent}% free)"
                        else
                            print_success "Disk space: ${free_disk} free / ${total_disk} total"
                        fi
                    else
                        print_warning "Disk space: Unable to parse disk information"
                    fi
                    ;;
                linux|wsl2)
                    local total_disk free_disk used_percent
                    total_disk=$(echo "$disk_info" | tr -s ' ' | cut -d' ' -f2 || echo "unknown")
                    free_disk=$(echo "$disk_info" | tr -s ' ' | cut -d' ' -f4 || echo "unknown")
                    used_percent=$(echo "$disk_info" | tr -s ' ' | cut -d' ' -f5 | sed 's/%//' || echo "unknown")

                    if [ "$total_disk" != "unknown" ] && [ "$free_disk" != "unknown" ]; then
                        if [ "$used_percent" != "unknown" ]; then
                            local free_percent=$((100 - used_percent))
                            print_success "Disk space: ${free_disk} free / ${total_disk} total (${free_percent}% free)"
                        else
                            print_success "Disk space: ${free_disk} free / ${total_disk} total"
                        fi
                    else
                        print_warning "Disk space: Unable to parse disk information"
                    fi
                    ;;
                *)
                    print_warning "Disk space: Unsupported platform for parsing"
                    ;;
            esac
        else
            print_warning "Disk space: Unable to get disk information"
        fi
    else
        print_warning "Disk space: Unable to detect (df not available)"
    fi
}

# =============================================================================
# PERFORMANCE MONITORING FUNCTIONS
# =============================================================================

# Get system load average in a cross-platform way
get_load_average() {
    local os_type result
    os_type=$(detect_os)

    case "$os_type" in
        macos)
            result=$(uptime 2>/dev/null | grep -o 'load averages: [0-9.]* [0-9.]* [0-9.]*' | sed 's/load averages: //')
            ;;
        linux|wsl2)
            if [ -f "/proc/loadavg" ]; then
                result=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)
            else
                result=$(uptime 2>/dev/null | grep -o 'load average: [0-9.]*, [0-9.]*, [0-9.]*' | sed 's/load average: //')
            fi
            ;;
        *)
            result=""
            ;;
    esac

    get_platform_info "Load average" "$result (1m, 5m, 15m)"
}

# Get CPU usage in a cross-platform way
get_cpu_usage() {
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        macos)
            if command_exists "top"; then
                local cpu_usage
                cpu_usage=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage:" | head -1)

                if [ -n "$cpu_usage" ]; then
                    # Extract idle percentage and calculate busy
                    local idle_cpu
                    idle_cpu=$(echo "$cpu_usage" | grep -o '[0-9.]*% idle' | grep -o '[0-9.]*' || echo "0")

                    if [ "${idle_cpu%%.*}" -gt 0 ]; then
                        local busy_cpu=$((100 - ${idle_cpu%%.*}))
                        print_success "CPU usage: ${busy_cpu}% busy, ${idle_cpu}% idle"
                    else
                        local user_cpu sys_cpu
                        user_cpu=$(echo "$cpu_usage" | grep -o '[0-9.]*% user' | grep -o '[0-9.]*' || echo "0")
                        sys_cpu=$(echo "$cpu_usage" | grep -o '[0-9.]*% sys' | grep -o '[0-9.]*' || echo "0")
                        print_success "CPU usage: ${user_cpu}% user, ${sys_cpu}% sys, ${idle_cpu}% idle"
                    fi
                else
                    print_warning "CPU usage: Unable to get from top"
                fi
            else
                print_warning "CPU usage: Unable to detect (top not available)"
            fi
            ;;
        linux|wsl2|*)
            # TODO: Implement accurate CPU usage monitoring for Linux
            # Current /proc/stat approach has issues with incomplete calculations
            # Consider using: iostat, sar, or proper /proc/stat parsing with all fields
            print_warning "CPU usage: TODO - Implement accurate CPU monitoring for Linux"
            ;;
    esac
}

# Get process information in a cross-platform way
get_process_info() {
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        macos)
            if command_exists "top"; then
                local process_info
                process_info=$(top -l 1 -n 0 2>/dev/null | grep "Processes:" | head -1)

                if [ -n "$process_info" ]; then
                    local total_proc running_proc sleeping_proc
                    total_proc=$(echo "$process_info" | grep -o '[0-9]* total' | grep -o '[0-9]*' || echo "unknown")
                    running_proc=$(echo "$process_info" | grep -o '[0-9]* running' | grep -o '[0-9]*' || echo "unknown")
                    sleeping_proc=$(echo "$process_info" | grep -o '[0-9]* sleeping' | grep -o '[0-9]*' || echo "unknown")

                    if [ "$total_proc" != "unknown" ]; then
                        if [ "$running_proc" != "unknown" ] && [ "$sleeping_proc" != "unknown" ]; then
                            print_success "Processes: $total_proc total ($running_proc running, $sleeping_proc sleeping)"
                        else
                            print_success "Processes: $total_proc total"
                        fi
                    else
                        print_warning "Processes: Unable to count"
                    fi
                else
                    print_warning "Processes: Unable to get from top"
                fi
            else
                print_warning "Processes: Unable to detect (top not available)"
            fi
            ;;
        linux|wsl2|*)
            # TODO: Implement efficient process monitoring for Linux
            # Current find+exec approach is extremely slow on systems with many processes
            # Consider using: ps aux, /proc/loadavg, or optimized /proc parsing
            print_warning "Processes: TODO - Implement efficient process monitoring for Linux"
            ;;
    esac
}

# Get network statistics in a cross-platform way
get_network_stats() {
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        macos)
            if command_exists "top"; then
                local network_info
                network_info=$(top -l 1 -n 0 2>/dev/null | grep "Networks:" | head -1)

                if [ -n "$network_info" ]; then
                    local packets_in packets_out
                    packets_in=$(echo "$network_info" | grep -o '[0-9.]*[MGK]*G* in' | sed 's/ in$//' || echo "unknown")
                    packets_out=$(echo "$network_info" | grep -o '[0-9.]*[MGK]*G* out' | sed 's/ out$//' || echo "unknown")

                    if [ "$packets_in" != "unknown" ] && [ "$packets_out" != "unknown" ]; then
                        print_success "Network: ${packets_in} in, ${packets_out} out"
                    else
                        print_warning "Network: Unable to parse statistics"
                    fi
                else
                    print_warning "Network: Unable to get statistics"
                fi
            else
                print_warning "Network: Unable to detect (top not available)"
            fi
            ;;
        linux|wsl2|*)
            # TODO: Implement efficient network monitoring for Linux
            # Current /proc/net/dev parsing with subshells is overcomplicated
            # Consider using: ss, netstat, iftop, or simple awk-based /proc/net/dev parsing
            print_warning "Network: TODO - Implement efficient network monitoring for Linux"
            ;;
    esac
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Format bytes into human readable format
format_bytes() {
    local bytes="$1"

    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes}B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$((bytes / 1024))KB"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$((bytes / 1024 / 1024))MB"
    else
        echo "$((bytes / 1024 / 1024 / 1024))GB"
    fi
}

# Get system uptime in a cross-platform way
get_uptime() {
    local result
    result=$(uptime 2>/dev/null | sed 's/.*up *//; s/, *load.*//' | sed 's/, *[0-9]* users*//')

    get_platform_info "Uptime" "$result"
}

# =============================================================================
# PLATFORM HELPER FUNCTIONS
# =============================================================================

# Execute platform-specific command and return result
# Usage: run_platform_command "macos_cmd" "linux_cmd" "fallback_msg"
run_platform_command() {
    local macos_cmd="$1"
    local linux_cmd="$2"
    local fallback_msg="${3:-Unable to detect}"
    local os_type

    os_type=$(detect_os)

    case "$os_type" in
        macos)
            eval "$macos_cmd" 2>/dev/null || echo "$fallback_msg"
            ;;
        linux|wsl2)
            eval "$linux_cmd" 2>/dev/null || echo "$fallback_msg"
            ;;
        *)
            echo "$fallback_msg"
            ;;
    esac
}

# Get platform-specific information with error handling
# Usage: get_platform_info "description" "success_result" "error_result"
get_platform_info() {
    local description="$1"
    local result="$2"
    local error_fallback="${3:-Unable to detect}"

    if [ -n "$result" ] && [ "$result" != "$error_fallback" ] && [ "$result" != "unknown" ]; then
        print_success "$description: $result"
    else
        print_warning "$description: $error_fallback"
    fi
}

# =============================================================================
# PLATFORM DETECTION AND SYSTEM INFORMATION
# =============================================================================
