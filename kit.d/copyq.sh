#!/bin/bash

# Module: copyq.sh
# Purpose: Install and configure CopyQ advanced clipboard manager
# Tier: 4 (Core User Tools)
# Description: Advanced clipboard manager with scripting and history support
# Installs: copyq

log_info "Setting up CopyQ clipboard manager"

# Check if CopyQ is already installed
if command -v copyq >/dev/null 2>&1; then
    log_success "CopyQ is already installed"
    exit 0
fi

# Install CopyQ
if ! run_with_progress "installing CopyQ" pkg_install copyq; then
    log_error "Failed to install CopyQ"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v copyq >/dev/null 2>&1; then
    log_success "CopyQ installed successfully"
    log_info "To start CopyQ, run: copyq"
    log_info "You can add it to your desktop environment's autostart to run automatically"
else
    log_error "Installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
