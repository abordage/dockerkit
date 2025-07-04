#!/bin/bash

# =============================================================================
# UNIVERSAL INPUT SYSTEM
# =============================================================================
# Unified input system for all DockerKit scripts with real-time validation,
# system beep for invalid input, and comprehensive debugging capabilities
# =============================================================================

set -euo pipefail

# Prevent multiple inclusion
if [[ "${DOCKERKIT_INPUT_LOADED:-}" == "true" ]]; then
    return 0
fi

# Load dependencies
INPUT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${INPUT_SCRIPT_DIR}/colors.sh"

# Constants
readonly INPUT_DEBUG="${INPUT_DEBUG:-0}"
readonly INPUT_BEEP_ENABLED="${INPUT_BEEP_ENABLED:-1}"

# Special characters
readonly CHAR_BACKSPACE_1=$'\x7f'  # Delete key
readonly CHAR_BACKSPACE_2=$'\x08'  # Backspace key
readonly CHAR_ESCAPE=$'\x1b'

# Mark as loaded
readonly DOCKERKIT_INPUT_LOADED="true"

# =============================================================================
# DEBUG AND UTILITY FUNCTIONS
# =============================================================================

_input_debug() {
    if [[ "$INPUT_DEBUG" == "1" ]]; then
        printf "DEBUG[input]: %s\n" "$1" >&2
    fi
}

_input_beep() {
    if [[ "$INPUT_BEEP_ENABLED" == "1" ]]; then
        printf '\a' >&2
    fi
}

_debug_char() {
    local char="$1"
    if [[ -z "$char" ]]; then
        echo "ENTER"
    elif [[ "$char" == "$CHAR_BACKSPACE_1" || "$char" == "$CHAR_BACKSPACE_2" ]]; then
        echo "BACKSPACE"
    elif [[ "$char" == "$CHAR_ESCAPE" ]]; then
        echo "ESCAPE"
    elif [[ $(printf '%d' "'$char") -lt 32 ]]; then
        printf "CTRL+%d" $(($(printf '%d' "'$char") + 64))
    else
        echo "$char"
    fi
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

_validate_menu_input() {
    local char="$1"
    local current_selection="$2"
    local max_option="$3"

    # Only allow digits
    if [[ "$char" =~ ^[0-9]$ ]]; then
        local new_selection="${current_selection}${char}"
        if (( new_selection > 0 && new_selection <= max_option )); then
            return 0
        fi
    fi
    return 1
}

_validate_yesno_input() {
    local char="$1"
    local current_selection="$2"
    [[ "$char" =~ ^[yYnN]$ ]]
}

_validate_text_input() {
    local char="$1"
    local current_selection="$2"
    local pattern="$3"
    [[ "$char" =~ $pattern ]]
}

# =============================================================================
# CORE INPUT ENGINE
# =============================================================================

_input_engine() {
    local validation_func="$1"
    local output_var=""
    shift

    _input_debug "Starting input engine with validator: $validation_func"

    while IFS= read -rsn1 char; do
        _input_debug "Input char: $(_debug_char "$char")"

        if [[ -z "$char" ]]; then
            # Enter pressed
            _input_debug "Enter pressed, current output: '$output_var'"
            if [[ -n "$output_var" ]]; then
                echo "$output_var"
                echo >&2
                return 0
            else
                _input_debug "Empty input, requiring non-empty"
                _input_beep
            fi
        elif [[ "$char" == "$CHAR_BACKSPACE_1" || "$char" == "$CHAR_BACKSPACE_2" ]]; then
            # Backspace
            if [[ -n "$output_var" ]]; then
                output_var="${output_var%?}"
                printf '\b \b' >&2
                _input_debug "Backspace, new output: '$output_var'"
            else
                _input_beep
            fi
        elif "$validation_func" "$char" "$output_var" "$@"; then
            # Valid character
            output_var+="$char"
            printf '%s' "$char" >&2
            _input_debug "Valid char accepted, output: '$output_var'"
        else
            # Invalid character
            _input_debug "Invalid char rejected"
            _input_beep
        fi
    done
}

# =============================================================================
# SPECIALIZED INPUT FUNCTIONS
# =============================================================================

input_menu() {
    local prompt="$1"
    shift
    local options=("$@")
    local max_option=${#options[@]}

    _input_debug "Starting menu input, options: ${#options[@]}"

    # Display prompt
    echo >&2
    printf '%b' "$(yellow "$prompt")" >&2

    # Display options
    _display_menu_options "${options[@]}"

    # Get user selection
    # printf '%b' "$(yellow "Your choice [1-$max_option]: ")" >&2
    printf '%b' "$(green "> ")" >&2

    local selection
    selection=$(_input_engine "_validate_menu_input" "$max_option")

    # Return selected option (1-based to 0-based)
    echo "${options[$((selection-1))]}"
}

input_yesno() {
    local prompt="$1"
    local default="${2:-y}"

    _input_debug "Starting yes/no input, default: $default"

    # Display prompt with default indication
    echo >&2
    printf '%b' "$(yellow "$prompt (y/n) [$default]: ")" >&2

    while IFS= read -rsn1 char; do
        _input_debug "YesNo input char: $(_debug_char "$char")"

        if [[ -z "$char" ]]; then
            # Enter pressed - use default
            printf '%s' "$default" >&2
            echo >&2
            case "$default" in
                [Yy]* ) return 0;;
                [Nn]* ) return 1;;
            esac
        elif [[ "$char" =~ ^[yY]$ ]]; then
            printf '%s' "$char" >&2
            echo >&2
            return 0
        elif [[ "$char" =~ ^[nN]$ ]]; then
            printf '%s' "$char" >&2
            echo >&2
            return 1
        else
            _input_debug "Invalid yes/no char"
            _input_beep
        fi
    done
}

input_text() {
    local prompt="$1"
    local pattern="${2:-[a-zA-Z0-9_-]}"
    local allow_empty="${3:-0}"

    _input_debug "Starting text input, pattern: $pattern, allow_empty: $allow_empty"

    # Display prompt
    echo >&2
    printf '%b' "$(yellow "$prompt")" >&2

    while true; do
        local input
        input=$(_input_engine "_validate_text_input" "$pattern")

        if [[ -n "$input" || "$allow_empty" == "1" ]]; then
            echo "$input"
            return 0
        else
            printf '%b' "$(red "Input cannot be empty. Try again: ")" >&2
        fi
    done
}

# =============================================================================
# DISPLAY FUNCTIONS
# =============================================================================

_display_menu_options() {
    local options=("$@")
    local total_items=${#options[@]}

    echo >&2

    # Calculate number width for alignment (e.g., "999" = 3 characters)
    local num_width=${#total_items}

    if (( total_items <= 15 )); then
        # Single column for small lists with aligned numbers
        for i in "${!options[@]}"; do
            printf "  %*d. %s\n" "$num_width" $((i+1)) "${options[i]}" >&2
        done
    else
        # Multiple columns for large lists
        local columns=2
        local terminal_width
        terminal_width=$(tput cols 2>/dev/null || echo 80)

        # Calculate max item length
        local max_length=0
        for item in "${options[@]}"; do
            if (( ${#item} > max_length )); then
                max_length=${#item}
            fi
        done

        # Determine optimal columns based on terminal width
        # +4 for "  " prefix, +2 for ". " after number, +2 for spacing
        local item_width=$((num_width + max_length + 8))
        if (( terminal_width >= item_width * 4 )); then
            columns=4
        elif (( terminal_width >= item_width * 3 )); then
            columns=3
        fi

        # Display in columns with aligned numbers
        local rows=$(( (total_items + columns - 1) / columns ))
        for (( row = 0; row < rows; row++ )); do
            for (( col = 0; col < columns; col++ )); do
                local idx=$((row + col * rows))
                if (( idx < total_items )); then
                    printf "  %*d. %-*s" "$num_width" $((idx+1)) "$max_length" "${options[idx]}" >&2
                    if (( col < columns - 1 )); then
                        printf "  " >&2  # Add spacing between columns
                    fi
                fi
            done
            echo >&2
        done
    fi

    # echo >&2
}

# =============================================================================
# CONVENIENCE FUNCTIONS
# =============================================================================

confirm() {
    local message="$1"
    local default="${2:-y}"
    input_yesno "$message" "$default"
}

input_database_name() {
    local prompt="${1:-Enter database name: }"
    input_text "$prompt" "[a-zA-Z0-9_]+"
}

input_filename() {
    local prompt="${1:-Enter filename: }"
    input_text "$prompt" "[a-zA-Z0-9._-]+"
}
