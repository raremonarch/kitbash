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

# Optional config — only applies if /etc/sddm.conf exists
SDDM_CONFIG="/etc/sddm.conf"
if [ -f "$SDDM_CONFIG" ]; then
    if [ -d "/usr/share/sddm/themes/custom" ] && ! sudo grep -q "^Current=custom" "$SDDM_CONFIG"; then
        log_step "setting custom theme"
        sudo sed -i 's|#Current=.*|Current=custom|; s|^Current=.*|Current=custom|' "$SDDM_CONFIG"
    fi

    if sudo grep -q "^DisplayServer=x11" "$SDDM_CONFIG"; then
        log_step "switching to Wayland mode"
        sudo sed -i 's|^DisplayServer=x11|# DisplayServer=wayland|' "$SDDM_CONFIG"
    fi
fi

log_success "SDDM installed and enabled"
log_info "Note: SDDM will start on next boot. To start now: sudo systemctl start sddm"
