#!/bin/bash

# Module: synology.sh
# Purpose: Install Synology Drive client
# Tier: 4 (Applications)
# Description: Synology Drive client (COPR on Fedora, AUR on Arch)
# Installs: synology-drive-noextra (Fedora), synology-drive (Arch)

log_info "Installing Synology Drive"

# Check if already installed
if command -v synology-drive >/dev/null 2>&1; then
    log_success "Synology Drive is already installed"
    return 0
fi

case "$KITBASH_PKG_MANAGER" in
    dnf)
        if ! run_with_progress "adding Synology Drive COPR repository" \
            pkg_copr_enable emixampp/synology-drive; then
            log_error "Failed to enable COPR repository"
            return $KIT_EXIT_MODULE_FAILED
        fi

        if ! run_with_progress "installing Synology Drive" \
            pkg_install synology-drive-noextra; then
            log_error "Failed to install Synology Drive"
            return $KIT_EXIT_MODULE_FAILED
        fi
        ;;
    pacman)
        # xwayland-satellite is required for Synology Drive on niri (X11-only Qt bundled)
        if ! command -v xwayland-satellite >/dev/null 2>&1; then
            log_info "Installing xwayland-satellite (required for X11 support in niri)..."
            if ! pkg_aur_install xwayland-satellite; then
                log_error "Failed to install xwayland-satellite"
                return $KIT_EXIT_MODULE_FAILED
            fi
        fi

        log_info "Installing Synology Drive from AUR (this may take a few minutes)..."
        if ! pkg_aur_install synology-drive; then
            log_error "Failed to install Synology Drive from AUR"
            return $KIT_EXIT_MODULE_FAILED
        fi
        ;;
    *)
        log_error "Synology Drive installation not supported on $KITBASH_PKG_MANAGER"
        return $KIT_EXIT_MODULE_FAILED
        ;;
esac

if command -v synology-drive >/dev/null 2>&1; then
    log_success "Synology Drive installed successfully"
else
    log_error "Synology Drive installation verification failed"
    return $KIT_EXIT_MODULE_FAILED
fi
