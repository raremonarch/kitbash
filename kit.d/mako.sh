#!/bin/bash

# Module: mako.sh
# Purpose: Install mako Wayland notification daemon
# Tier: 2 (Core Desktop Environment)
# Description: Lightweight notification daemon for Wayland compositors
# Installs: mako

log_info "Setting up mako notification daemon"

# Check if already installed
if command -v mako >/dev/null 2>&1; then
    log_success "mako is already installed"
    exit 0
fi

# Install mako
if ! run_with_progress "installing mako" pkg_install mako; then
    log_error "Failed to install mako"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v mako >/dev/null 2>&1; then
    log_success "mako installed successfully"
    log_info "Config location: ~/.config/mako/config"
else
    log_error "Installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
