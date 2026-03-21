#!/bin/bash

# Module: zoom.sh
# Purpose: Install Zoom video conferencing application
# Tier: 4 (Applications)
# Description: Zoom video conferencing installed from the official Zoom RPM
# Installs: zoom

log_info "Installing Zoom"

# Check if Zoom is already installed
if command -v zoom >/dev/null 2>&1; then
    log_success "Zoom is already installed"
    exit 0
fi

# Define Zoom download URL (RPM package for Fedora)
ZOOM_RPM_URL="https://zoom.us/client/latest/zoom_x86_64.rpm"
TEMP_RPM="/tmp/zoom_x86_64.rpm"

# Download Zoom RPM
if ! run_with_progress "downloading Zoom" curl -L -o "$TEMP_RPM" "$ZOOM_RPM_URL"; then
    log_error "Failed to download Zoom"
    exit $KIT_EXIT_NETWORK_ERROR
fi

# Install Zoom using DNF (handles dependencies automatically)
if ! run_with_progress "installing Zoom" sudo dnf install -y "$TEMP_RPM"; then
    log_error "Failed to install Zoom"
    rm -f "$TEMP_RPM"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Clean up downloaded RPM
rm -f "$TEMP_RPM"

# Verify installation
if command -v zoom >/dev/null 2>&1; then
    log_success "Zoom installed successfully"
    exit 0
else
    log_error "Zoom installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
