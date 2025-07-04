#!/bin/bash

# =============================================================================
# SSL MANAGER
# =============================================================================
# Functions for managing SSL certificates with mkcert
# Usage: source this file and call SSL management functions
# =============================================================================

set -euo pipefail

# Load base functionality
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"

source "$BASE_DIR/base.sh"

# Load dependencies
SSL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SSL_SCRIPT_DIR/../core/utils.sh"
source "$SSL_SCRIPT_DIR/../core/config.sh"
source "$SSL_SCRIPT_DIR/../core/validation.sh"

initialize_ssl_environment() {
    if ! command_exists "mkcert"; then
        print_error "mkcert is required but not installed"
        print_tip "Run dependency installation first"
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    # Create SSL directories if they don't exist
    local ssl_dir="${DOCKERKIT_DIR}/${NGINX_SSL_DIR}"
    local ssl_ca_dir="${DOCKERKIT_DIR}/${SSL_CA_DIR:-ssl-ca}"
    ensure_project_directory "$NGINX_SSL_DIR"
    ensure_project_directory "${SSL_CA_DIR:-ssl-ca}"

    # Install CA if not already done
    if ! is_ca_installed; then
        install_ca
    else
        print_success "Certificate Authority already installed"
    fi

    # Copy root certificates to SSL CA directory
    copy_root_certificates
}

is_ca_installed() {
    if mkcert -CAROOT >/dev/null 2>&1; then
        local ca_root
        ca_root=$(mkcert -CAROOT)

        if [ -f "$ca_root/rootCA.pem" ] && [ -f "$ca_root/rootCA-key.pem" ]; then
            return "$EXIT_SUCCESS"
        fi
    fi

    return "$EXIT_GENERAL_ERROR"
}

install_ca() {
    print_info "Installing Certificate Authority..."



    if mkcert -install; then
        print_success "Certificate Authority installed successfully"

        local ca_root
        ca_root=$(mkcert -CAROOT)
        print_info "CA Root: $ca_root"
    else
        print_error "Failed to install Certificate Authority"
        return "$EXIT_GENERAL_ERROR"
    fi
}

copy_root_certificates() {
    local ssl_ca_dir="${DOCKERKIT_DIR}/${SSL_CA_DIR:-ssl-ca}"

    if ! command_exists "mkcert"; then
        print_warning "mkcert not available, skipping root certificate copy"
        return "$EXIT_GENERAL_ERROR"
    fi

    local ca_root
    ca_root=$(mkcert -CAROOT 2>/dev/null)

    if [ -z "$ca_root" ] || [ ! -d "$ca_root" ]; then
        print_warning "mkcert CA root directory not found"
        return "$EXIT_GENERAL_ERROR"
    fi

    # Copy root CA certificate and key to SSL CA directory
    if [ -f "$ca_root/rootCA.pem" ]; then
        cp "$ca_root/rootCA.pem" "$ssl_ca_dir/rootCA.crt" 2>/dev/null || true
        print_success "Root CA certificate copied to SSL CA directory"
    fi

    if [ -f "$ca_root/rootCA-key.pem" ]; then
        cp "$ca_root/rootCA-key.pem" "$ssl_ca_dir/rootCA.key" 2>/dev/null || true
        print_success "Root CA key copied to SSL CA directory"
    fi
}

generate_ssl_certificates() {
    local sites=("$@")

    if [ ${#sites[@]} -eq 0 ]; then
        print_warning "No sites provided for SSL certificate generation"
        return "$EXIT_GENERAL_ERROR"
    fi

    if ! command_exists "mkcert"; then
        print_error "mkcert is required but not installed"
        return "$EXIT_MISSING_DEPENDENCY"
    fi

    local ssl_dir="${DOCKERKIT_DIR}/${NGINX_SSL_DIR}"
    ensure_project_directory "$NGINX_SSL_DIR"

    # Generate certificates for each site
    for site in "${sites[@]}"; do
        generate_certificate_for_site "$site" "$ssl_dir"
    done
}



generate_certificate_for_site() {
    local site_name="$1"
    local ssl_dir="$2"

    # Skip non-.local domains silently
    if ! is_valid_local_domain "$site_name"; then
        return "$EXIT_SUCCESS"
    fi

    local cert_file="$ssl_dir/${site_name}.crt"
    local key_file="$ssl_dir/${site_name}.key"



    # Check if certificate already exists and is valid
    if [ -f "$cert_file" ] && [ -f "$key_file" ]; then
        if is_certificate_valid "$cert_file" "$site_name"; then
            print_success "SSL certificate already exists for: $site_name"
            return "$EXIT_SUCCESS"
        fi
    fi

    # Generate new certificate (suppress mkcert output)
    if (cd "$ssl_dir" && mkcert "$site_name" >/dev/null 2>&1); then
        # Rename files to expected format
        if [ -f "$ssl_dir/${site_name}.pem" ]; then
            mv "$ssl_dir/${site_name}.pem" "$cert_file"
        fi

        if [ -f "$ssl_dir/${site_name}-key.pem" ]; then
            mv "$ssl_dir/${site_name}-key.pem" "$key_file"
        fi

        print_success "SSL certificate generated for: $site_name"
    else
        print_error "Failed to generate certificate for $site_name"
        return "$EXIT_GENERAL_ERROR"
    fi
}

is_certificate_valid() {
    local cert_file="$1"
    local domain="$2"

    if ! [ -f "$cert_file" ]; then
        return "$EXIT_GENERAL_ERROR"
    fi

    # Check if certificate is not expired (basic check)
    if openssl x509 -in "$cert_file" -noout -checkend 86400 >/dev/null 2>&1; then
        # Check if certificate is for the correct domain
        local cert_subject
        cert_subject=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | grep -o "CN=[^,]*" | cut -d'=' -f2)

        if [ "$cert_subject" = "$domain" ]; then
            return "$EXIT_SUCCESS"
        fi
    fi

    return "$EXIT_GENERAL_ERROR"
}


