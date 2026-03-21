#!/bin/bash

# Module: gnome_boxes.sh
# Purpose: Install GNOME Boxes and virt-manager for virtualization
# Tier: 4 (Applications)
# Description: GNOME Boxes virtualization app and optionally virt-manager
# Installs: gnome-boxes, virt-manager (optional)

log_info "Installing virtualization tools"

# Check if both are already installed
BOXES_INSTALLED=false
VIRT_MANAGER_INSTALLED=false

if command -v gnome-boxes >/dev/null 2>&1; then
    log_debug "GNOME Boxes already installed"
    BOXES_INSTALLED=true
fi

if command -v virt-manager >/dev/null 2>&1; then
    log_debug "virt-manager already installed"
    VIRT_MANAGER_INSTALLED=true
fi

# Exit early if both are installed
if $BOXES_INSTALLED && $VIRT_MANAGER_INSTALLED; then
    log_success "GNOME Boxes and virt-manager are already installed"
    exit 0
fi

# Build list of packages to install
PACKAGES=()
if ! $BOXES_INSTALLED; then
    PACKAGES+=("gnome-boxes")
fi
if ! $VIRT_MANAGER_INSTALLED; then
    PACKAGES+=("virt-manager")
fi

# Install packages
log_step "installing virtualization packages: ${PACKAGES[*]}"
if ! run_with_progress "installing ${PACKAGES[*]}" sudo dnf install -y "${PACKAGES[@]}"; then
    log_error "Failed to install virtualization packages"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installations
ALL_INSTALLED=true

if ! $BOXES_INSTALLED && ! command -v gnome-boxes >/dev/null 2>&1; then
    log_error "GNOME Boxes installation verification failed"
    ALL_INSTALLED=false
fi

if ! $VIRT_MANAGER_INSTALLED && ! command -v virt-manager >/dev/null 2>&1; then
    log_error "virt-manager installation verification failed"
    ALL_INSTALLED=false
fi

if $ALL_INSTALLED; then
    log_success "Virtualization tools installed successfully"
    log_info "Launch with: gnome-boxes (simple) or virt-manager (advanced)"
    log_info "Tip: Use virt-manager for VM snapshots on Boxes VMs"
    exit 0
else
    log_error "Installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
