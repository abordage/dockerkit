#!/bin/bash

# =============================================================================
# SYSTEM DIAGNOSTICS
# =============================================================================
# Main system diagnostics functions and orchestration
# Usage: source this file and call run_system_diagnostics
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"
# shellcheck source=../core/base.sh
source "$BASE_DIR/base.sh"

# Load dependencies
LIB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../core/colors.sh
source "$LIB_SCRIPT_DIR/../core/colors.sh"
# shellcheck source=../core/utils.sh
source "$LIB_SCRIPT_DIR/../core/utils.sh"
# shellcheck source=../core/config.sh
source "$LIB_SCRIPT_DIR/../core/config.sh"
# shellcheck source=./tools-status.sh
source "$LIB_SCRIPT_DIR/tools-status.sh"
# shellcheck source=./docker-status.sh
source "$LIB_SCRIPT_DIR/docker-status.sh"
# shellcheck source=./site-status.sh
source "$LIB_SCRIPT_DIR/site-status.sh"

# Get total memory in GB
get_total_memory_gb() {
    if command_exists "sysctl"; then
        local mem_bytes
        mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
        if [ -n "$mem_bytes" ] && [ "$mem_bytes" -gt 0 ]; then
            if command -v bc >/dev/null 2>&1; then
                echo "scale=1; $mem_bytes / 1024 / 1024 / 1024" | bc 2>/dev/null
            else
                echo "scale=1; $mem_bytes / 1024 / 1024 / 1024" | bc
            fi
            return
        fi
    fi
    echo "unknown"
}

# Get memory information
get_memory_info() {
    local total_mem used_mem
    total_mem=$(get_total_memory_gb)

    if [ "$total_mem" = "unknown" ]; then
        print_warning "Memory: Unable to detect total memory"
        return
    fi

    # Get used memory from top
    if command_exists "top"; then
        local mem_info
        mem_info=$(top -l 1 -n 0 2>/dev/null | grep "PhysMem:" | head -1)
        if [ -n "$mem_info" ]; then
            # Extract used memory from PhysMem line
            # Format: "PhysMem: 23G used (3477M wired, 9703M compressor), 110M unused."
            used_mem=$(echo "$mem_info" | grep -o '[0-9.]*G used' | grep -o '[0-9.]*' || echo "unknown")

            if [ "$used_mem" != "unknown" ]; then
                print_success "Total memory: ${total_mem}GB"

                # Calculate percentage (convert total_mem to integer for division)
                local total_mem_int="${total_mem%.*}"
                if [ "${used_mem%%.*}" -gt 0 ] && [ "$total_mem_int" -gt 0 ]; then
                    local percentage
                    percentage=$(echo "scale=0; ${used_mem} * 100 / ${total_mem}" | bc 2>/dev/null || echo "0")
                    print_success "Memory usage: ${used_mem}GB (${percentage}%)"
                else
                    print_success "Memory usage: ${used_mem}GB"
                fi
            else
                print_success "Total memory: ${total_mem}GB"
                print_warning "Memory usage: Unable to parse"
            fi
        else
            print_success "Total memory: ${total_mem}GB"
            print_warning "Memory usage: Unable to get information from top"
        fi
    else
        print_success "Total memory: ${total_mem}GB"
        print_warning "Memory usage: Unable to detect (top not available)"
    fi
}

# Main diagnostics function
run_system_diagnostics() {
    print_header "SYSTEM DIAGNOSTICS"

    show_operating_system
    show_system_resources
    show_system_performance
    check_docker_environment
    check_system_tools
    check_development_tools

    # Check critical tools and exit if missing
    if ! check_critical_tools; then
        echo ""
        return "$EXIT_GENERAL_ERROR"
    fi

    validate_project_configuration
    check_site_status

    # Show upgrade recommendations after main diagnostics
    show_upgrade_recommendations

    echo ""
}

# Show operating system information
show_operating_system() {
    print_section "Operating System"

    local os_name arch
    os_name=$(uname -s)
    arch=$(uname -m)

    print_success "System: $os_name $(uname -r)"
    print_success "Architecture: $arch"

    if command_exists "sw_vers"; then
        local macos_version
        macos_version=$(sw_vers -productVersion)
        print_success "macOS version: $macos_version"
    fi
}

# Validate project configuration
validate_project_configuration() {
    print_section "Project Configuration"

    show_project_info
    check_env_file
    check_makefile_config
    check_nginx_templates
    check_ssl_certificates
}

# Show project information
show_project_info() {
    if [ -f ".env" ]; then
        # shellcheck source=/dev/null
        source .env
    else
        print_warning "No .env file found"
    fi
}

# Check .env file
check_env_file() {
    if [ ! -f ".env" ]; then
        print_error ".env file missing"
        return "$EXIT_GENERAL_ERROR"
    fi

    # Check .env syntax and content
    local syntax_errors=0
    local missing_vars=()
    local empty_vars=()

    # Check syntax - valid KEY=VALUE format
    if ! grep -E "^[A-Z_][A-Z0-9_]*=.*$" .env >/dev/null 2>&1 && [ -s ".env" ]; then
        # File exists but might have syntax issues, let's be more specific
        local invalid_lines
        invalid_lines=$(grep -v "^#" .env | grep -v "^$" | grep -cv "^[A-Z_][A-Z0-9_]*=" || echo "0")
        if [ "$invalid_lines" -gt 0 ]; then
            syntax_errors=$invalid_lines
        fi
    fi

    # Check for required variables
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        if ! grep -q "^${var}=" .env 2>/dev/null; then
            missing_vars+=("$var")
        fi
    done

    # Check for empty critical values
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        if grep -q "^${var}=$" .env 2>/dev/null; then
            empty_vars+=("$var")
        fi
    done

    # Report results
    if [ "$syntax_errors" -eq 0 ] && [ ${#missing_vars[@]} -eq 0 ] && [ ${#empty_vars[@]} -eq 0 ]; then
        local var_count
        var_count=$(grep -c "^[A-Z_][A-Z0-9_]*=" .env 2>/dev/null || echo "0")
        print_success ".env file valid ($var_count variables)"
    elif [ "$syntax_errors" -gt 0 ]; then
        print_error ".env syntax errors ($syntax_errors lines)"
    elif [ ${#missing_vars[@]} -gt 0 ]; then
        print_warning ".env missing variables: ${missing_vars[*]}"
    elif [ ${#empty_vars[@]} -gt 0 ]; then
        print_warning ".env empty values: ${empty_vars[*]}"
    fi
}

# Check Makefile configuration
check_makefile_config() {
    if [ ! -f "Makefile" ]; then
        print_error "Makefile missing"
        return "$EXIT_GENERAL_ERROR"
    fi

    # Check syntax by trying to parse targets
    if make -n -f Makefile >/dev/null 2>&1; then
        # Check for required targets
        local missing_targets=()

        for target in "${REQUIRED_MAKEFILE_TARGETS[@]}"; do
            if ! grep -q "^${target}:" Makefile 2>/dev/null; then
                missing_targets+=("$target")
            fi
        done

        if [ ${#missing_targets[@]} -eq 0 ]; then
            # Count total targets
            local target_count
            target_count=$(grep -c "^[a-zA-Z_-]*:" Makefile 2>/dev/null || echo "0")
            print_success "Makefile valid ($target_count targets)"
        else
            print_warning "Makefile valid, missing targets: ${missing_targets[*]}"
        fi
    else
        print_error "Makefile syntax error"
    fi
}

# Check nginx templates
check_nginx_templates() {
    local templates_dir="$NGINX_TEMPLATES_DIR"
    local missing_templates=()

    if [ ! -d "$templates_dir" ]; then
        print_error "nginx templates directory missing"
        return "$EXIT_GENERAL_ERROR"
    fi

    for template in "${REQUIRED_NGINX_TEMPLATES[@]}"; do
        if [ ! -f "$templates_dir/$template" ]; then
            missing_templates+=("$template")
        fi
    done

    if [ ${#missing_templates[@]} -gt 0 ]; then
        print_error "nginx templates missing (${#missing_templates[@]}/${#REQUIRED_NGINX_TEMPLATES[@]})"
        return "$EXIT_GENERAL_ERROR"
    fi

    print_success "nginx templates available (${#REQUIRED_NGINX_TEMPLATES[@]})"
    return "$EXIT_SUCCESS"
}

# Check SSL certificates
check_ssl_certificates() {
    local ssl_dir="$NGINX_SSL_DIR"
    local ssl_ca_dir="${DOCKERKIT_DIR}/${SSL_CA_DIR:-ssl-ca}"

    # Check for root CA certificates in ssl-ca directory
    local root_ca_cert="$ssl_ca_dir/rootCA.crt"
    local root_ca_key="$ssl_ca_dir/rootCA.key"
    local has_root_ca=false

    if [ -f "$root_ca_cert" ] && [ -f "$root_ca_key" ]; then
        has_root_ca=true
        print_success "Root CA certificates available"
    fi

    # Count site certificates in nginx/ssl directory
    local site_certs_count=0
    if [ -d "$ssl_dir" ] && compgen -G "$ssl_dir/*.local.crt" > /dev/null 2>&1; then
        site_certs_count=$(find "$ssl_dir" -name "*.local.crt" | wc -l | tr -d ' ')
    fi

    # Only show site certificates if they exist
    if [ "$site_certs_count" -gt 0 ]; then
        print_success "Site certificates available ($site_certs_count)"
    fi

    # If no certificates at all, don't show anything
    if [ "$has_root_ca" = false ] && [ "$site_certs_count" -eq 0 ]; then
        return "$EXIT_SUCCESS"
    fi
}

# Show system resources information
show_system_resources() {
    print_section "System Resources"

    # Get CPU information
    local cpu_brand cores
    if command_exists "sysctl"; then
        cpu_brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")
        cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "unknown")

        if [ "$cpu_brand" != "unknown" ] && [ "$cores" != "unknown" ]; then
            print_success "CPU: $cpu_brand ($cores cores)"
        else
            print_warning "CPU: Unable to detect"
        fi
    else
        print_warning "CPU: Unable to detect (sysctl not available)"
    fi

    # Get memory information
    get_memory_info

    # Get disk space information
    local disk_info
    if command_exists "df"; then
        disk_info=$(df -h / 2>/dev/null | tail -1)
        if [ -n "$disk_info" ]; then
            # Extract values: format like "/dev/disk3s1s1   460Gi    10Gi   213Gi     5%"
            total_disk=$(echo "$disk_info" | tr -s ' ' | cut -d' ' -f2 | sed 's/Gi$/GB/' || echo "unknown")
            free_disk=$(echo "$disk_info" | tr -s ' ' | cut -d' ' -f4 | sed 's/Gi$/GB/' || echo "unknown")

            if [ "$total_disk" != "unknown" ] && [ "$free_disk" != "unknown" ]; then
                # Calculate actual free percentage from real numbers (not df's used_percent which includes reserved space)
                local free_num total_num free_percent
                free_num=${free_disk%GB}
                total_num=${total_disk%GB}

                if command -v bc >/dev/null 2>&1 && [ "$total_num" != "0" ]; then
                    free_percent=$(echo "scale=0; $free_num * 100 / $total_num" | bc 2>/dev/null || echo "unknown")
                else
                    # Fallback without bc
                    free_percent=$(echo "scale=0; $free_num * 100 / $total_num" | bc 2>/dev/null || echo "unknown")
                fi

                if [ "$free_percent" != "unknown" ]; then
                    print_success "Disk space: ${free_disk} free / ${total_disk} total (${free_percent}% free)"
                else
                    print_success "Disk space: ${free_disk} free / ${total_disk} total"
                fi
            else
                print_warning "Disk space: Unable to parse disk information"
            fi
        else
            print_warning "Disk space: Unable to get disk information"
        fi
    else
        print_warning "Disk space: Unable to detect (df not available)"
    fi
}

# Show system performance information
show_system_performance() {
    print_section "System Performance"

    # Get load average from uptime
    local load_avg
    if command_exists "uptime"; then
        load_avg=$(uptime 2>/dev/null | grep -o 'load averages: [0-9.]* [0-9.]* [0-9.]*' | sed 's/load averages: //' || echo "unknown")
        if [ "$load_avg" != "unknown" ]; then
            print_success "Load average: $load_avg (1m, 5m, 15m)"
        else
            print_warning "Load average: Unable to parse"
        fi
    else
        print_warning "Load average: Unable to detect (uptime not available)"
    fi

    # Get CPU usage from top
    local cpu_usage
    if command_exists "top"; then
        cpu_usage=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage:" | head -1)
        if [ -n "$cpu_usage" ]; then
            # Extract user and sys percentages and calculate busy
            user_cpu=$(echo "$cpu_usage" | grep -o '[0-9.]*% user' | grep -o '[0-9.]*' || echo "0")
            sys_cpu=$(echo "$cpu_usage" | grep -o '[0-9.]*% sys' | grep -o '[0-9.]*' || echo "0")
            idle_cpu=$(echo "$cpu_usage" | grep -o '[0-9.]*% idle' | grep -o '[0-9.]*' || echo "0")

            if [ "${idle_cpu%%.*}" -gt 0 ]; then
                # Calculate busy percentage (100 - idle) using integer math
                busy_cpu=$((100 - ${idle_cpu%%.*}))
                print_success "CPU usage: ${busy_cpu}% busy, ${idle_cpu}% idle"
            else
                print_success "CPU usage: ${user_cpu}% user, ${sys_cpu}% sys, ${idle_cpu}% idle"
            fi
        else
            print_warning "CPU usage: Unable to get from top"
        fi
    else
        print_warning "CPU usage: Unable to detect (top not available)"
    fi

    # Get process information from top
    local process_info
    if command_exists "top"; then
        process_info=$(top -l 1 -n 0 2>/dev/null | grep "Processes:" | head -1)
        if [ -n "$process_info" ]; then
            # Extract process counts
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

    # Get uptime
    local uptime_info
    if command_exists "uptime"; then
        uptime_info=$(uptime 2>/dev/null | sed 's/.*up *//; s/, *load.*//' | sed 's/, *[0-9]* users*//' || echo "unknown")
        if [ "$uptime_info" != "unknown" ] && [ -n "$uptime_info" ]; then
            print_success "Uptime: $uptime_info"
        else
            print_warning "Uptime: Unable to parse"
        fi
    else
        print_warning "Uptime: Unable to detect (uptime not available)"
    fi

    # Get network statistics from top
    local network_info
    if command_exists "top"; then
        network_info=$(top -l 1 -n 0 2>/dev/null | grep "Networks:" | head -1)
        if [ -n "$network_info" ]; then
            # Extract network data
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
}
