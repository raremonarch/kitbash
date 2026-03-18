#!/bin/bash

# Module: vscode.sh
# Purpose: Install Visual Studio Code editor
# Tier: 3 (Package Repositories)
# Description: Visual Studio Code editor (Microsoft repo on Fedora, official repos on Arch)
# Installs: code

log_info "Installing Visual Studio Code"

# Check if VS Code is already installed
if command -v code >/dev/null 2>&1; then
    log_success "Visual Studio Code is already installed"
    return 0
fi

case "$KITBASH_PKG_MANAGER" in
    dnf)
        # Check if repository already exists
        if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
            run_with_progress "importing Microsoft GPG key" \
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

            log_step "adding Visual Studio Code repository"
            echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" \
                | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
        fi

        if ! run_with_progress "installing Visual Studio Code" \
            pkg_install code; then
            log_error "Failed to install Visual Studio Code"
            return $KIT_EXIT_MODULE_FAILED
        fi
        ;;
    pacman)
        if ! run_with_progress "installing Visual Studio Code" \
            pkg_aur_install visual-studio-code-bin; then
            log_error "Failed to install Visual Studio Code"
            return $KIT_EXIT_MODULE_FAILED
        fi
        ;;
    *)
        log_error "Visual Studio Code installation not supported on $KITBASH_PKG_MANAGER"
        return $KIT_EXIT_MODULE_FAILED
        ;;
esac

if command -v code >/dev/null 2>&1; then
    log_success "Visual Studio Code installed successfully"
else
    log_error "Visual Studio Code installation verification failed"
    return $KIT_EXIT_MODULE_FAILED
fi
