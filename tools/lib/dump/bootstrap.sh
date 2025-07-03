#!/bin/bash

# =============================================================================
# DUMP MANAGER BOOTSTRAP
# =============================================================================
# Initialization and library loading for database dump operations
# =============================================================================

# Load core utilities
source "$SCRIPT_DIR/lib/core/utils.sh"

# Load dump-specific libraries
source "$SCRIPT_DIR/lib/dump/registry.sh"
source "$SCRIPT_DIR/lib/dump/ui.sh"
source "$SCRIPT_DIR/lib/dump/workflows.sh"

# Load database drivers
source "$SCRIPT_DIR/lib/dump/drivers/mysql.sh"
source "$SCRIPT_DIR/lib/dump/drivers/postgres.sh"

# =============================================================================
# CONSTANTS
# =============================================================================

readonly DUMPS_DIR="$DOCKERKIT_DIR/dumps"
readonly TIMESTAMP_FORMAT="%Y-%m-%d_%H-%M-%S-UTC"
# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Execute command in workspace container
workspace_exec() {
    debug_log "dump" "Executing in workspace container: $*"
    local result
    if docker compose exec workspace "$@"; then
        debug_log "dump" "Workspace command succeeded: $*"
        return 0
    else
        result=$?
        debug_log "dump" "Workspace command failed with exit code $result: $*"
        return $result
    fi
}

# =============================================================================
# INITIALIZATION FUNCTIONS
# =============================================================================

# Initialize dump environment
initialize_dump_environment() {
    # Verify dumps directory exists
    if [[ ! -d "$DUMPS_DIR" ]]; then
        print_section "Initializing dump environment"
        print_error "Dumps directory not found: $DUMPS_DIR"
        exit "$EXIT_INVALID_CONFIG"
    fi

    # Verify workspace container exists and is running
    if ! workspace_exec echo "test" >/dev/null 2>&1; then
        print_section "Initializing dump environment"
        print_error "Workspace container not found or not running"
        print_tip "Start DockerKit containers first: make start"
        exit "$EXIT_CONTAINER_NOT_FOUND"
    fi
}

# Run interactive workflow
run_interactive_workflow() {
    # Step 1: Select database type
    local db_type
    db_type=$(select_database_type)

    # Step 2: Select operation
    local operation_label
    operation_label=$(select_operation)

    # Convert operation label to code
    local operation
    operation=$(get_operation_code "$operation_label")

    # Step 3: Execute workflow based on selection
    case "$operation" in
        "export")
            run_export_workflow "$db_type"
            ;;
        "import")
            run_import_workflow "$db_type"
            ;;
        *)
            print_error "Unknown operation: $operation"
            exit "$EXIT_INVALID_INPUT"
            ;;
    esac
}

# Generate dump filename with timestamp
generate_dump_filename() {
    local db_type="$1"
    local db_name="$2"
    local compress="$3"

    local timestamp
    timestamp=$(TZ=UTC date +"$TIMESTAMP_FORMAT")

    local extension="sql"
    if [[ "$compress" == "true" ]]; then
        extension="sql.gz"
    fi

    echo "${db_type}_${db_name}_${timestamp}.${extension}"
}
