#!/bin/bash

# Module: hypridle.sh
# Purpose: Install and enable hypridle idle management daemon
# Tier: 2 (Core Desktop Environment)
# Description: Compositor-agnostic idle daemon; locks screen and powers off monitors on inactivity
# Installs: hypridle

log_info "Setting up hypridle idle management daemon"

# Check if already installed
if command -v hypridle >/dev/null 2>&1; then
    log_success "hypridle is already installed"
    exit 0
fi

# On Fedora, hypridle lives in the solopasha/hyprland COPR
if [ "$KITBASH_DISTRO" = "fedora" ]; then
    if ! dnf copr list 2>/dev/null | grep -q "copr:copr.fedorainfracloud.org:solopasha:hyprland"; then
        run_with_progress "enabling solopasha/hyprland COPR" \
            sudo dnf copr enable -y solopasha/hyprland || {
            log_error "Failed to enable solopasha/hyprland COPR"
            exit $KIT_EXIT_MODULE_FAILED
        }
    fi
fi

# Install hypridle
if ! run_with_progress "installing hypridle" pkg_install hypridle; then
    log_error "Failed to install hypridle"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if ! command -v hypridle >/dev/null 2>&1; then
    log_error "Installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Enable as a systemd user service so it starts automatically with the session
if ! systemctl --user is-enabled hypridle >/dev/null 2>&1; then
    run_with_progress "enabling hypridle user service" \
        systemctl --user enable --now hypridle
else
    log_debug "hypridle user service already enabled"
fi

log_success "hypridle installed and enabled"
log_info "Config expected at: ~/.config/hypr/hypridle.conf"
