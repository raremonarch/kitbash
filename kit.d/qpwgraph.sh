#!/bin/bash

# Module: qpwgraph.sh
# Purpose: Install qpwgraph PipeWire graph editor for audio/video routing
# Tier: 5 (Applications)
# Description: PipeWire graph editor for visual audio and video routing
# Installs: qpwgraph

log_info "Installing qpwgraph"

if command -v qpwgraph >/dev/null 2>&1; then
    log_success "qpwgraph is already installed"
    exit 0
fi

run_with_progress "installing qpwgraph" \
    sudo dnf install -y qpwgraph

if command -v qpwgraph >/dev/null 2>&1; then
    log_success "qpwgraph installed successfully"
    log_step "Launch qpwgraph to visualise and manage PipeWire audio routing"
else
    log_error "qpwgraph installation failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
