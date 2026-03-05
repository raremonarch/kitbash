#!/bin/bash

# Module: synology.sh
# Purpose: Install Synology Drive client from COPR repository
# Tier: 5 (Applications)
# Description: Synology Drive client installed via COPR repository
# Installs: synology-drive-noextra

# Exit on any error
set -e

log_info "Installing Synology Drive"

# Check if Synology Drive is already installed
if command -v synology-drive >/dev/null 2>&1; then
    log_step "already installed"
    exit 0
fi

# Add Synology Drive COPR repository
if ! run_with_progress "adding Synology Drive COPR repository" sudo dnf copr enable emixampp/synology-drive -y; then
    log_error "Failed to enable COPR repository"
    exit 1
fi

# Install Synology Drive
if ! run_with_progress "installing Synology Drive package" sudo dnf install -y synology-drive-noextra; then
    log_error "Failed to install Synology Drive"
    exit 1
fi

log_success "Synology Drive installed successfully"