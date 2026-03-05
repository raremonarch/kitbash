#!/bin/bash

# Module: vscode.sh
# Purpose: Install Visual Studio Code editor and repository
# Tier: 3 (Package Repositories)
# Description: Visual Studio Code editor installed via the official Microsoft repository
# Installs: code

log_info "Setting up Visual Studio Code repository"

# Check if VS Code is already installed
if command -v code >/dev/null 2>&1; then
    log_success "Visual Studio Code is already installed"
    exit 0
fi

# Check if repository already exists
if [ -f /etc/yum.repos.d/vscode.repo ]; then
    log_success "Visual Studio Code repository already configured"
    exit 0
fi

run_with_progress "importing Microsoft GPG key" sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

log_step "adding Visual Studio Code repository"
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

run_with_progress "checking for updates" dnf check-update > /dev/null

log_success "Visual Studio Code repository configured"
