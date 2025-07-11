#!/bin/bash

# =============================================================================
# GIT CONFIGURATION MANAGEMENT
# =============================================================================
# Functions for managing git configuration in DockerKit environment
# =============================================================================

# Generate git configuration file for workspace container
generate_git_config() {
    local git_config_file="$DOCKERKIT_DIR/workspace/.gitconfig"

    if [[ -f "$git_config_file" ]]; then
        return 0
    fi

    # Get settings from host git config
    local host_name host_email
    host_name=$(git config --global --get user.name 2>/dev/null || echo "")
    host_email=$(git config --global --get user.email 2>/dev/null || echo "")

    # Fallback values with dockerkit
    if [[ -z "$host_name" ]]; then
        host_name="DockerKit Developer"
    fi

    if [[ -z "$host_email" ]]; then
        host_email="developer@dockerkit.local"
    fi

    # Create .gitconfig file
    cat > "$git_config_file" << EOF
[user]
	email = $host_email
	name = $host_name
[core]
	autocrlf = input
EOF

    print_success "Git configuration generated: $host_name <$host_email>"
    return 0
}
