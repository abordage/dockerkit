#!/bin/bash

# =============================================================================
# DEBEZIUM INSTANCE CREATION
# =============================================================================
# Create a new Debezium CDC instance for a PostgreSQL database
# Usage: ./debezium-instance.sh INSTANCE=name DATABASE=db_name [PORT=8080]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export DOCKERKIT_DIR

source "$SCRIPT_DIR/lib/core/base.sh"
source "$SCRIPT_DIR/lib/core/colors.sh"
source "$SCRIPT_DIR/lib/services/debezium.sh"

show_help() {
    cat << 'EOF'
Debezium Instance Creation

USAGE:
    ./debezium-instance.sh INSTANCE=<name> DATABASE=<db_name> [PORT=<port>]
    make debezium-instance INSTANCE=<name> DATABASE=<db_name> [PORT=<port>]

DESCRIPTION:
    Creates a new Debezium Server instance for a PostgreSQL database:
    • debezium/instances/<name>/application.properties
    • debezium/instances/<name>/instance.env (optional port)
    • Regenerates docker-compose.debezium.yml

EXAMPLES:
    make debezium-instance INSTANCE=myapp DATABASE=myapp_db PORT=8081
    make debezium-instance INSTANCE=api DATABASE=api_db

EOF
}

parse_args() {
    local instance="" database="" port=""

    for arg in "$@"; do
        case "$arg" in
            INSTANCE=*) instance="${arg#INSTANCE=}" ;;
            DATABASE=*) database="${arg#DATABASE=}" ;;
            PORT=*) port="${arg#PORT=}" ;;
            -h|--help) show_help; exit 0 ;;
            *)
                print_error "Unknown argument: $arg"
                show_help
                exit "$EXIT_INVALID_INPUT"
                ;;
        esac
    done

    if [ -z "$instance" ] || [ -z "$database" ]; then
        print_error "INSTANCE and DATABASE are required"
        show_help
        exit "$EXIT_INVALID_INPUT"
    fi

    create_debezium_instance "$instance" "$database" "$port"
}

parse_args "$@"
