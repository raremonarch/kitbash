#!/bin/bash

# Module: moonlight.sh
# Purpose: Install Moonlight game/desktop streaming client
# Tier: 5 (Applications)
# Description: Moonlight open-source streaming client for connecting to Sunshine hosts
# Installs: moonlight-qt

log_info "Installing Moonlight streaming client"

if command -v moonlight >/dev/null 2>&1; then
    log_success "Moonlight is already installed"
    return 0
fi

case "$KITBASH_PKG_MANAGER" in
    dnf)
        if ! pkg_repo_exists moonlight-qt; then
            if ! run_with_progress "enabling Moonlight COPR repository" \
                pkg_copr_enable pgdev/moonlight-qt; then
                log_error "Failed to enable Moonlight COPR repository"
                return $KIT_EXIT_MODULE_FAILED
            fi
        fi

        if ! run_with_progress "installing Moonlight" \
            pkg_install moonlight-qt; then
            log_error "Failed to install Moonlight"
            return $KIT_EXIT_MODULE_FAILED
        fi
        ;;
    pacman)
        if ! run_with_progress "installing Moonlight" \
            pkg_install moonlight-qt; then
            log_error "Failed to install Moonlight"
            return $KIT_EXIT_MODULE_FAILED
        fi
        ;;
    *)
        log_error "Moonlight installation not supported on $KITBASH_PKG_MANAGER"
        return $KIT_EXIT_MODULE_FAILED
        ;;
esac

if command -v moonlight >/dev/null 2>&1; then
    log_success "Moonlight installed successfully"
else
    log_error "Moonlight installation verification failed"
    return $KIT_EXIT_MODULE_FAILED
fi
