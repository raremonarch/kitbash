#!/bin/bash

# Module: editor.sh
# Purpose: Set default EDITOR and VISUAL environment variables
# Tier: 1 (System Fundamentals)
# Description: Sets default EDITOR and VISUAL environment variables in shell profile
# Installs: none (configuration only)

EDITOR_CHOICE="${1:-$_editor}"

if [ -z "$EDITOR_CHOICE" ]; then
    log_error "No editor specified. Usage: $0 <editor>"
    exit 1
fi

# Verify the editor is available
if ! command -v "$EDITOR_CHOICE" >/dev/null 2>&1; then
    log_warning "Editor '$EDITOR_CHOICE' not found in PATH"
    log_warning "Proceeding anyway (it may be installed later)"
fi

log_step "setting default editor to '$EDITOR_CHOICE'"
log_debug "Editor choice: $EDITOR_CHOICE"

# Update systemd user environment file
EDITOR_ENV_FILE="$HOME/.config/environment.d/editor.conf"
if [ -f "$EDITOR_ENV_FILE" ]; then
    log_step "updating editor environment configuration"
    sed -i "s|^EDITOR=.*|EDITOR=$EDITOR_CHOICE|" "$EDITOR_ENV_FILE"
    sed -i "s|^VISUAL=.*|VISUAL=$EDITOR_CHOICE|" "$EDITOR_ENV_FILE"
    log_debug "Updated $EDITOR_ENV_FILE"
else
    log_debug "Editor environment file not found: $EDITOR_ENV_FILE"
fi

# Set for current session
export EDITOR="$EDITOR_CHOICE"
export VISUAL="$EDITOR_CHOICE"
log_debug "Set environment variables for current session"

# Set git default editor (useful even if rarely used)
if command -v git >/dev/null 2>&1; then
    run_with_progress "configuring git default editor" git config --global core.editor "$EDITOR_CHOICE"
else
    log_debug "Skipped git configuration (git not available)"
fi

# Set systemd user environment for consistency
if command -v systemctl >/dev/null 2>&1; then
    log_step "setting systemd user environment"
    systemctl --user set-environment EDITOR="$EDITOR_CHOICE" 2>/dev/null || true
    systemctl --user set-environment VISUAL="$EDITOR_CHOICE" 2>/dev/null || true
    log_debug "Systemd user environment updated"
else
    log_debug "Skipped systemd configuration (systemctl not available)"
fi