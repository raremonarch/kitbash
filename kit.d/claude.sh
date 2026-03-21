#!/bin/bash

# Module: claude.sh
# Purpose: Install Claude Code CLI via npm
# Tier: 4 (Applications)
# Description: Official Claude Code CLI (claude-code npm package)
# Installs: nodejs, npm, @anthropic-ai/claude-code

log_info "Installing Claude CLI"

# Check if already installed and in PATH
if command -v claude >/dev/null 2>&1; then
    current_version=$(claude --version 2>/dev/null | head -n1 || echo "unknown")
    log_success "Claude CLI is already installed: $current_version"
    exit 0
fi

# Ensure node and npm are available
if ! command -v npm >/dev/null 2>&1; then
    log_step "installing nodejs and npm"
    if ! run_with_progress "installing nodejs" pkg_install nodejs npm; then
        log_error "Failed to install nodejs/npm"
        exit $KIT_EXIT_DEPENDENCY_MISSING
    fi
fi

# Configure user-local npm prefix so global installs don't need sudo
NPM_PREFIX="$HOME/.npm-global"
CURRENT_PREFIX="$(npm config get prefix 2>/dev/null)"
if [ "$CURRENT_PREFIX" != "$NPM_PREFIX" ]; then
    log_step "configuring user-local npm prefix"
    npm config set prefix "$NPM_PREFIX"
fi

# Ensure the bin directory is in PATH (persisted to ~/.bashrc)
NPM_BIN="$NPM_PREFIX/bin"
if [[ ":$PATH:" != *":$NPM_BIN:"* ]]; then
    export PATH="$NPM_BIN:$PATH"
fi
if ! grep -q "$NPM_BIN" "$HOME/.bashrc" 2>/dev/null; then
    echo "export PATH=\"$NPM_BIN:\$PATH\"" >> "$HOME/.bashrc"
fi

# Install claude-code globally — no sudo needed since prefix is user-local
if ! run_with_progress "installing claude-code via npm" \
    npm install -g @anthropic-ai/claude-code; then
    log_error "Failed to install claude-code"
    exit $KIT_EXIT_MODULE_FAILED
fi

if command -v claude >/dev/null 2>&1; then
    version=$(claude --version 2>/dev/null | head -n1 || echo "installed")
    log_success "Claude CLI installed successfully: $version"
    exit 0
fi

log_error "Claude CLI installed but binary not found in $NPM_BIN"
log_error "Open a new terminal (PATH update required) then run 'claude'"
exit $KIT_EXIT_MODULE_FAILED
