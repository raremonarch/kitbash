#!/bin/bash

# Module: rofi.sh
# Purpose: Install rofi application launcher
# Tier: 1 (System Fundamentals)
# Description: Versatile application launcher and dmenu replacement for Wayland compositors
# Installs: rofi
# Config-var: _launcher
# Config-match: rofi

log_info "Setting up rofi application launcher"

# Check if already installed
if command -v rofi >/dev/null 2>&1; then
    log_success "rofi is already installed"
    exit 0
fi

# Install rofi
if ! run_with_progress "installing rofi" pkg_install rofi; then
    log_error "Failed to install rofi"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v rofi >/dev/null 2>&1; then
    log_success "rofi installed successfully"
    log_info "Config location: ~/.config/rofi/"
else
    log_error "Installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
