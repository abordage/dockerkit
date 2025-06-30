#!/bin/bash

# =============================================================================
# SITE STATUS CHECKER
# =============================================================================
# Functions to check status and response times of .local sites
# Usage: source this file and call check_site_status
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"
# shellcheck source=../core/base.sh
source "$BASE_DIR/base.sh"

# Load dependencies
SITE_STATUS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../core/utils.sh
source "$SITE_STATUS_SCRIPT_DIR/../core/utils.sh"
# shellcheck source=../core/config.sh
source "$SITE_STATUS_SCRIPT_DIR/../core/config.sh"
# shellcheck source=../core/math.sh
source "$SITE_STATUS_SCRIPT_DIR/../core/math.sh"

# Check status of all .local sites
check_site_status() {
    local sites=()
    # shellcheck disable=SC2207
    sites=($(discover_sites_from_configs))

    # If no sites found, don't show the section at all
    if [ ${#sites[@]} -eq 0 ]; then
        return "$EXIT_SUCCESS"
    fi

    print_section "Site Status"

    # Test each site
    for site_name in "${sites[@]}"; do
        test_site_status "$site_name" || true
    done
}

# Discover sites from nginx configurations
discover_sites_from_configs() {
    # Get DOCKERKIT_DIR from environment or calculate it
    local dockerkit_dir="${DOCKERKIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
    local sites_dir="$dockerkit_dir/$NGINX_SITES_DIR"
    local sites=()

    if [ ! -d "$sites_dir" ]; then
        return
    fi

    for config_file in "$sites_dir"/*.conf; do
        if [ -f "$config_file" ]; then
            local site_name
            site_name=$(basename "$config_file" .conf)
            # Skip default site
            if [ "$site_name" != "default" ]; then
                sites+=("$site_name")
            fi
        fi
    done

    # Only echo if sites array has elements
    if [ ${#sites[@]} -gt 0 ]; then
        echo "${sites[@]}"
    fi
}

# Test a single site status
test_site_status() {
    local site_name="$1"
    local url="https://$site_name"

    # Perform curl test
    local curl_output
    curl_output=$(perform_curl_test "$url")

    # Parse and display result
    parse_and_display_site_result "$site_name" "$curl_output"
}

# Perform curl performance test
perform_curl_test() {
    local url="$1"
    local format_string="DNS_LOOKUP:%{time_namelookup}|TCP_CONNECT:%{time_connect}|SSL_HANDSHAKE:%{time_appconnect}|PRETRANSFER:%{time_pretransfer}|TRANSFER_START:%{time_starttransfer}|TOTAL_TIME:%{time_total}|HTTP_CODE:%{http_code}"

    curl -w "$format_string" \
         -o /dev/null \
         -s \
         -k \
         --connect-timeout "$CURL_CONNECT_TIMEOUT" \
         --max-time "$CURL_MAX_TIME" \
         "$url" 2>/dev/null || echo "DNS_LOOKUP:0|TCP_CONNECT:0|SSL_HANDSHAKE:0|PRETRANSFER:0|TRANSFER_START:0|TOTAL_TIME:999|HTTP_CODE:000"
}

# Validate and set default value for timing data
validate_and_default_time() {
    local value="$1"
    local default="${2:-0.000}"

    if [[ "$value" =~ ^[0-9.]+$ ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Parse curl output and display formatted result for a site
parse_and_display_site_result() {
    local site_name="$1"
    local curl_output="$2"

    # Extract timing values
    local dns_time ssl_time pretransfer_time starttransfer_time total_time http_code

    dns_time=$(echo "$curl_output" | grep -o 'DNS_LOOKUP:[0-9.]*' | cut -d: -f2 || echo "0.000")
    ssl_time=$(echo "$curl_output" | grep -o 'SSL_HANDSHAKE:[0-9.]*' | cut -d: -f2 || echo "0.000")
    pretransfer_time=$(echo "$curl_output" | grep -o 'PRETRANSFER:[0-9.]*' | cut -d: -f2 || echo "0.000")
    starttransfer_time=$(echo "$curl_output" | grep -o 'TRANSFER_START:[0-9.]*' | cut -d: -f2 || echo "0.000")
    total_time=$(echo "$curl_output" | grep -o 'TOTAL_TIME:[0-9.]*' | cut -d: -f2 || echo "999.999")
    http_code=$(echo "$curl_output" | grep -o 'HTTP_CODE:[0-9]*' | cut -d: -f2 || echo "000")

    # Validate and normalize timing values using universal function
    dns_time=$(validate_and_default_time "$dns_time")
    ssl_time=$(validate_and_default_time "$ssl_time")
    pretransfer_time=$(validate_and_default_time "$pretransfer_time")
    starttransfer_time=$(validate_and_default_time "$starttransfer_time")
    total_time=$(validate_and_default_time "$total_time" "999.999")

    # Validate HTTP code
    if [[ ! "$http_code" =~ ^[0-9]+$ ]]; then
        http_code="000"
    fi

    # Calculate TTFB (Time To First Byte) = starttransfer - pretransfer
    local ttfb_time
    local ttfb_raw
    ttfb_raw=$(math_subtract "$starttransfer_time" "$pretransfer_time")

    # Ensure TTFB is not negative
    if ! math_compare_gte "$ttfb_raw" "0"; then
        ttfb_raw="0"
    fi

    ttfb_time=$(format_time_smart "$ttfb_raw")

    # Format times with smart units
    total_time=$(format_time_smart "$total_time")
    dns_time=$(format_time_smart "$dns_time")
    ssl_time=$(format_time_smart "$ssl_time")

    # Format timing information and total time with color coding
    local timing_info
    timing_info=$(format_timing_info "$dns_time" "$ssl_time" "$ttfb_time")

    local total_time_colored
    total_time_colored=$(format_total_time "$total_time")

    # Display result with unified format using standard functions
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
        # 2xx success, 3xx redirects - site is working
        print_success "$site_name: $total_time_colored $timing_info $(green '[OK]')"
    elif [ "$http_code" -ge 400 ] && [ "$http_code" -lt 600 ]; then
        # 4xx client errors, 5xx server errors - site accessible but with issues
        print_success "$site_name: $total_time_colored $timing_info $(yellow "[$http_code]")"
    else
        # Other codes - treat as unavailable
        print_error "$site_name $(yellow '[UNAVAILABLE]')"
    fi
}

# Format timing information with TTFB (white color for details in parentheses)
format_timing_info() {
    local dns_time="$1"
    local ssl_time="$2"
    local ttfb_time="$3"

    echo "(DNS: ${dns_time}, SSL: ${ssl_time}, TTFB: ${ttfb_time})"
}

# Format total time with color coding based on performance
format_total_time() {
    local total_time="$1"

    # Extract numeric value for comparison (remove 'ms' or 's' suffix)
    local numeric_time
    if [[ "$total_time" == *"ms" ]]; then
        numeric_time="${total_time%ms}"
        numeric_time=$(math_operation "$numeric_time / 1000" 3)
    else
        numeric_time="${total_time%s}"
    fi

    # Check if total time is slow (above threshold)
    if is_time_above_threshold "$numeric_time" "$PERFORMANCE_THRESHOLD_TOTAL"; then
        yellow "$total_time"
    else
        green "$total_time"
    fi
}

# Check if time is above threshold (using math functions for floating point comparison)
is_time_above_threshold() {
    local time_value="$1"
    local threshold="$2"

    # Use math functions for reliable floating point comparison
    math_compare_gt "$time_value" "$threshold"
}

# Format time with smart units (ms for < 0.1s, s for >= 0.1s)
format_time_smart() {
    local time_val="$1"

    # Handle edge cases
    if [ -z "$time_val" ] || [ "$time_val" = "0" ]; then
        echo "0ms"
        return
    fi

    # Compare with 0.1 second threshold
    if math_compare_gte "$time_val" "0.1"; then
        # Show seconds with 1 decimal place - use math functions for precise formatting
        local formatted_seconds
        formatted_seconds=$(math_operation "$time_val / 1" 1)
        echo "${formatted_seconds}s"
    else
        # Show milliseconds (rounded to 1 decimal place) - use math functions for precise calculation
        local ms_raw ms_rounded
        ms_raw=$(math_multiply "$time_val" "1000")
        ms_rounded=$(math_round "$ms_raw" 1)
        echo "${ms_rounded}ms"
    fi
}

# Legacy function for backward compatibility (now uses smart formatting)
round_time() {
    format_time_smart "$1"
}
