#!/bin/bash

# =============================================================================
# PACKAGE MANAGER
# =============================================================================
# Functions for managing system packages and dependencies
# Usage: source this file and call package management functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"

source "$BASE_DIR/base.sh"

# Load dependencies
PKG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$PKG_SCRIPT_DIR/../core/utils.sh"
source "$PKG_SCRIPT_DIR/../core/config.sh"

check_system_dependencies() {
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        macos|linux|wsl2)
            check_required_tools
            ;;
        *)
            print_warning "Unsupported operating system: $os_type"
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

check_required_tools() {
    local required_tools=("mkcert")
    local all_ok=true

    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            print_info "$tool: Not found, installing..."
            if ! install_missing_tool "$tool"; then
                print_error "$tool: Installation failed"
                all_ok=false
            else
                print_success "$tool: Installed successfully"
            fi
        else
            print_success "$tool: Already installed"
        fi
    done

    if [ "$all_ok" = false ]; then
        return "$EXIT_GENERAL_ERROR"
    fi

    # WSL2: sync mkcert to Windows
    if [ "$(detect_os)" = "wsl2" ] && command_exists "mkcert"; then
        sync_mkcert_to_windows
    fi

    return "$EXIT_SUCCESS"
}

install_missing_tool() {
    local tool_name="$1"
    local os_type
    os_type=$(detect_os)

    case "$tool_name" in
        mkcert)
            install_mkcert_for_platform "$os_type"
            ;;
        *)
            print_error "Unknown tool: $tool_name"
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

install_mkcert_for_platform() {
    local os_type="$1"

    case "$os_type" in
        linux|wsl2)
            install_mkcert_linux
            ;;
        macos)
            install_mkcert_macos_stub
            ;;
        *)
            print_error "Unsupported platform for mkcert installation: $os_type"
            return "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

install_mkcert_linux() {
    local temp_dir="/tmp/mkcert-install"
    local mkcert_url="https://dl.filippo.io/mkcert/latest?for=linux/amd64"
    local install_path="/usr/local/bin/mkcert"

    # Check sudo access
    if ! check_sudo_access; then
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    # Create temporary directory
    mkdir -p "$temp_dir" || {
        print_error "Failed to create temporary directory"
        return "$EXIT_GENERAL_ERROR"
    }

    # Download mkcert
    print_info "Downloading mkcert latest version..."
    if ! curl "$mkcert_url" -o "$temp_dir/mkcert"; then
        print_error "Failed to download mkcert"
        rm -rf "$temp_dir" 2>/dev/null || true
        return "$EXIT_GENERAL_ERROR"
    fi

    # Set executable permissions and move to install path
    chmod +x "$temp_dir/mkcert" || {
        rm -rf "$temp_dir" 2>/dev/null || true
        return "$EXIT_GENERAL_ERROR"
    }

    sudo mv "$temp_dir/mkcert" "$install_path" || {
        rm -rf "$temp_dir" 2>/dev/null || true
        return "$EXIT_GENERAL_ERROR"
    }

    # Verify installation
    if ! command_exists "mkcert"; then
        print_error "mkcert installation verification failed"
        rm -rf "$temp_dir" 2>/dev/null || true
        return "$EXIT_GENERAL_ERROR"
    fi

    # Clean up temporary files
    rm -rf "$temp_dir" 2>/dev/null || true

    return "$EXIT_SUCCESS"
}

install_mkcert_macos_stub() {
    print_warning "Automatic mkcert installation for macOS not implemented yet"
    print_tip "Please install mkcert manually:"
    print_tip "  brew install mkcert"

    return "$EXIT_MISSING_DEPENDENCY"
}

check_sudo_access() {
    if sudo -n true 2>/dev/null; then
        return "$EXIT_SUCCESS"
    else
        print_info "sudo access required for mkcert installation"
        print_tip "Please enter your password when prompted"
        # Try sudo with password prompt
        if sudo true 2>/dev/null; then
            return "$EXIT_SUCCESS"
        else
            print_error "sudo access denied"
            return "$EXIT_PERMISSION_DENIED"
        fi
    fi
}

sync_mkcert_to_windows() {
    local windows_drive="/mnt/c"
    local windows_cert_dir="$windows_drive/mkcert"
    local ca_root
    local batch_file="$windows_cert_dir/install-cert.bat"

    # Check if Windows drive is accessible
    if [ ! -d "$windows_drive" ]; then
        print_warning "Windows drive not accessible at $windows_drive"
        print_info "Skipping Windows integration"
        return "$EXIT_SUCCESS"  # Don't fail, just skip
    fi

    # Get mkcert CA root directory
    ca_root=$(mkcert -CAROOT 2>/dev/null)
    if [ -z "$ca_root" ] || [ ! -f "$ca_root/rootCA.pem" ]; then
        print_warning "mkcert CA certificate not found"
        print_info "Run 'mkcert -install' first"
        return "$EXIT_SUCCESS"  # Don't fail, just skip
    fi

    # Check if sync is needed
    if ! needs_windows_sync "$ca_root/rootCA.pem" "$windows_cert_dir/dockerkit-ca.crt"; then
        print_info "Windows certificate is up to date"
        return "$EXIT_SUCCESS"
    fi

    print_info "Syncing mkcert certificate to Windows..."

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
    print_info "Location: C:\\mkcert\\dockerkit-ca.crt"
    print_tip "Run C:\\mkcert\\install-cert.bat to install certificate in Windows"

    return "$EXIT_SUCCESS"
}

needs_windows_sync() {
    local source_cert="$1"
    local target_cert="$2"

    # If target doesn't exist, sync is needed
    if [ ! -f "$target_cert" ]; then
        return 0  # true - sync needed
    fi

    # Compare file sizes (quick check)
    local source_size target_size
    source_size=$(stat -f%z "$source_cert" 2>/dev/null || stat -c%s "$source_cert" 2>/dev/null)
    target_size=$(stat -f%z "$target_cert" 2>/dev/null || stat -c%s "$target_cert" 2>/dev/null)

    if [ "$source_size" != "$target_size" ]; then
        return 0  # true - sync needed
    fi

    # Files appear to be the same
    return 1  # false - sync not needed
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


