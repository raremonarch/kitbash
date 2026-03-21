#!/bin/bash

# Module: google_chrome.sh
# Purpose: Install Google Chrome browser
# Tier: 2 (Package Repositories)
# Description: Google Chrome browser (AUR on Arch, official repo on Fedora)
# Installs: google-chrome-stable

log_info "Setting up Google Chrome"

if command -v google-chrome >/dev/null 2>&1 || command -v google-chrome-stable >/dev/null 2>&1; then
    log_success "Google Chrome is already installed"
    return 0
fi

if [ "$KITBASH_DISTRO" = "arch" ]; then
    if ! run_with_progress "installing Google Chrome" pkg_aur_install google-chrome; then
        log_error "Failed to install Google Chrome"
        return $KIT_EXIT_MODULE_FAILED
    fi
else
    # Fedora: add the official Google repository
    if ! dnf repolist --all 2>/dev/null | grep -q "^google-chrome"; then
        run_with_progress "installing DNF plugins" sudo dnf install -y dnf-plugins-core

        run_with_progress "adding Google Chrome repository" \
            sudo dnf config-manager addrepo \
                --id=google-chrome \
                --set=baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64 \
                --set=name=google-chrome \
                --set=enabled=1 \
                --set=gpgcheck=1 \
                --set=gpgkey=https://dl.google.com/linux/linux_signing_key.pub
    else
        log_step "Google Chrome repository already configured"
    fi

    if ! run_with_progress "installing Google Chrome" sudo dnf install -y google-chrome-stable; then
        log_error "Failed to install Google Chrome"
        return $KIT_EXIT_MODULE_FAILED
    fi
fi

log_success "Google Chrome installed successfully"
