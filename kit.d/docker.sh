#!/bin/bash

# Module: docker.sh
# Purpose: Install and configure Docker engine
# Tier: 5 (Applications)
# Description: Docker Engine with CLI tools, containerd, and Compose plugin
# Installs: docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin

# Exit on any error
set -e

log_step "installing and configuring Docker"

# Check if Docker is already installed
if command -v docker >/dev/null 2>&1; then
    log_debug "Docker already installed"
    return 0
fi

# Install Docker engine from official repository
if ! run_with_progress "setting up Docker repository" sudo dnf config-manager addrepo --from-repofile="https://download.docker.com/linux/fedora/docker-ce.repo"; then
    log_error "Failed to add Docker repository"
    exit 1
fi

if ! run_with_progress "installing Docker packages" sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
    log_error "Failed to install Docker packages"
    exit 1
fi

# Start and enable Docker service
log_step "starting Docker service"
sudo systemctl start docker
sudo systemctl enable docker
log_debug "Docker service started and enabled"

# Configure Docker group for non-root access
log_step "configuring Docker group access"
sudo groupadd docker 2>/dev/null || true  # Group might already exist
sudo gpasswd -a ${USER} docker
sudo systemctl restart docker
log_debug "Docker group configured (logout/login required for group changes)"