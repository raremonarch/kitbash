#!/bin/bash

# Module: firefox.sh
# Purpose: Install Firefox web browser
# Tier: 4 (Applications)
# Description: Firefox web browser from official repositories
# Installs: firefox

log_info "Installing Firefox"

if command -v firefox >/dev/null 2>&1; then
    log_success "Firefox is already installed"
    exit 0
fi

pkg_detect

if ! run_with_progress "installing Firefox" pkg_install firefox; then
    log_error "Failed to install Firefox"
    exit $KIT_EXIT_MODULE_FAILED
fi

log_success "Firefox installed successfully"
