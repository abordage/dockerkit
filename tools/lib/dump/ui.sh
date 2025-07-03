#!/bin/bash

# =============================================================================
# USER INTERFACE COMPONENTS
# =============================================================================
# Interactive menu and input functions for database dump operations
# =============================================================================

# Load universal input system
UI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${UI_SCRIPT_DIR}/../core/input.sh"

# =============================================================================
# OPERATION TYPES
# =============================================================================

readonly OPERATIONS=(
    "export"
    "import"
)

readonly OPERATION_LABELS=(
    "Export (create dump)"
    "Import (restore dump)"
)

# =============================================================================
# WORKFLOW FUNCTIONS
# =============================================================================

# Step 1: Select database type
select_database_type() {
    local db_types=()
    local db_type

    # Bash 3.x compatible way to fill array
    while IFS= read -r db_type; do
        db_types+=("$db_type")
    done < <(get_supported_db_types)

    input_menu "Select database type:" "${db_types[@]}"
}

# Step 2: Select operation
select_operation() {
    input_menu "Select operation:" "${OPERATION_LABELS[@]}"
}

# Convert operation label to operation code
get_operation_code() {
    local operation_label="$1"

    for i in "${!OPERATION_LABELS[@]}"; do
        if [[ "${OPERATION_LABELS[i]}" == "$operation_label" ]]; then
            echo "${OPERATIONS[i]}"
            return 0
        fi
    done

    print_error "Unknown operation: $operation_label"
    return 1
}
