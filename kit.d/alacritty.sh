#!/bin/bash

# Module: alacritty.sh
# Purpose: Install Alacritty terminal emulator
# Tier: 3 (User Applications)
# Description: Fast, GPU-accelerated terminal emulator
# Installs: alacritty

log_info "Setting up Alacritty"

if command -v alacritty >/dev/null 2>&1; then
    log_success "Alacritty is already installed"
    exit 0
fi

if ! run_with_progress "installing Alacritty" pkg_install alacritty; then
    log_error "Failed to install Alacritty"
    exit $KIT_EXIT_MODULE_FAILED
fi

if command -v alacritty >/dev/null 2>&1; then
    log_success "Alacritty installed successfully"
else
    log_error "Installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
