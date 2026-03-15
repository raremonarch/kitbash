#!/bin/bash

# Module: sddm.sh
# Purpose: Install and configure SDDM login manager
# Tier: 2 (Core Desktop Environment)
# Description: SDDM display manager with Wayland support
# Installs: sddm

log_info "Setting up SDDM login manager"

# Install if not present
if ! command -v sddm >/dev/null 2>&1; then
    if ! run_with_progress "installing SDDM" pkg_install sddm; then
        log_error "Failed to install SDDM"
        exit $KIT_EXIT_MODULE_FAILED
    fi
fi

# Enable sddm.service so it starts on boot
if ! systemctl is-enabled sddm >/dev/null 2>&1; then
    if ! run_with_progress "enabling SDDM service" sudo systemctl enable sddm; then
        log_error "Failed to enable SDDM service"
        exit $KIT_EXIT_MODULE_FAILED
    fi
fi

# Deploy themes from dotfiles to system theme directory
DOTFILES_THEMES="$HOME/system-configs/sddm/themes"
SYSTEM_THEMES="/usr/share/sddm/themes"
if [ -d "$DOTFILES_THEMES" ]; then
    for theme_dir in "$DOTFILES_THEMES"/*/; do
        theme_name=$(basename "$theme_dir")
        log_step "deploying SDDM theme: $theme_name"
        sudo mkdir -p "$SYSTEM_THEMES/$theme_name"
        sudo cp -r "$theme_dir"* "$SYSTEM_THEMES/$theme_name/"
    done
fi

# Optional config — only applies if /etc/sddm.conf exists
SDDM_CONFIG="/etc/sddm.conf"
if [ -f "$SDDM_CONFIG" ]; then
    if sudo grep -q "^DisplayServer=x11" "$SDDM_CONFIG"; then
        log_step "switching to Wayland mode"
        sudo sed -i 's|^DisplayServer=x11|# DisplayServer=wayland|' "$SDDM_CONFIG"
    fi
fi

log_success "SDDM installed and enabled"
log_info "Note: SDDM will start on next boot. To start now: sudo systemctl start sddm"
