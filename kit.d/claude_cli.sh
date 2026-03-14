#!/bin/bash

# Module: claude_cli.sh
# Purpose: Install Claude Code CLI via npm
# Tier: 5 (Applications)
# Description: Official Claude Code CLI (claude-code npm package)
# Installs: nodejs, npm, @anthropic-ai/claude-code

log_info "Installing Claude CLI"

# Check if already installed and in PATH
if command -v claude >/dev/null 2>&1; then
    current_version=$(claude --version 2>/dev/null | head -n1 || echo "unknown")
    log_success "Claude CLI is already installed: $current_version"
    exit 0
fi

# Ensure nodejs and npm are available
if ! command -v npm >/dev/null 2>&1; then
    log_step "installing nodejs and npm"
    if ! run_with_progress "installing nodejs and npm" pkg_install nodejs npm; then
        log_error "Failed to install nodejs/npm"
        exit $KIT_EXIT_DEPENDENCY_MISSING
    fi
fi

# Install claude-code globally via npm
if ! run_with_progress "installing claude-code via npm" \
    sudo npm install -g @anthropic-ai/claude-code; then
    log_error "Failed to install claude-code"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Check if claude is now in PATH
if command -v claude >/dev/null 2>&1; then
    version=$(claude --version 2>/dev/null | head -n1 || echo "installed")
    log_success "Claude CLI installed successfully: $version"
    exit 0
fi

# Not in PATH yet — find where npm installed it and add to ~/.bashrc
NPM_BIN="$(npm config get prefix)/bin"
if [ -f "$NPM_BIN/claude" ]; then
    log_step "adding $NPM_BIN to PATH in ~/.bashrc"
    if ! grep -q "$NPM_BIN" "$HOME/.bashrc" 2>/dev/null; then
        echo "export PATH=\"$NPM_BIN:\$PATH\"" >> "$HOME/.bashrc"
        log_success "Claude CLI installed — PATH updated in ~/.bashrc"
        log_info "Run 'source ~/.bashrc' or open a new terminal, then run 'claude'"
    else
        log_success "Claude CLI installed — PATH entry already present in ~/.bashrc"
        log_info "Run 'source ~/.bashrc' or open a new terminal, then run 'claude'"
    fi
    exit 0
fi

log_error "Claude CLI installed but binary not found in $NPM_BIN"
log_error "Check 'npm config get prefix' and ensure its bin/ is in your PATH"
exit $KIT_EXIT_MODULE_FAILED
