#!/bin/bash

# ============================================================================
# RABBITMQ ENTRYPOINT SCRIPT
# ============================================================================
# Starts RabbitMQ server and configures legacy users
# Handles ENV user creation and legacy user setup
# ============================================================================
set -euo pipefail

# Color output functions
log_ok() { echo -e "[$SCRIPT_NAME] \033[32m[OK]\033[0m $*"; }
log_warn() { echo -e "[$SCRIPT_NAME] \033[93m[WARN]\033[0m $*"; }
log_error() { echo -e "[$SCRIPT_NAME] \033[31m[ERROR]\033[0m $*"; }
log_info() { echo "[$SCRIPT_NAME] $*"; }
log_skip() { echo -e "[$SCRIPT_NAME] \033[36m[SKIP]\033[0m $*"; }

SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_NAME

# RabbitMQ configuration
readonly RABBITMQ_STARTUP_TIMEOUT=60
readonly LEGACY_USERS=("guest" "admin" "default")

# ============================================================================
# PREREQUISITES AND SETUP
# ============================================================================

setup_permissions() {
    log_info "Setting up RabbitMQ permissions..."

    if [ "$(id -u)" = '0' ]; then
        find /var/lib/rabbitmq \! -user rabbitmq -exec chown rabbitmq '{}' +
        log_ok "RabbitMQ permissions fixed"
    else
        log_info "Running as non-root user, skipping permission fix"
    fi
}

run_rabbitmqctl() {
    if [ "$(id -u)" = '0' ]; then
        gosu rabbitmq rabbitmqctl "$@"
    else
        rabbitmqctl "$@"
    fi
}

# ============================================================================
# RABBITMQ SERVER STARTUP
# ============================================================================

start_rabbitmq_server() {
    log_info "Starting RabbitMQ server in background..."

    # Start RabbitMQ server in background
    /usr/local/bin/docker-entrypoint.sh rabbitmq-server &
    RABBITMQ_PID=$!

    log_ok "RabbitMQ server started with PID: $RABBITMQ_PID"
    return 0
}

# ============================================================================
# SERVER READINESS CHECK
# ============================================================================

wait_for_rabbitmq_ready() {
    log_info "Waiting for RabbitMQ to be fully ready..."

    local timeout=$RABBITMQ_STARTUP_TIMEOUT
    local attempt=1
    local max_attempts=$((timeout / 2))

    while [ $timeout -gt 0 ]; do
        if run_rabbitmqctl await_startup >/dev/null 2>&1 && run_rabbitmqctl status >/dev/null 2>&1; then
            log_ok "RabbitMQ is fully ready (took $((attempt * 2)) seconds)"
            return 0
        fi

        if [ $((attempt % 15)) -eq 0 ]; then  # Log every 30 seconds
            log_info "Still waiting... ($timeout seconds remaining, attempt $attempt/$max_attempts)"
        fi

        sleep 2
        timeout=$((timeout - 2))
        attempt=$((attempt + 1))
    done

    log_error "RabbitMQ failed to start within $RABBITMQ_STARTUP_TIMEOUT seconds"
    return 1
}

# ============================================================================
# VIRTUAL HOST SETUP
# ============================================================================

setup_default_vhost() {
    log_info "Setting up default virtual host..."

    if run_rabbitmqctl add_vhost / >/dev/null 2>&1; then
        log_ok "Default virtual host '/' created"
    else
        log_skip "Virtual host '/' already exists"
    fi

    return 0
}

# ============================================================================
# USER MANAGEMENT
# ============================================================================

create_legacy_user() {
    local username="$1"
    local password="$2"

    # Create user
    if run_rabbitmqctl add_user "$username" "$password" >/dev/null 2>&1; then
        log_ok "Legacy user '$username' created"
    else
        log_skip "User '$username' already exists"
    fi

    # Set administrator tags
    if run_rabbitmqctl set_user_tags "$username" administrator >/dev/null 2>&1; then
        log_info "Set administrator tags for user '$username'"
    else
        log_warn "Failed to set administrator tags for user '$username'"
    fi

    # Set permissions
    if run_rabbitmqctl set_permissions -p / "$username" '.*' '.*' '.*' >/dev/null 2>&1; then
        log_info "Set full permissions for user '$username'"
    else
        log_warn "Failed to set permissions for user '$username'"
    fi

    return 0
}

setup_legacy_users() {
    log_info "Setting up legacy users..."

    local created_count=0

    for username in "${LEGACY_USERS[@]}"; do
        if create_legacy_user "$username" "$username"; then
            created_count=$((created_count + 1))
        fi
    done

    log_ok "Legacy user setup completed ($created_count users processed)"
    return 0
}

# Check if ENV user was created automatically
check_env_user() {
    if [[ -n "${RABBITMQ_DEFAULT_USER:-}" ]]; then
        if run_rabbitmqctl list_users | grep -q "^${RABBITMQ_DEFAULT_USER}[[:space:]]"; then
            log_ok "ENV user '${RABBITMQ_DEFAULT_USER}' automatically created"
        else
            log_warn "ENV user '${RABBITMQ_DEFAULT_USER}' was not created automatically"
        fi
    else
        log_info "No RABBITMQ_DEFAULT_USER environment variable set"
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log_info "Starting RabbitMQ configuration and user setup..."

    # Step 1: Setup permissions
    if ! setup_permissions; then
        log_error "Failed to setup permissions"
        return 1
    fi

    # Step 2: Start RabbitMQ server
    if ! start_rabbitmq_server; then
        log_error "Failed to start RabbitMQ server"
        return 1
    fi

    # Step 3: Wait for readiness
    if ! wait_for_rabbitmq_ready; then
        log_error "RabbitMQ startup timeout exceeded"
        return 1
    fi

    # Step 4: Setup virtual host
    if ! setup_default_vhost; then
        log_warn "Virtual host setup failed, continuing..."
    fi

    # Step 5: Check ENV user
    check_env_user

    # Step 6: Setup legacy users
    if ! setup_legacy_users; then
        log_warn "Legacy user setup failed, continuing..."
    fi

    log_info "RabbitMQ configuration completed successfully"
    echo ""

    # Step 7: Wait for RabbitMQ process
    log_info "Waiting for RabbitMQ server process..."
    wait $RABBITMQ_PID
}

# Execute main function
main "$@"
