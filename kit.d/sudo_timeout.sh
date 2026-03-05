#!/bin/bash

# Module: sudo_timeout.sh
# Purpose: Configure sudo password cache timeout
# Tier: 1 (System Fundamentals)
# Description: Configures sudo password cache timeout via /etc/sudoers.d/kitbash-sudo
# Installs: none (configuration only)

# Determine timeout value - use parameter if provided, otherwise use config
timeout_value="${1:-$_sudo_timeout}"

# Skip if no timeout value provided
if [ -z "$timeout_value" ]; then
    log_debug "No sudo timeout configuration provided"
    return 0
fi

log_info "Configuring sudo timeout: $timeout_value minutes"

# Define paths
TEMPLATE_FILE="$HOME/system-configs/sudoers.d/user-timeout.template"
DOTFILES_CONFIG="$HOME/system-configs/sudoers.d/${USER}-timeout"
SYSTEM_CONFIG="/etc/sudoers.d/${USER}-timeout"

# Create sudoers config from template
log_step "generating configuration from template"
if [ -f "$TEMPLATE_FILE" ]; then
    # Use template and substitute variables
    sed -e "s/%USER%/${USER}/g" -e "s/%TIMEOUT%/${timeout_value}/g" "$TEMPLATE_FILE" > "$DOTFILES_CONFIG"
else
    # Fallback: create directly
    log_debug "no template found, creating directly"
    echo "Defaults:${USER} timestamp_timeout=${timeout_value}" > "$DOTFILES_CONFIG"
fi

# Install to system location
if ! run_with_progress "installing to system" sudo cp "$DOTFILES_CONFIG" "$SYSTEM_CONFIG"; then
    return 1
fi

# Set correct permissions (sudoers files must be mode 440)
if ! run_with_progress "setting permissions" sudo chmod 440 "$SYSTEM_CONFIG"; then
    return 1
fi

# Validate sudoers configuration
log_step "validating configuration"
if sudo visudo -c > /dev/null 2>&1; then
    log_debug "configuration is valid"
else
    log_error "Configuration is invalid - removing invalid configuration"
    sudo rm -f "$SYSTEM_CONFIG"
    rm -f "$DOTFILES_CONFIG"
    return 1
fi

# Clear current sudo timestamp to apply new settings
log_step "applying new timeout settings"
sudo -k 2>/dev/null

log_success "Sudo timeout configured: $timeout_value minutes"
log_debug "dotfiles config: $DOTFILES_CONFIG"
log_debug "system config: $SYSTEM_CONFIG"