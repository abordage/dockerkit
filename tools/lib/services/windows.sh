#!/bin/bash

# =============================================================================
# WINDOWS INTEGRATION MANAGER
# =============================================================================
# Functions for managing WSL2 <-> Windows integrations
# Usage: source this file and call Windows integration functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"

source "$BASE_DIR/base.sh"

# Load dependencies
source "$BASE_DIR/utils.sh"
source "$BASE_DIR/colors.sh"

setup_windows_integrations() {
    local os_type
    os_type=$(detect_os)

    if [ "$os_type" != "wsl2" ]; then
        print_warning "Windows integrations are only available on WSL2"
        return "$EXIT_SUCCESS"
    fi

    setup_mkcert_integration

    return "$EXIT_SUCCESS"
}

setup_mkcert_integration() {
    if ! command_exists "mkcert"; then
        print_info "mkcert not installed, skipping Windows certificate sync"
        return "$EXIT_SUCCESS"
    fi

    sync_mkcert_to_windows
}

sync_mkcert_to_windows() {
    local ca_root windows_cert_dir batch_file

    # Get mkcert CA root directory
    ca_root=$(mkcert -CAROOT 2>/dev/null) || {
        print_warning "Failed to get mkcert CA root directory"
        return "$EXIT_SUCCESS"  # Don't fail
    }

    # Windows paths
    windows_cert_dir="/mnt/c/mkcert"
    batch_file="$windows_cert_dir/install-cert.bat"

    # Check if Windows C: drive is accessible
    if [ ! -d "/mnt/c" ]; then
        print_warning "Windows C: drive not accessible from WSL2"
        return "$EXIT_SUCCESS"  # Don't fail
    fi

    # Check if CA certificate exists
    if [ ! -f "$ca_root/rootCA.pem" ]; then
        print_warning "mkcert CA certificate not found"
        print_info "Run 'mkcert -install' first"
        return "$EXIT_SUCCESS"  # Don't fail, just skip
    fi

    # Create Windows certificate directory
    mkdir -p "$windows_cert_dir" || {
        print_warning "Failed to create Windows certificate directory"
        return "$EXIT_SUCCESS"  # Don't fail
    }

    # Copy CA certificate to Windows
    cp "$ca_root/rootCA.pem" "$windows_cert_dir/dockerkit-ca.crt" || {
        print_warning "Failed to copy CA certificate to Windows"
        return "$EXIT_SUCCESS"  # Don't fail
    }

    # Create batch file for certificate installation
    create_windows_install_batch "$batch_file"

    # Show success message
    print_success "CA certificate synced to Windows"

    return "$EXIT_SUCCESS"
}


create_windows_install_batch() {
    local batch_file="$1"

    cat > "$batch_file" << 'EOF'
@echo off
echo Installing DockerKit CA certificate...
echo.

certutil -addstore -user "Root" "%~dp0dockerkit-ca.crt" >nul 2>&1

if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] Certificate installed successfully!
    echo.
    echo DockerKit HTTPS sites will now work without security warnings.
) else (
    echo [ERROR] Failed to install certificate.
    echo.
    echo Try running this batch file as Administrator, or install manually:
    echo 1. Double-click dockerkit-ca.crt
    echo 2. Click "Install Certificate"
    echo 3. Select "Current User" and click "Next"
    echo 4. Select "Place all certificates in the following store"
    echo 5. Click "Browse" and select "Trusted Root Certification Authorities"
    echo 6. Click "Next" and "Finish"
)

echo.
pause
EOF

    return "$EXIT_SUCCESS"
}
