#!/bin/bash

# =============================================================================
# POSTGRESQL DATABASE DRIVER
# =============================================================================
# PostgreSQL database operations using Docker containers
# =============================================================================

# =============================================================================
# CONSTANTS
# =============================================================================

readonly POSTGRES_HOST="postgres"
readonly POSTGRES_USER="${POSTGRES_USER:-dockerkit}"
readonly POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-dockerkit}"
readonly POSTGRES_DEFAULT_DB="${POSTGRES_DB:-default}"
readonly POSTGRES_DUMPS_PATH="/dumps/postgres"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

postgres_exec() {
    local database="${1:-$POSTGRES_DEFAULT_DB}"
    shift

    debug_log "postgres" "Executing PostgreSQL command on database '$database' with args: $*"
    debug_log "postgres" "Full command: PGPASSWORD='***' psql -h'$POSTGRES_HOST' -U'$POSTGRES_USER' -d'$database' $*"

    workspace_exec env PGPASSWORD="$POSTGRES_PASSWORD" psql \
        -q \
        -h"$POSTGRES_HOST" \
        -U"$POSTGRES_USER" \
        -d"$database" \
        "$@" 2>/dev/null
}

postgres_exec_clean() {
    postgres_exec "$@" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$'
}

postgres_bash_exec() {
    workspace_exec bash -c "$1" >/dev/null 2>&1
}

postgres_dump_path() {
    local dump_file="$1"
    echo "$POSTGRES_DUMPS_PATH/$dump_file"
}

# =============================================================================
# CONNECTION FUNCTIONS
# =============================================================================

postgres_test_connection() {
    debug_log "postgres" "Testing PostgreSQL connection to host=$POSTGRES_HOST, user=$POSTGRES_USER, database=$POSTGRES_DEFAULT_DB"

    # Test workspace container accessibility
    debug_log "postgres" "Checking workspace container accessibility"
    if ! workspace_exec echo "workspace test" >/dev/null 2>&1; then
        debug_log "postgres" "ERROR: Workspace container is not accessible"
        return 1
    fi
    debug_log "postgres" "Workspace container is accessible"

    # Test PostgreSQL connection directly
    debug_log "postgres" "Testing PostgreSQL connection with query: SELECT 1"
    if postgres_exec "$POSTGRES_DEFAULT_DB" -c "SELECT 1;" >/dev/null; then
        debug_log "postgres" "PostgreSQL connection test successful"
        return 0
    else
        debug_log "postgres" "ERROR: PostgreSQL connection test failed - check PostgreSQL service is running"
        return 1
    fi
}

# =============================================================================
# DATABASE MANAGEMENT
# =============================================================================

postgres_list_databases() {
    postgres_exec_clean "$POSTGRES_DEFAULT_DB" -t -c \
        "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres', 'default');"
}

postgres_database_exists() {
    local db_name="$1"

    postgres_exec "$POSTGRES_DEFAULT_DB" -t -c "SELECT 1 FROM pg_database WHERE datname='$db_name';" | \
    grep -q "1"
}

postgres_create_database() {
    local db_name="$1"

    postgres_exec "$POSTGRES_DEFAULT_DB" -c "CREATE DATABASE \"$db_name\";"
}

postgres_drop_database() {
    local db_name="$1"

    postgres_exec "$POSTGRES_DEFAULT_DB" -c "DROP DATABASE IF EXISTS \"$db_name\";"
}

# =============================================================================
# DUMP OPERATIONS
# =============================================================================

postgres_create_dump() {
    local db_name="$1"
    local dump_file="$2"
    local compress="$3"
    local dump_path
    dump_path=$(postgres_dump_path "$dump_file")
    local pg_dump_cmd="PGPASSWORD='$POSTGRES_PASSWORD' pg_dump -h'$POSTGRES_HOST' -U'$POSTGRES_USER' '$db_name'"

    # Ensure dumps directory exists
    postgres_bash_exec "mkdir -p '$POSTGRES_DUMPS_PATH'"
    debug_log "postgres" "Ensured PostgreSQL dumps directory exists: $POSTGRES_DUMPS_PATH"

    print_section "Starting PostgreSQL dump for database: $db_name"

    if [[ "$compress" == "true" ]]; then
        # Create compressed dump
        postgres_bash_exec "$pg_dump_cmd | gzip > '$dump_path'"
    else
        # Create uncompressed dump
        postgres_bash_exec "$pg_dump_cmd > '$dump_path'"
    fi
}

postgres_restore_dump() {
    local dump_file="$1"
    local target_db="$2"

    print_section "Starting PostgreSQL restore for database: $target_db"

    local dump_path
    dump_path=$(postgres_dump_path "$dump_file")

    # Check if dump file exists (in container)
    if ! workspace_exec test -f "$dump_path"; then
        print_error "Dump file not found: $dump_file"
        return 1
    fi

    # Determine if file is compressed and prepare restore command
    local psql_cmd="PGPASSWORD='$POSTGRES_PASSWORD' psql -q -h'$POSTGRES_HOST' -U'$POSTGRES_USER' '$target_db'"

    if [[ "$dump_file" == *.gz ]]; then
        # Restore from compressed dump
        postgres_bash_exec "gunzip -c '$dump_path' | $psql_cmd"
    else
        # Restore from uncompressed dump
        postgres_bash_exec "$psql_cmd < '$dump_path'"
    fi
}

# =============================================================================
# DATABASE ACCESS MANAGEMENT
# =============================================================================

postgres_ensure_database_access() {
    local database="$1"

    debug_log "postgres" "Ensuring database access for: $database"

    # Get all users from PostgreSQL (excluding system users)
    local users=()
    local user

    while IFS= read -r user; do
        users+=("$user")
    done < <(postgres_exec_clean "$POSTGRES_DEFAULT_DB" -t -c "SELECT usename FROM pg_user WHERE usename != 'postgres'" 2>/dev/null || true)

    if [[ ${#users[@]} -eq 0 ]]; then
        debug_log "postgres" "No application users found in PostgreSQL"
        return 0
    fi

    for user in "${users[@]}"; do
        debug_log "postgres" "Granting access to user: $user"
        # GRANT is idempotent - safe to repeat
        postgres_exec "$POSTGRES_DEFAULT_DB" -c "GRANT ALL PRIVILEGES ON DATABASE \"${database}\" TO \"${user}\"" 2>/dev/null || true
        postgres_exec "$database" -c "GRANT ALL PRIVILEGES ON SCHEMA public TO \"${user}\"" 2>/dev/null || true
    done

    debug_log "postgres" "Database access grants completed"
}
