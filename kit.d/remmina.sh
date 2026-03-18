#!/bin/bash

# Module: remmina.sh
# Purpose: Install Remmina remote desktop client
# Tier: 5 (Applications)
# Description: Remmina remote desktop client with RDP, VNC, and SSH support
# Installs: remmina

log_info "Installing Remmina"

if command -v remmina >/dev/null 2>&1; then
    log_success "Remmina is already installed"
    return 0
fi

if ! run_with_progress "installing Remmina" pkg_install remmina; then
    log_error "Failed to install Remmina"
    return $KIT_EXIT_MODULE_FAILED
fi

if command -v remmina >/dev/null 2>&1; then
    log_success "Remmina installed successfully"
else
    log_error "Remmina installation verification failed"
    return $KIT_EXIT_MODULE_FAILED
fi
