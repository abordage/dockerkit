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
source "$BASE_DIR/base.sh"

# Load dependencies
LIB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_SCRIPT_DIR/../core/utils.sh"
source "$LIB_SCRIPT_DIR/../core/config.sh"
source "$LIB_SCRIPT_DIR/../core/math.sh"
source "$LIB_SCRIPT_DIR/../core/platform.sh"
source "$LIB_SCRIPT_DIR/tools-status.sh"
source "$LIB_SCRIPT_DIR/docker-status.sh"
source "$LIB_SCRIPT_DIR/site-status.sh"

# =============================================================================
# CONFIGURATION CHECKING FUNCTIONS
# =============================================================================

is_env_file_valid() {
    local syntax_errors="$1"
    local missing_count="$2"
    local empty_count="$3"

    [ "$syntax_errors" -eq 0 ] && \
    [ "$missing_count" -eq 0 ] && \
    [ "$empty_count" -eq 0 ]
}

get_total_memory_gb() {
    if command_exists "sysctl"; then
        local mem_bytes
        mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
        if [ -n "$mem_bytes" ] && [ "$mem_bytes" -gt 0 ]; then
            # Convert bytes to GB using math module with precision
            math_operation "$mem_bytes / 1024 / 1024 / 1024" 1
            return
        fi
    fi
    echo "unknown"
}

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

                # Calculate percentage using math module
                if [ "${used_mem%%.*}" -gt 0 ] && [ "${total_mem%%.*}" -gt 0 ]; then
                    local percentage
                    percentage=$(math_percentage "$used_mem" "$total_mem" 0)
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

validate_project_configuration() {
    print_section "Project Configuration"

    show_project_info
    check_env_file
    check_makefile_config
    check_nginx_templates
    check_ssl_certificates
}

show_project_info() {
    if [ -f ".env" ]; then
                source .env
    else
        print_warning "No .env file found"
    fi
}

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

    # Check if .env file is in perfect state
    if is_env_file_valid "$syntax_errors" "${#missing_vars[@]}" "${#empty_vars[@]}"; then
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

show_system_resources() {
    print_section "System Resources"

    # Get CPU information using cross-platform function
    get_cpu_info

    # Get memory information
    get_memory_info

    # Get disk space information using cross-platform function
    get_disk_info
}

show_system_performance() {
    print_section "System Performance"

    # Get load average using cross-platform function
    get_load_average

    # Get CPU usage using cross-platform function
    get_cpu_usage

    # Get process information using cross-platform function
    get_process_info

    # Get uptime using cross-platform function
    get_uptime

    # Get network statistics using cross-platform function
    get_network_stats
}
