#!/bin/bash

# Module: thunar.sh
# Purpose: Install Thunar file manager
# Tier: 2 (Desktop Environment)
# Description: Lightweight GTK file manager from the Xfce project
# Installs: thunar

log_info "Setting up Thunar"

# Check if already installed
if command -v thunar >/dev/null 2>&1; then
    log_success "Thunar is already installed"
    return 0
fi

# Install Thunar
if ! run_with_progress "installing Thunar" pkg_install thunar; then
    log_error "Failed to install Thunar"
    return $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v thunar >/dev/null 2>&1; then
    log_debug "Thunar installed successfully"
else
    log_error "Thunar installation verification failed"
    return $KIT_EXIT_MODULE_FAILED
fi

log_success "Thunar installation completed successfully"
