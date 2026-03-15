#!/bin/bash

# Module: brightnessctl.sh
# Purpose: Install brightnessctl for screen brightness control
# Tier: 2 (Desktop Environment)
# Description: Screen brightness control utility for backlight management
# Installs: brightnessctl

log_info "Setting up brightnessctl"

# Check if already installed
if command -v brightnessctl >/dev/null 2>&1; then
    log_success "brightnessctl is already installed"
    return 0
fi

# Install brightnessctl
if ! run_with_progress "installing brightnessctl" pkg_install brightnessctl; then
    log_error "Failed to install brightnessctl"
    return $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v brightnessctl >/dev/null 2>&1; then
    log_debug "brightnessctl installed successfully"
else
    log_error "brightnessctl installation verification failed"
    return $KIT_EXIT_MODULE_FAILED
fi

log_success "brightnessctl installation completed successfully"
