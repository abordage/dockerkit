#!/bin/bash
set -euo pipefail

# ============================================================================
# DOCKERKIT PHP-FPM ENTRYPOINT
# ============================================================================
# Main entrypoint script for DockerKit php-fpm container
# Handles user switching, shell modes, and initialization scripts
# ============================================================================

# Print DockerKit header (moved from 01-welcome)
print_dockerkit_header() {
    echo ""
    cat << 'EOF'
$$$$$$$\                      $$\                           $$\   $$\ $$\   $$\
$$  __$$\                     $$ |                          $$ | $$  |\__|  $$ |
$$ |  $$ | $$$$$$\   $$$$$$$\ $$ |  $$\  $$$$$$\   $$$$$$\  $$ |$$  / $$\ $$$$$$\
$$ |  $$ |$$  __$$\ $$  _____|$$ | $$  |$$  __$$\ $$  __$$\ $$$$$  /  $$ |\_$$  _|
$$ |  $$ |$$ /  $$ |$$ /      $$$$$$  / $$$$$$$$ |$$ |  \__|$$  $$<   $$ |  $$ |
$$ |  $$ |$$ |  $$ |$$ |      $$  _$$<  $$   ____|$$ |      $$ |\$$\  $$ |  $$ |$$\
$$$$$$$  |\$$$$$$  |\$$$$$$$\ $$ | \$$\ \$$$$$$$\ $$ |      $$ | \$$\ $$ |  \$$$$  |
\_______/  \______/  \_______|\__|  \__| \_______|\__|      \__|  \__|\__|   \____/
EOF
    echo ""
    echo "Starting DockerKit pho-fpm container..."
    echo "Working directory: $(pwd)"
    echo "User: $(whoami) (UID: $(id -u))"
    echo ""
}

run_entrypoint_scripts() {
    if [ -d "/entrypoint.d" ]; then
        echo "Running initialization scripts from /entrypoint.d/..."
        run-parts --exit-on-error /entrypoint.d/
        echo "Initialization scripts completed successfully."
    fi
}

main() {
    print_dockerkit_header
    run_entrypoint_scripts

    if [ $# -eq 0 ]; then
        set -- bash
    fi

    if [ "$(id -u)" = '0' ]; then
        exec gosu dockerkit "$@"
    else
        exec "$@"
    fi
}

main "$@"
