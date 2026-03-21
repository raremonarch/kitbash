#!/bin/bash

# Module: hostname.sh
# Purpose: Set system hostname via hostnamectl
# Tier: 1 (System Fundamentals)
# Description: Sets the system hostname using hostnamectl
# Installs: none (configuration only)

# Check if hostname is provided as first parameter
if [ -z "$1" ]; then
    log_error "No hostname provided. Usage: $0 <new_hostname>"
    return 1
fi

# Update hostname
new_hostname="$1"
log_debug "Setting hostname to: $new_hostname"

if ! run_with_progress "updating hostname to '$new_hostname'" sudo hostnamectl hostname "$1"; then
    log_error "Failed to update hostname"
    return 1
fi

# Verify update (use hostnamectl to avoid requiring the 'hostname' command)
if hostnamectl hostname 2>/dev/null | grep -qxF "$1"; then
    log_debug "Hostname verified: $new_hostname"
else
    log_error "Failed to verify hostname update"
    return 1
fi