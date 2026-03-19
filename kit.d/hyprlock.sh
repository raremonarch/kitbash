#!/bin/bash

# Module: hyprlock.sh
# Purpose: Install hyprlock screen locker
# Tier: 2 (Core Desktop Environment)
# Description: GPU-accelerated screen locker for Wayland, works with Hyprland, Niri, and Sway
# Installs: hyprlock

log_info "Setting up hyprlock screen locker"

# Check if already installed
if command -v hyprlock >/dev/null 2>&1; then
    log_success "hyprlock is already installed"
    exit 0
fi

# On Fedora, hyprlock lives in the solopasha/hyprland COPR
if [ "$KITBASH_DISTRO" = "fedora" ]; then
    if ! dnf copr list 2>/dev/null | grep -q "copr:copr.fedorainfracloud.org:solopasha:hyprland"; then
        run_with_progress "enabling solopasha/hyprland COPR" \
            sudo dnf copr enable -y solopasha/hyprland || {
            log_error "Failed to enable solopasha/hyprland COPR"
            exit $KIT_EXIT_MODULE_FAILED
        }
    fi
fi

# Install hyprlock
if ! run_with_progress "installing hyprlock" pkg_install hyprlock; then
    log_error "Failed to install hyprlock"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v hyprlock >/dev/null 2>&1; then
    log_success "hyprlock installed successfully"
    log_info "Trigger it via: loginctl lock-session"
else
    log_error "Installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
