#!/bin/bash

# Module: zsh.sh
# Purpose: Install zsh and set it as the default shell
# Tier: 1 (System Fundamentals)
# Description: Installs zsh and configures it as the default login shell for the current user
# Installs: zsh
# Config-var: _shell
# Config-match: zsh

log_info "Setting up zsh as default shell"

# Check if already installed and already the default shell
if command -v zsh >/dev/null 2>&1; then
    if [ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ]; then
        log_success "zsh is already installed and set as the default shell"
        exit 0
    fi
fi

# Install zsh
if ! command -v zsh >/dev/null 2>&1; then
    if ! run_with_progress "installing zsh" pkg_install zsh; then
        log_error "Failed to install zsh"
        exit $KIT_EXIT_MODULE_FAILED
    fi
fi

# Ensure zsh is listed in /etc/shells (required for chsh)
ZSH_PATH="$(command -v zsh)"
if ! grep -qx "$ZSH_PATH" /etc/shells; then
    log_step "adding $ZSH_PATH to /etc/shells"
    echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
fi

# Set zsh as the default shell for the current user
# usermod is used instead of chsh to avoid interactive password prompts
if ! run_with_progress "setting zsh as default shell" sudo usermod -s "$ZSH_PATH" "$USER"; then
    log_error "Failed to set zsh as default shell"
    exit $KIT_EXIT_MODULE_FAILED
fi

log_success "zsh installed and set as default shell"
log_info "Log out and back in for the shell change to take effect"
