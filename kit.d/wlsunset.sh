#!/bin/bash

# Module: wlsunset.sh
# Purpose: Install wlsunset day/night gamma adjustment for Wayland
# Tier: 4 (Applications)
# Description: Adjusts color temperature based on time of day for Wayland compositors
# Installs: wlsunset

log_info "Setting up wlsunset color temperature manager"

# Check if already installed
if command -v wlsunset >/dev/null 2>&1; then
    log_success "wlsunset is already installed"
    exit 0
fi

# Install wlsunset
if ! run_with_progress "installing wlsunset" pkg_install wlsunset; then
    log_error "Failed to install wlsunset"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v wlsunset >/dev/null 2>&1; then
    log_success "wlsunset installed successfully"
    log_info "Launch with coordinates, e.g.: wlsunset -l 51.5 -L -0.1"
else
    log_error "Installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
