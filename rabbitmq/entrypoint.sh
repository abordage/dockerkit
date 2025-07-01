#!/bin/bash
set -eo pipefail

# Logic from official docker-entrypoint.sh - fix permissions if running as root
if [ "$(id -u)" = '0' ]; then
    find /var/lib/rabbitmq \! -user rabbitmq -exec chown rabbitmq '{}' +
fi

# Start RabbitMQ server in background
/usr/local/bin/docker-entrypoint.sh rabbitmq-server &
RABBITMQ_PID=$!

# Function to run rabbitmqctl as rabbitmq user
run_rabbitmqctl() {
    if [ "$(id -u)" = '0' ]; then
        gosu rabbitmq rabbitmqctl "$@"
    else
        rabbitmqctl "$@"
    fi
}

# Wait for RabbitMQ to be fully ready
echo "[INFO] Waiting for RabbitMQ to be fully ready..."
timeout=60
while [ $timeout -gt 0 ]; do
    if run_rabbitmqctl await_startup >/dev/null 2>&1 && run_rabbitmqctl status >/dev/null 2>&1; then
        echo "[INFO] RabbitMQ is fully ready"
        break
    fi
    echo "[INFO] Waiting... ($timeout seconds remaining)"
    sleep 2
    timeout=$((timeout - 2))
done

if [ $timeout -le 0 ]; then
    echo "[ERROR] RabbitMQ failed to start within timeout"
    exit 1
fi

# Create default virtual host if it doesn't exist
echo "[INFO] Creating default virtual host..."
run_rabbitmqctl add_vhost / 2>/dev/null || echo "[INFO] Virtual host '/' already exists"

# Create legacy users
echo "[INFO] Creating legacy users..."

# Guest user
run_rabbitmqctl add_user guest guest 2>/dev/null || echo "[INFO] User 'guest' already exists"
run_rabbitmqctl set_user_tags guest administrator
run_rabbitmqctl set_permissions -p / guest '.*' '.*' '.*'

# Admin user
run_rabbitmqctl add_user admin admin 2>/dev/null || echo "[INFO] User 'admin' already exists"
run_rabbitmqctl set_user_tags admin administrator
run_rabbitmqctl set_permissions -p / admin '.*' '.*' '.*'

# Default user
run_rabbitmqctl add_user default default 2>/dev/null || echo "[INFO] User 'default' already exists"
run_rabbitmqctl set_user_tags default administrator
run_rabbitmqctl set_permissions -p / default '.*' '.*' '.*'

echo "[INFO] Legacy users created successfully"

# Wait for RabbitMQ process
wait $RABBITMQ_PID
