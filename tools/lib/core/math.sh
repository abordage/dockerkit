#!/bin/bash

# =============================================================================
# MATHEMATICAL OPERATIONS MODULE
# =============================================================================
# Cross-platform mathematical functions with bc fallback support
# =============================================================================

set -euo pipefail

# Prevent multiple inclusion
if [[ "${DOCKERKIT_MATH_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly DOCKERKIT_MATH_LOADED="true"

# =============================================================================
# BASIC MATHEMATICAL OPERATIONS
# =============================================================================

math_operation() {
    local expression="$1"
    local precision="${2:-0}"
    if command -v bc >/dev/null 2>&1; then
        local result
        if [ "$precision" -gt 0 ]; then
            result=$(echo "scale=$precision; $expression" | bc -l 2>/dev/null)
        else
            result=$(echo "$expression" | bc -l 2>/dev/null)
        fi

        if [[ "$result" == *.* ]]; then
            result=$(echo "$result" | sed 's/\.0*$//' | sed 's/\([0-9]\)0*$/\1/')
        fi
        echo "$result"
    else
        echo "0"
    fi
}

math_subtract() {
    local val1="$1"
    local val2="$2"

    if command -v bc >/dev/null 2>&1; then
        local result
        result=$(echo "$val1 - $val2" | bc -l)
        if [[ "$result" == *.* ]]; then
            result=$(echo "$result" | sed 's/\.0*$//' | sed 's/\([0-9]\)0*$/\1/')
        fi
        echo "$result"
    else
        echo "0"
    fi
}

math_multiply() {
    local val1="$1"
    local val2="$2"

    if command -v bc >/dev/null 2>&1; then
        local result
        result=$(echo "$val1 * $val2" | bc -l)
        if [[ "$result" == *.* ]]; then
            result=$(echo "$result" | sed 's/\.0*$//' | sed 's/\([0-9]\)0*$/\1/')
        fi
        echo "$result"
    else
        echo "0"
    fi
}

# =============================================================================
# COMPARISON FUNCTIONS
# =============================================================================

math_compare() {
    local val1="$1"
    local operator="$2"
    local val2="$3"

    if command -v bc >/dev/null 2>&1; then
        [ "$(echo "$val1 $operator $val2" | bc -l)" = "1" ]
    else
        case "$operator" in
            ">")  [ "${val1%.*}" -gt "${val2%.*}" ] ;;
            ">=") [ "${val1%.*}" -ge "${val2%.*}" ] ;;
            "<")  [ "${val1%.*}" -lt "${val2%.*}" ] ;;
            "<=") [ "${val1%.*}" -le "${val2%.*}" ] ;;
            "==") [ "$val1" = "$val2" ] ;;
            "!=") [ "$val1" != "$val2" ] ;;
            *) return 1 ;;
        esac
    fi
}

math_compare_gt() {
    math_compare "$1" ">" "$2"
}

math_compare_gte() {
    math_compare "$1" ">=" "$2"
}

math_compare_eq() {
    math_compare "$1" "==" "$2"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

math_round() {
    local number="$1"
    local decimals="${2:-0}"

    if command -v bc >/dev/null 2>&1; then
        if [ "$decimals" -eq 0 ]; then
            # Round to integer using bc and then format
            local result
            result=$(echo "scale=0; ($number + 0.5) / 1" | bc -l 2>/dev/null)
            # Force integer output by removing everything after decimal point
            printf "%.0f" "$result" 2>/dev/null || echo "${result%.*}"
        else
            # Round to specific decimal places using printf
            printf "%.${decimals}f" "$number" 2>/dev/null || echo "$number"
        fi
    else
        # Simple fallback - truncate decimals
        if [ "$decimals" -eq 0 ]; then
            echo "${number%.*}"
        else
            echo "$number"
        fi
    fi
}

math_percentage() {
    local value="$1"
    local total="$2"
    local precision="${3:-1}"

    if math_compare_eq "$total" "0"; then
        echo "0"
    else
        local result
        result=$(math_operation "($value * 100) / $total" "$precision")
        # Round the result to the specified precision
        math_round "$result" "$precision"
    fi
}
