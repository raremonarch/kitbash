#!/bin/bash

# Module: discord.sh
# Purpose: Install Discord chat client from RPM Fusion nonfree repository
# Tier: 4 (Applications)
# Description: Discord chat and voice client installed via RPM Fusion
# Installs: discord

log_info "Setting up Discord"

# Check if Discord is already installed (executable is "Discord" with capital D)
if command -v Discord >/dev/null 2>&1; then
    log_success "Discord is already installed"
    exit 0
fi

# Check and enable RPM Fusion repositories if not already present
if ! dnf repolist --all 2>/dev/null | grep -q "rpmfusion-nonfree"; then
    log_step "enabling RPM Fusion free and nonfree repositories"

    if ! run_with_progress "installing RPM Fusion repositories" \
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"; then
        log_error "Failed to install RPM Fusion repositories"
        exit $KIT_EXIT_NETWORK_ERROR
    fi

    log_step "RPM Fusion repositories enabled"
else
    log_step "RPM Fusion repositories already enabled"
fi

# Install Discord
log_step "installing Discord package"

if ! run_with_progress "installing Discord" \
    sudo dnf install -y discord; then
    log_error "Failed to install Discord"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation (executable is "Discord" with capital D)
if command -v Discord >/dev/null 2>&1; then
    log_success "Discord installed successfully"
    exit 0
else
    log_error "Discord installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
