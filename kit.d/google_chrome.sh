#!/bin/bash

# Module: google_chrome.sh
# Purpose: Install Google Chrome browser and repository
# Tier: 3 (Package Repositories)
# Description: Google Chrome browser via the official Google repository
# Installs: google-chrome-stable

log_info "Setting up Google Chrome repository"

# Check if Google Chrome is already installed
if command -v google-chrome >/dev/null 2>&1 || command -v google-chrome-stable >/dev/null 2>&1; then
    log_success "Google Chrome is already installed"
    exit 0
fi

# Check if repository already exists
if ! dnf repolist --all 2>/dev/null | grep -q "^google-chrome"; then
    run_with_progress "installing DNF plugins" sudo dnf install -y dnf-plugins-core

    run_with_progress "adding Google Chrome repository" sudo dnf config-manager addrepo --id=google-chrome --set=baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64 --set=name=google-chrome --set=enabled=1 --set=gpgcheck=1 --set=gpgkey=https://dl.google.com/linux/linux_signing_key.pub

    log_success "Google Chrome repository configured"
else
    log_success "Google Chrome repository already configured"
fi

# Install Google Chrome
run_with_progress "installing Google Chrome" sudo dnf install -y google-chrome-stable

log_success "Google Chrome installed successfully"
