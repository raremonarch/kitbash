#!/bin/bash

# Module: waybar.sh
# Purpose: Install Waybar status bar for Wayland compositors
# Tier: 2 (Core Desktop Environment)
# Description: Highly customizable Wayland bar for Sway, Niri, and Hyprland
# Installs: waybar

log_info "Installing Waybar"

if command -v waybar >/dev/null 2>&1; then
    log_success "Waybar is already installed"
    exit 0
fi

if ! run_with_progress "installing waybar" pkg_install waybar; then
    log_error "Failed to install waybar"
    exit $KIT_EXIT_MODULE_FAILED
fi

if command -v waybar >/dev/null 2>&1; then
    log_success "Waybar installed successfully"
else
    log_error "Waybar installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
