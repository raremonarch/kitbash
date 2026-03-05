#!/bin/bash

# Module: claude_cli.sh
# Purpose: Install Claude CLI (official native binary)
# Tier: 5 (Applications)
# Description: Official Claude CLI native binary
# Installs: claude (binary)

log_info "Installing Claude CLI"

# Check if already installed
if command -v claude >/dev/null 2>&1; then
    current_version=$(claude --version 2>/dev/null | head -n1 || echo "unknown")
    log_success "Claude CLI is already installed: $current_version"
    exit 0
fi

# Install Claude CLI using official installer
log_step "downloading and installing Claude CLI"
if ! run_with_progress "installing Claude CLI" \
    bash -c 'curl -fsSL https://claude.ai/install.sh | bash'; then
    log_error "Failed to install Claude CLI"
    exit $KIT_EXIT_NETWORK_ERROR
fi

# Verify installation
if command -v claude >/dev/null 2>&1; then
    version=$(claude --version 2>/dev/null | head -n1 || echo "installed")
    log_success "Claude CLI installed successfully: $version"
    log_debug ""
    log_debug "Next steps:"
    log_debug "  1. Restart your shell or run: source ~/.bashrc"
    log_debug "  2. Run 'claude doctor' to verify installation"
    log_debug "  3. Run 'claude' in a project directory to start"
    log_debug "  4. Authenticate via OAuth (requires billing at console.anthropic.com)"
    log_debug ""
else
    log_error "Claude CLI installation completed but 'claude' command not found"
    log_warning "You may need to restart your shell or run: source ~/.bashrc"
    exit $KIT_EXIT_MODULE_FAILED
fi
