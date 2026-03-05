#!/bin/bash

# Module: jq.sh
# Purpose: Install jq - lightweight and flexible command-line JSON processor
# Tier: 1 (System Fundamentals)
# Description: Lightweight command-line JSON processor
# Installs: jq

log_info "Setting up jq"

# Check if jq is already installed
if command -v jq >/dev/null 2>&1; then
    JQ_VERSION=$(jq --version 2>&1 || echo "unknown")
    log_debug "jq is already installed: $JQ_VERSION"
    log_success "jq is already installed"
    exit 0
fi

# Install jq from Fedora repositories
log_step "installing jq"
if ! run_with_progress "installing jq package" \
    sudo dnf install -y jq; then
    log_error "Failed to install jq"
    log_error "Check ~/kit.log for details"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v jq >/dev/null 2>&1; then
    JQ_VERSION=$(jq --version 2>&1 || echo "installed")
    log_debug "jq installed successfully: $JQ_VERSION"
else
    log_error "jq installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi

log_success "jq installation completed successfully"
log_info "Note: Use 'jq --help' or 'man jq' for usage information"
exit 0
