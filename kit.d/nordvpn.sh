#!/bin/bash

# Module: nordvpn.sh
# Purpose: Install NordVPN client
# Tier: 5 (Applications)
# Description: NordVPN client installed via the official NordVPN install script
# Installs: nordvpn

log_info "Installing NordVPN"

# Check if already installed
if command -v nordvpn >/dev/null 2>&1; then
    log_success "NordVPN is already installed"
    exit 0
fi

# Use official install script with non-interactive flag
if ! run_with_progress "running NordVPN installer" sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh) -n; then
    log_error "Failed to install NordVPN"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Add user to nordvpn group for non-root access
run_with_progress "adding user to nordvpn group" sudo usermod -aG nordvpn "$USER"

# Enable and start the service
run_with_progress "enabling NordVPN service" sudo systemctl enable --now nordvpnd

# Verify installation
if command -v nordvpn >/dev/null 2>&1; then
    log_success "NordVPN installed successfully"
    log_warning "You may need to log out and back in for group membership to take effect"
    log_step "run 'nordvpn login' to authenticate"
else
    log_error "NordVPN installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
