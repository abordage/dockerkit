#!/bin/bash

# =============================================================================
# DOCKERKIT CODE QUALITY CHECKER
# =============================================================================
# Run all linting and quality checks (Dockerfiles, bash scripts, docker-compose)
# Usage: ./lint.sh
# =============================================================================

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export DOCKERKIT_DIR

# Load core libraries
# shellcheck source=lib/core/base.sh
source "$SCRIPT_DIR/lib/core/base.sh"
# shellcheck source=lib/core/colors.sh
source "$SCRIPT_DIR/lib/core/colors.sh"
# shellcheck source=lib/core/utils.sh
source "$SCRIPT_DIR/lib/core/utils.sh"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit "$EXIT_SUCCESS"
                ;;
            --dockerfiles)
                check_dockerfiles_only
                exit "$EXIT_SUCCESS"
                ;;
            --scripts)
                check_scripts_only
                exit "$EXIT_SUCCESS"
                ;;
            --compose)
                check_compose_only
                exit "$EXIT_SUCCESS"
                ;;
            *)
                print_error "Unknown parameter: $1"
                show_help
                exit "$EXIT_GENERAL_ERROR"
                ;;
        esac
    done
}

# Show help
show_help() {
    cat << EOF
DockerKit Code Quality Checker

USAGE:
    ./lint.sh [OPTIONS]

DESCRIPTION:
    Run comprehensive code quality checks including:
    • Dockerfile best practices with hadolint
    • Bash script quality with shellcheck
    • Docker Compose file validation

OPTIONS:
    -h, --help          Show this help message
    --dockerfiles       Check only Dockerfiles
    --scripts           Check only bash scripts
    --compose           Check only docker-compose files

EXAMPLES:
    ./lint.sh                   # Run all checks
    ./lint.sh --dockerfiles     # Check only Dockerfiles
    ./lint.sh --scripts         # Check only bash scripts

TOOLS USED:
    • hadolint - Dockerfile linter
    • shellcheck - Bash script analyzer
    • docker compose config - YAML validation

EOF
}

# Check Dockerfiles with hadolint
check_dockerfiles() {
    print_section "Dockerfile Quality"

    if command -v hadolint >/dev/null 2>&1; then
        local dockerfile_count=0
        local error_count=0

        while IFS= read -r -d '' dockerfile; do
            ((dockerfile_count++))

            if hadolint "$dockerfile" >/dev/null 2>&1; then
                print_success "$(basename "$dockerfile")"
            else
                print_error "$(basename "$dockerfile") - issues found"
                ((error_count++))
                # Show actual errors for failed files
                hadolint "$dockerfile" 2>&1 | sed 's/^/    /'
            fi
        done < <(find . -name "Dockerfile*" -type f ! -path "./.git/*" -print0)

        if [ $dockerfile_count -eq 0 ]; then
            print_error "No Dockerfiles found"
        elif [ $error_count -eq 0 ]; then
            print_success "Quality check passed ($dockerfile_count files)"
        else
            print_error "Quality issues found ($error_count/$dockerfile_count files)"
            return "$EXIT_GENERAL_ERROR"
        fi
    else
        print_error "hadolint not available"
        print_tip "Install: brew install hadolint"
        return "$EXIT_GENERAL_ERROR"
    fi
}

# Check bash scripts with shellcheck
check_bash_scripts() {
    print_section "Bash Script Quality"

    if command -v shellcheck >/dev/null 2>&1; then
        local script_count=0
        local error_count=0
        local scripts=()

        # Find .sh files
        while IFS= read -r -d '' script; do
            scripts+=("$script")
        done < <(find . -name "*.sh" -type f ! -path "./.git/*" -print0)

        # Find executable files with bash shebang
        while IFS= read -r -d '' script; do
            if [[ "$script" != *.sh ]] && head -1 "$script" 2>/dev/null | grep -q "^#!/bin/bash"; then
                scripts+=("$script")
            fi
        done < <(find . -type f -executable ! -path "./.git/*" -print0 2>/dev/null)

        # Check each script
        for script in "${scripts[@]}"; do
            ((script_count++))

            if shellcheck "$script" >/dev/null 2>&1; then
                print_success "$(basename "$script")"
            else
                print_error "$(basename "$script") - issues found"
                ((error_count++))
                # Show actual errors for failed files
                shellcheck "$script" 2>&1 | sed 's/^/    /'
            fi
        done

        if [ $script_count -eq 0 ]; then
            print_error "No bash scripts found"
        elif [ $error_count -eq 0 ]; then
            print_success "Quality check passed ($script_count files)"
        else
            print_error "Quality issues found ($error_count/$script_count files)"
            return "$EXIT_GENERAL_ERROR"
        fi
    else
        print_error "shellcheck not available"
        print_tip "Install: brew install shellcheck"
        return "$EXIT_GENERAL_ERROR"
    fi
}

# Check docker-compose files
check_docker_compose() {
    print_section "Docker Compose Validation"

    if command -v docker >/dev/null 2>&1; then
        local compose_count=0
        local error_count=0

        while IFS= read -r -d '' compose_file; do
            # Skip aliases files as they're meant to extend main compose file
            if [[ "$compose_file" == *"aliases"* ]]; then
                continue
            fi

            ((compose_count++))

            if docker compose -f "$compose_file" config --quiet 2>/dev/null; then
                print_success "$(basename "$compose_file")"
            else
                print_error "$(basename "$compose_file") - validation failed"
                ((error_count++))
                # Show actual errors for failed files
                docker compose -f "$compose_file" config 2>&1 | sed 's/^/    /'
            fi
        done < <(find . \( -name "docker-compose*.yml" -o -name "docker-compose*.yaml" \) -type f ! -path "./.git/*" -print0)

        if [ $compose_count -eq 0 ]; then
            print_error "No docker-compose files found"
        elif [ $error_count -eq 0 ]; then
            print_success "Validation passed ($compose_count files)"
        else
            print_error "Validation failed ($error_count/$compose_count files)"
            return "$EXIT_GENERAL_ERROR"
        fi
    else
        print_error "docker not available"
        print_tip "Install Docker Desktop or docker CLI"
        return "$EXIT_GENERAL_ERROR"
    fi
}

# Individual check functions
check_dockerfiles_only() {
    print_header "DOCKERFILE QUALITY CHECK"
    check_dockerfiles
}

check_scripts_only() {
    print_header "BASH SCRIPT QUALITY CHECK"
    check_bash_scripts
}

check_compose_only() {
    print_header "DOCKER COMPOSE VALIDATION"
    check_docker_compose
}

# Main function
main() {
    print_header "CODE QUALITY CHECKS"

    local overall_status=0

    # Run all checks
    if ! check_dockerfiles; then
        overall_status=1
    fi

    if ! check_bash_scripts; then
        overall_status=1
    fi

    if ! check_docker_compose; then
        overall_status=1
    fi

    # Show final status summary
    print_section "Quality Summary"
    if [ $overall_status -eq 0 ]; then
        print_success "All quality checks passed"
    else
        print_error "Some quality checks failed"
        exit "$EXIT_GENERAL_ERROR"
    fi

    echo ""
}

# Script entry point
parse_arguments "$@"
main
