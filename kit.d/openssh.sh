#!/bin/bash

# Module: openssh.sh
# Purpose: Install OpenSSH client tools (ssh, ssh-keygen, scp, etc.)
# Tier: 1 (System Fundamentals)
# Description: OpenSSH client utilities including ssh-keygen for key management
# Installs: openssh-clients (Fedora), openssh (Arch)

log_info "Setting up OpenSSH client tools"

# Check if already installed
if command -v ssh-keygen >/dev/null 2>&1; then
    log_success "OpenSSH client tools are already installed"
    exit 0
fi

# Install — package name differs by distro
if ! run_with_progress "installing OpenSSH client tools" pkg_install "$(pkg_name openssh)"; then
    log_error "Failed to install OpenSSH client tools"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v ssh-keygen >/dev/null 2>&1; then
    log_success "OpenSSH client tools installed successfully"
else
    log_error "Installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
