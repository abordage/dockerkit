#!/bin/bash

# =============================================================================
# MYSQL DATABASE DRIVER
# =============================================================================
# MySQL database operations using Docker containers
# =============================================================================

# =============================================================================
# CONSTANTS
# =============================================================================

readonly MYSQL_HOST="mysql"
readonly MYSQL_USER="root"
readonly MYSQL_PASSWORD="${MYSQL_ROOT_PASSWORD:-root}"
readonly MYSQL_DEFAULT_DB="mysql"
readonly MYSQL_SYSTEM_DBS="information_schema|performance_schema|mysql|sys"
readonly MYSQL_DUMPS_PATH="/dumps/mysql"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

mysql_exec() {
    local database="${1:-$MYSQL_DEFAULT_DB}"
    shift

    debug_log "mysql" "Executing MySQL command on database '$database' with args: $*"
    debug_log "mysql" "Full command: mysql -h'$MYSQL_HOST' -u'$MYSQL_USER' -p'***' -D'$database' --skip-ssl $*"

    workspace_exec mysql \
        -h"$MYSQL_HOST" \
        -u"$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        -D"$database" \
        --skip-ssl \
        "$@" 2>/dev/null
}

mysql_bash_exec() {
    workspace_exec bash -c "$1" 2>/dev/null
}

mysql_dump_path() {
    local dump_file="$1"
    echo "$MYSQL_DUMPS_PATH/$dump_file"
}

# =============================================================================
# CONNECTION FUNCTIONS
# =============================================================================

mysql_test_connection() {
    debug_log "mysql" "Testing MySQL connection to host=$MYSQL_HOST, user=$MYSQL_USER, database=$MYSQL_DEFAULT_DB"

    # Test workspace container accessibility
    debug_log "mysql" "Checking workspace container accessibility"
    if ! workspace_exec echo "workspace test" >/dev/null 2>&1; then
        debug_log "mysql" "ERROR: Workspace container is not accessible"
        return 1
    fi
    debug_log "mysql" "Workspace container is accessible"

    # Test MySQL connection directly (MySQL service should be accessible by name from workspace)
    debug_log "mysql" "Testing MySQL connection with query: SELECT 1"
    if mysql_exec "$MYSQL_DEFAULT_DB" --connect-timeout=5 -e "SELECT 1;" >/dev/null; then
        debug_log "mysql" "MySQL connection test successful"
        return 0
    else
        debug_log "mysql" "ERROR: MySQL connection test failed - check MySQL service is running"
        return 1
    fi
}

# =============================================================================
# DATABASE MANAGEMENT
# =============================================================================

mysql_list_databases() {
    mysql_exec "$MYSQL_DEFAULT_DB" -s -N -e "SHOW DATABASES;" | \
    grep -v -E "^($MYSQL_SYSTEM_DBS)$"
}

mysql_database_exists() {
    local db_name="$1"

    mysql_exec "$MYSQL_DEFAULT_DB" -s -N -e "SHOW DATABASES LIKE '$db_name';" | \
    grep -q "^$db_name$"
}

mysql_create_database() {
    local db_name="$1"

    mysql_exec "$MYSQL_DEFAULT_DB" -e "CREATE DATABASE \`$db_name\`;"
}

mysql_drop_database() {
    local db_name="$1"

    mysql_exec "$MYSQL_DEFAULT_DB" -e "DROP DATABASE IF EXISTS \`$db_name\`;"
}

# =============================================================================
# DUMP OPERATIONS
# =============================================================================

mysql_create_dump() {
    local db_name="$1"
    local dump_file="$2"
    local compress="$3"
    local dump_path
    dump_path=$(mysql_dump_path "$dump_file")
    local mysqldump_cmd="mysqldump -h'$MYSQL_HOST' -u'$MYSQL_USER' -p'$MYSQL_PASSWORD' --skip-ssl --single-transaction --routines --triggers '$db_name'"

    # Ensure dumps directory exists
    mysql_bash_exec "mkdir -p '$MYSQL_DUMPS_PATH'"
    debug_log "mysql" "Ensured MySQL dumps directory exists: $MYSQL_DUMPS_PATH"

    print_section "Starting MySQL dump for database: $db_name"

    if [[ "$compress" == "true" ]]; then
        # Create compressed dump
        mysql_bash_exec "$mysqldump_cmd | gzip > '$dump_path'"
    else
        # Create uncompressed dump
        mysql_bash_exec "$mysqldump_cmd > '$dump_path'"
    fi
}

mysql_restore_dump() {
    local dump_file="$1"
    local target_db="$2"

    print_section "Starting MySQL restore for database: $target_db"

    local dump_path
    dump_path=$(mysql_dump_path "$dump_file")

    # Check if dump file exists (in container)
    if ! workspace_exec test -f "$dump_path"; then
        print_error "Dump file not found: $dump_file"
        return 1
    fi

    # Determine if file is compressed and prepare restore command
    local mysql_cmd="mysql -h'$MYSQL_HOST' -u'$MYSQL_USER' -p'$MYSQL_PASSWORD' --skip-ssl '$target_db'"

    if [[ "$dump_file" == *.gz ]]; then
        # Restore from compressed dump
        mysql_bash_exec "gunzip -c '$dump_path' | $mysql_cmd"
    else
        # Restore from uncompressed dump
        mysql_bash_exec "$mysql_cmd < '$dump_path'"
    fi
}

# =============================================================================
# DATABASE ACCESS MANAGEMENT
# =============================================================================

mysql_ensure_database_access() {
    local database="$1"

    debug_log "mysql" "Ensuring database access for: $database"

    # Get all users from MySQL (excluding system users)
    local users=()
    local user

    while IFS= read -r user; do
        users+=("$user")
    done < <(mysql_exec "$MYSQL_DEFAULT_DB" -s -N -e "SELECT DISTINCT User FROM mysql.user WHERE User != 'root' AND User != '' AND User != 'mysql.session' AND User != 'mysql.sys'" 2>/dev/null || true)

    if [[ ${#users[@]} -eq 0 ]]; then
        debug_log "mysql" "No application users found in MySQL"
        return 0
    fi

    for user in "${users[@]}"; do
        debug_log "mysql" "Granting access to user: $user"
        # GRANT is idempotent - safe to repeat
        mysql_exec "$MYSQL_DEFAULT_DB" -e "GRANT ALL PRIVILEGES ON \`${database}\`.* TO '${user}'@'%'" 2>/dev/null || true
    done

    # Flush privileges
    mysql_exec "$MYSQL_DEFAULT_DB" -e "FLUSH PRIVILEGES" 2>/dev/null || true
    debug_log "mysql" "Database access grants completed"
}
