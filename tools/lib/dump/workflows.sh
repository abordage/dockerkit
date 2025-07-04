#!/bin/bash

# =============================================================================
# DUMP WORKFLOWS
# =============================================================================
# Business logic for database export and import operations
# =============================================================================

create_dump_with_compression() {
    local driver="$1"
    local db_name="$2"
    local dump_file="$3"
    local compress="$4"

    print_success "Database: $db_name"
    print_success "File: $dump_file"

   if [[ "$compress" == "true" ]]; then
       print_success "Compression: enabled"
   else
       print_success "Compression: disabled"
   fi

    "${driver}_create_dump" "$db_name" "$dump_file" "$compress"
}

restore_dump_file() {
    local driver="$1"
    local dump_file="$2"
    local target_db="$3"

    print_success "Dump file: $dump_file"
    print_success "Target database: $target_db"

    "${driver}_restore_dump" "$dump_file" "$target_db"
}

find_dump_files() {
    local driver="$1"
    local dumps_dir="/dumps/$driver"

    # Find all SQL dump files and sort by modification time (newest first)
    workspace_exec bash -c "
        files=\$(find '$dumps_dir' -name '*.sql' -o -name '*.sql.gz' 2>/dev/null)
        if [ -n \"\$files\" ]; then
            echo \"\$files\" | xargs ls -t 2>/dev/null
        fi
    "
}

# =============================================================================
# EXPORT WORKFLOW
# =============================================================================

run_export_workflow() {
    local db_type="$1"
    local driver
    driver=$(get_db_driver "$db_type")

    # Validate database type
    validate_db_type "$db_type" || exit "$EXIT_INVALID_INPUT"

    # Test database connection
    if ! "${driver}_test_connection"; then
        print_section "Starting $db_type export workflow"
        print_error "Cannot connect to $db_type database"
        print_tip "Check that $db_type container is running and accessible"
        exit "$EXIT_CONNECTION_ERROR"
    fi

    # Get available databases
    local databases=()
    local db_name

    while IFS= read -r db_name; do
        databases+=("$db_name")
    done < <("${driver}_list_databases")

    if [[ ${#databases[@]} -eq 0 ]]; then
        print_section "Starting $db_type export workflow"
        print_error "No databases found in $db_type"
        exit "$EXIT_GENERAL_ERROR"
    fi

    # Select source database
    local selected_db
    selected_db=$(select_source_database "${databases[@]}")

    # Configure dump options
    local compress
    compress=$(ask_compression)

    # Generate dump filename
    local dump_file
    dump_file=$(generate_dump_filename "$driver" "$selected_db" "$compress")

    # Create dump
    print_section "Params"

    if create_dump_with_compression "$driver" "$selected_db" "$dump_file" "$compress"; then
        print_success "Dump created successfully: dumps/$driver/$dump_file"
    else
        print_error "Failed to create dump"
        exit "$EXIT_GENERAL_ERROR"
    fi
}

select_source_database() {
    local databases=("$@")

    input_menu "Select database to dump:" "${databases[@]}"
}

ask_compression() {
    if input_yesno "Do you want to compress the dump with Gzip?" "y"; then
        echo "true"
    else
        echo "false"
    fi
}

# =============================================================================
# IMPORT WORKFLOW
# =============================================================================

run_import_workflow() {
    local db_type="$1"
    local driver
    driver=$(get_db_driver "$db_type")

    # Validate database type
    validate_db_type "$db_type" || exit "$EXIT_INVALID_INPUT"

    # Test database connection
    if ! "${driver}_test_connection"; then
        print_error "Cannot connect to $db_type database"
        print_tip "Check that $db_type container is running and accessible"
        exit "$EXIT_CONNECTION_ERROR"
    fi

    # Select dump file
    local dump_file
    dump_file=$(select_dump_file "$driver")

    # Select target database
    local target_db
    target_db=$(select_target_database "$driver")

    # Restore dump
    print_section "Params"

    if restore_dump_file "$driver" "$dump_file" "$target_db"; then
        print_success "Dump restored successfully to: $target_db"
    else
        print_error "Failed to restore dump"
        exit "$EXIT_GENERAL_ERROR"
    fi
}

select_dump_file() {
    local driver="$1"

    # Find dump files for this database type
    local dump_files=()
    local dump_file

    while IFS= read -r dump_file; do
        dump_files+=("$dump_file")
    done < <(find_dump_files "$driver")

    if [[ ${#dump_files[@]} -eq 0 ]]; then
        print_error "No dump files found for $driver"
        print_tip "Create a dump first or place dump files in: dumps/"
        exit "$EXIT_FILE_NOT_FOUND"
    fi

    # Convert full paths to relative names for display
    local dump_options=()
    for file in "${dump_files[@]}"; do
        local basename
        basename=$(basename "$file")
        dump_options+=("$basename")
    done

    # Select dump file
    local selected_dump
    selected_dump=$(input_menu "Select dump file to restore:" "${dump_options[@]}")

    echo "$selected_dump"
}

select_target_database() {
    local driver="$1"

    # Ask whether to restore to existing or new database
    if input_yesno "Do you want to restore to an EXISTING database?" "y"; then
        # Restore to existing database
        select_existing_database "$driver"
    else
        # Create new database
        create_new_database "$driver"
    fi
}

select_existing_database() {
    local driver="$1"

    local databases=()
    local db_name

    while IFS= read -r db_name; do
        databases+=("$db_name")
    done < <("${driver}_list_databases")

    if [[ ${#databases[@]} -eq 0 ]]; then
        print_error "No existing databases found"
        print_tip "Create a database first or choose to create a new one"
        exit "$EXIT_GENERAL_ERROR"
    fi

    input_menu "Select target database:" "${databases[@]}"
}

create_new_database() {
    local driver="$1"

    local db_name
    db_name=$(input_database_name "Enter name for the NEW database: ")

    # Check if database already exists
    if "${driver}_database_exists" "$db_name"; then
        if input_yesno "Database '$db_name' already exists. Do you want to drop and recreate it?" "y"; then
            if ! "${driver}_drop_database" "$db_name"; then
                print_error "Failed to drop existing database: $db_name"
                exit "$EXIT_GENERAL_ERROR"
            fi
        else
            print_error "Database already exists and user chose not to recreate it"
            exit "$EXIT_GENERAL_ERROR"
        fi
    fi

    # Create database
    if "${driver}_create_database" "$db_name" >/dev/null; then
        # Ensure database access for application users
        "${driver}_ensure_database_access" "$db_name"
        echo "$db_name"
    else
        print_error "Failed to create database: $db_name"
        exit "$EXIT_GENERAL_ERROR"
    fi
}
