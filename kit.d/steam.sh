#!/bin/bash

# Module: steam.sh
# Purpose: Install Steam gaming platform with RPM Fusion nonfree repository
# Tier: 5 (Applications)
# Description: Steam gaming platform installed via RPM Fusion
# Installs: steam

log_info "Setting up Steam"

# Check if Steam is already installed
if command -v steam >/dev/null 2>&1; then
    log_success "Steam is already installed"
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

# Configure Cisco OpenH264 codec repository (for Fedora 41+)
FEDORA_VERSION=$(rpm -E %fedora)
if [ "$FEDORA_VERSION" -ge 41 ]; then
    log_step "configuring Cisco OpenH264 codec repository"

    if ! run_with_progress "enabling cisco-openh264 repository" \
        sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1; then
        log_warning "Failed to enable Cisco OpenH264 repository (non-critical)"
    fi
fi

# Install Steam
log_step "installing Steam package"

if ! run_with_progress "installing Steam" \
    sudo dnf install -y steam; then
    log_error "Failed to install Steam"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v steam >/dev/null 2>&1; then
    log_success "Steam installed successfully"
    log_info "To enable Proton for Windows games:"
    log_info "  1. Launch Steam"
    log_info "  2. Go to Steam > Settings > Compatibility"
    log_info "  3. Enable 'Steam Play for supported titles'"
    log_info "  4. Enable 'Steam Play for all other titles'"
    log_info "  5. Select your preferred Proton version"
    log_info "  6. Restart Steam"
    exit 0
else
    log_error "Steam installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
