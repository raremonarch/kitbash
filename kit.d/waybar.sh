#!/bin/bash

# Module: waybar.sh
# Purpose: Install Waybar status bar for Wayland compositors
# Tier: 2 (Core Desktop Environment)
# Description: Highly customizable Wayland bar for Sway, Niri, and Hyprland
# Installs: waybar, wireplumber, pacman-contrib (Arch only, for checkupdates)

log_info "Installing Waybar"

if command -v waybar >/dev/null 2>&1; then
    log_success "Waybar is already installed"
    exit 0
fi

if ! run_with_progress "installing waybar" pkg_install waybar; then
    log_error "Failed to install waybar"
    exit $KIT_EXIT_MODULE_FAILED
fi

if ! run_with_progress "installing wireplumber" pkg_install wireplumber; then
    log_warning "Failed to install wireplumber (volume control may not work)"
fi

# On Arch: install pacman-contrib for checkupdates (used by waybar updates widget)
if [ "$KITBASH_DISTRO" = "arch" ] && ! command -v checkupdates >/dev/null 2>&1; then
    run_with_progress "installing pacman-contrib" pkg_install pacman-contrib
fi

if command -v waybar >/dev/null 2>&1; then
    log_success "Waybar installed successfully"
else
    log_error "Waybar installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
