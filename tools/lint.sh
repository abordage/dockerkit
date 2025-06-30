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
    • Shell configuration files (.bashrc, .bash_aliases)
    • Docker Compose file validation

OPTIONS:
    -h, --help          Show this help message

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

# Discover all bash scripts in the project (optimized single find)
discover_all_scripts() {
    local scripts=()

    while IFS= read -r -d '' file; do
        # .sh files
        if [[ "$file" == *.sh ]]; then
            scripts+=("$file")
            continue
        fi

        # entrypoint.d files with bash shebang
        if [[ "$file" == */entrypoint.d/* ]] && head -1 "$file" 2>/dev/null | grep -q "^#!/bin/bash"; then
            scripts+=("$file")
            continue
        fi

        # workspace shell config files
        if [[ "$file" == */workspace/shell/* ]]; then
            case "$(basename "$file")" in
                .bashrc|.bash_aliases|.bash_profile|.profile)
                    scripts+=("$file")
                    ;;
            esac
            continue
        fi

        # executable files with bash shebang
        if test -x "$file" 2>/dev/null && head -1 "$file" 2>/dev/null | grep -q "^#!/bin/bash"; then
            scripts+=("$file")
        fi
    done < <(find . -type f ! -path "./.git/*" -print0 2>/dev/null)

    # Output all discovered scripts
    printf '%s\n' "${scripts[@]}"
}

# Check bash scripts with shellcheck
check_bash_scripts() {
    print_section "Bash Script Quality"

    if command -v shellcheck >/dev/null 2>&1; then
        local script_count=0
        local error_count=0
        local scripts=()

        # Discover all scripts using unified function - compatible with older bash
        while IFS= read -r script; do
            [ -n "$script" ] && scripts+=("$script")
        done < <(discover_all_scripts)

        # Sort scripts alphabetically by filename
        if [ ${#scripts[@]} -gt 0 ]; then
            local sorted_scripts=()
            while IFS=':' read -r _basename fullpath; do
                sorted_scripts+=("$fullpath")
            done < <(for script in "${scripts[@]}"; do echo "$(basename "$script"):$script"; done | sort)

            scripts=("${sorted_scripts[@]}")
        fi

        # Check each script
        if [ ${#scripts[@]} -gt 0 ]; then
            for script in "${scripts[@]}"; do
            ((script_count++))

            # Run shellcheck and capture exit status
            shellcheck "$script" >/dev/null 2>&1
            local shellcheck_status=$?

            if [ $shellcheck_status -eq 0 ]; then
                print_success "$(basename "$script")"
            else
                print_error "$(basename "$script") - issues found"
                ((error_count++))
                # Show actual errors for failed files
                shellcheck "$script" 2>&1 | sed 's/^/    /' || true
            fi
        done
        fi

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

# Main function
main() {
    # Parse help argument
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit "$EXIT_SUCCESS"
    fi

    print_header "CODE QUALITY CHECKS"

    local overall_status="$EXIT_SUCCESS"

    # Run all checks
    if ! check_dockerfiles; then
        overall_status="$EXIT_GENERAL_ERROR"
    fi

    if ! check_docker_compose; then
        overall_status="$EXIT_GENERAL_ERROR"
    fi

    if ! check_bash_scripts; then
        overall_status="$EXIT_GENERAL_ERROR"
    fi

    # Show final status summary
    print_section "Quality Summary"
    if [ "$overall_status" -eq "$EXIT_SUCCESS" ]; then
        print_success "All quality checks passed"
    else
        print_error "Some quality checks failed"
        exit "$overall_status"
    fi

    echo ""
}

# Script entry point
main "$@"
