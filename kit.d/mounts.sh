#!/bin/bash

# Module: mounts.sh
# Purpose: Configure network and local mount points with safety checks
# Tier: 5 (System Services)
# Description: Configures CIFS/NFS network and local disk mounts in /etc/fstab
# Installs: none (configuration only)

log_info "Setting up mounts and symlinks"

# Function to check if a device UUID exists
check_device_exists() {
    local uuid="$1"
    if [[ "$uuid" == UUID=* ]]; then
        # Extract just the UUID part
        local uuid_value="${uuid#UUID=}"
        if blkid -U "$uuid_value" &>/dev/null; then
            return 0  # Device exists
        else
            return 1  # Device does not exist
        fi
    fi
    return 0  # Not a UUID, assume it exists (network share, etc.)
}

# Function to check network connectivity for CIFS/NFS
check_network_available() {
    local source="$1"
    if [[ "$source" == //* ]]; then
        # CIFS share - extract hostname
        local hostname="${source#//}"
        hostname="${hostname%%/*}"
        if ping -c 1 -W 2 "$hostname" &>/dev/null; then
            return 0  # Network host reachable
        else
            return 1  # Network host unreachable
        fi
    fi
    return 0  # Not a network share
}

# Function to process mount configurations
process_mount_config() {
    local config="$1"
    local mount_type="$2"
    
    # Skip comments
    [[ "$config" =~ ^[[:space:]]*# ]] && return 0
    
    # Parse configuration: "source:mount_point:home_symlink,option1=value,option2=value"
    IFS=':' read -r source mount_point symlink_and_options <<< "$config"
    
    # Split symlink and options
    IFS=',' read -r home_symlink options <<< "$symlink_and_options"
    
    # Expand tilde in home_symlink and credential files
    home_symlink=$(eval echo "$home_symlink")

    log_debug ""
    log_debug "Processing ($mount_type): $source -> $mount_point -> $home_symlink"

    # SAFETY CHECK: Verify device/network availability
    if [ "$mount_type" = "local" ]; then
        if ! check_device_exists "$source"; then
            log_warning "SKIPPING: Device $source not found on this system (normal when running on different hardware)"
            return 0
        fi
    elif [ "$mount_type" = "network" ]; then
        if ! check_network_available "$source"; then
            log_warning "SKIPPING: Network host for $source not reachable (normal when running on different networks)"
            return 0
        fi
    fi
    
    # Determine filesystem type and build mount options based on mount type
    if [ "$mount_type" = "network" ]; then
        if [[ "$source" == //* ]]; then
            # CIFS/SMB share
            fs_type="cifs"
            base_options="uid=$USER,gid=$USER,file_mode=0777,dir_mode=0777,_netdev,noauto"

            # Process custom options
            if [ -n "$options" ]; then
                # Expand tilde in credential file paths
                processed_options=""
                for opt in $(echo "$options" | tr ',' ' '); do
                    if [[ "$opt" == credfile=* ]]; then
                        credpath="${opt#credfile=}"
                        credpath=$(eval echo "$credpath")
                        # Check if credential file exists
                        if [ ! -f "$credpath" ]; then
                            log_warning "Credential file $credpath not found - mount will be added to fstab but may fail until credentials are provided"
                        fi
                        processed_options="${processed_options},credentials=$credpath"
                    else
                        processed_options="${processed_options},$opt"
                    fi
                done
                fstab_options="$base_options$processed_options"
            else
                fstab_options="$base_options"
            fi
        else
            # Assume NFS
            fs_type="nfs"
            # fstab expects the fstype in column 3 and options in column 4
            fstab_options="defaults,_netdev,noauto"
            if [ -n "$options" ]; then
                fstab_options="$fstab_options,$options"
            fi
        fi
    else
        # Local mount
        fs_type="exfat"
        base_options="uid=$USER,gid=$USER,dmask=0022,fmask=0133,noauto"
        if [ -n "$options" ]; then
            fstab_options="$base_options,$options"
        else
            fstab_options="$base_options"
        fi
    fi
    
    # Create mount point directory
    if ! run_with_progress "creating mount point '$mount_point'" sudo mkdir -p "$mount_point"; then
        return 1
    fi

    # Set proper ownership for mount point
    if ! run_with_progress "setting ownership of '$mount_point'" sudo chown "$USER:$USER" "$mount_point"; then
        log_warning "failed to set ownership (continuing anyway)"
    fi
    
    # Create home symlink if specified
    if [ -n "$home_symlink" ]; then
        # Create home symlink directory if it doesn't exist
        symlink_dir=$(dirname "$home_symlink")
        if [ ! -d "$symlink_dir" ]; then
            if ! run_with_progress "creating symlink directory '$symlink_dir'" mkdir -p "$symlink_dir"; then
                return 1
            fi
        fi

        # Create or update symlink
        if [ -L "$home_symlink" ]; then
            # Remove existing symlink
            rm "$home_symlink"
        elif [ -e "$home_symlink" ]; then
            log_error "Cannot create symlink - target exists and is not a symlink: $home_symlink"
            return 1
        fi

        if ! run_with_progress "creating symlink '$home_symlink' -> '$mount_point'" ln -s "$mount_point" "$home_symlink"; then
            return 1
        fi
    else
        log_debug "skipping symlink creation (none specified)"
    fi
    

    # Check if fstab entry exists and update it
    log_step "checking /etc/fstab entry"
    if grep -q "^[[:space:]]*$source " /etc/fstab 2>/dev/null; then
        log_debug "found existing entry, updating with current options"
        # Remove existing entry and add new one
        sudo sed -i "\|^[[:space:]]*$source |d" /etc/fstab
        echo "$source $mount_point $fs_type $fstab_options 0 0" | sudo tee -a /etc/fstab > /dev/null
        log_debug "updated fstab entry (with noauto for safety)"
    elif grep -q "^[[:space:]]*#.*$source " /etc/fstab 2>/dev/null; then
        log_debug "found commented entry, updating and enabling"
        # Remove commented entry and add new active one
        sudo sed -i "\|^[[:space:]]*#.*$source |d" /etc/fstab
        echo "$source $mount_point $fs_type $fstab_options 0 0" | sudo tee -a /etc/fstab > /dev/null
        log_debug "added active fstab entry (with noauto for safety)"
    else
        log_debug "no existing entry, adding new entry"
        echo "$source $mount_point $fs_type $fstab_options 0 0" | sudo tee -a /etc/fstab > /dev/null
        log_debug "added to fstab (with noauto for safety)"
    fi

    # Reload systemd after fstab changes
    if ! run_with_progress "reloading systemd units" sudo systemctl daemon-reload 2>/dev/null; then
        log_warning "failed to reload systemd (continuing anyway)"
    fi

    # Try to mount if possible (but don't fail if it doesn't work)
    log_step "attempting to mount"
    if sudo mount "$mount_point" 2>/dev/null; then
        log_debug "successfully mounted"
    else
        log_debug "mount failed (but fstab entry created for manual mounting)"
        log_debug "Use: sudo mount $mount_point"
    fi
}

# Process network mounts
if [ -n "${_network_mounts[*]}" ]; then
    log_debug ""
    log_info "Processing Network Mounts"
    for config in "${_network_mounts[@]}"; do
        process_mount_config "$config" "network"
    done
else
    log_debug "No network mount configurations defined in kit.conf"
fi

# Process local media drives
if [ -n "${_local_media[*]}" ]; then
    log_debug ""
    log_info "Processing Local Media Drives"
    for config in "${_local_media[@]}"; do
        process_mount_config "$config" "local"
    done
else
    log_debug "No local media drive configurations defined in kit.conf"
fi

log_debug ""
log_info "Mount Setup Results"
log_step "All mounts configured with 'noauto' for system safety"
log_step "Use 'sudo mount <mount_point>' to manually mount when needed"

# Show network mount results
if [ -n "${_network_mounts[*]}" ]; then
    log_debug ""
    log_debug "Network Mounts:"
    for config in "${_network_mounts[@]}"; do
        # Skip comments
        [[ "$config" =~ ^[[:space:]]*# ]] && continue

        # Parse configuration to get mount point and symlink
        IFS=':' read -r source mount_point symlink_and_options <<< "$config"
        IFS=',' read -r home_symlink options <<< "$symlink_and_options"
        home_symlink=$(eval echo "$home_symlink")

        # Check availability first
        if ! check_network_available "$source"; then
            log_debug "  $source -> SKIPPED (network unreachable)"
            continue
        fi

        # Check final status
        if mountpoint -q "$mount_point" 2>/dev/null; then
            mount_status="mounted: $mount_point"
        else
            mount_status="ready: $mount_point (use: sudo mount $mount_point)"
        fi

        if [ -n "$home_symlink" ]; then
            if [ -L "$home_symlink" ]; then
                symlink_status="linked: $home_symlink"
            else
                symlink_status="no link: $home_symlink"
            fi
            log_debug "  $source -> $mount_status, $symlink_status"
        else
            log_debug "  $source -> $mount_status"
        fi
    done
fi

# Show local media drive results
if [ -n "${_local_media[*]}" ]; then
    log_debug ""
    log_debug "Local Media Drives:"
    for config in "${_local_media[@]}"; do
        # Skip comments
        [[ "$config" =~ ^[[:space:]]*# ]] && continue

        # Parse configuration to get mount point and symlink
        IFS=':' read -r source mount_point symlink_and_options <<< "$config"
        IFS=',' read -r home_symlink options <<< "$symlink_and_options"
        home_symlink=$(eval echo "$home_symlink")

        # Check device availability first
        if ! check_device_exists "$source"; then
            log_debug "  $source -> SKIPPED (device not found on this system)"
            continue
        fi

        # Check final status
        if mountpoint -q "$mount_point" 2>/dev/null; then
            mount_status="mounted: $mount_point"
        else
            mount_status="ready: $mount_point (use: sudo mount $mount_point)"
        fi

        if [ -n "$home_symlink" ]; then
            if [ -L "$home_symlink" ]; then
                symlink_status="linked: $home_symlink"
            else
                symlink_status="no link: $home_symlink"
            fi
            log_debug "  $source -> $mount_status, $symlink_status"
        else
            log_debug "  $source -> $mount_status"
        fi
    done
fi

# Function to organize fstab entries into logical groups
organize_fstab() {
    log_debug ""
    log_info "Organizing /etc/fstab"

    local temp_fstab="/tmp/fstab.organized"
    local original_fstab="/etc/fstab"

    # Extract the header comments
    log_step "organizing fstab entries"
    {
        # Header section
        grep "^#" "$original_fstab"
        echo ""

        # System mounts (/, /boot, /home, swap)
        echo "# System mounts"
        grep -E "^[^#].*[[:space:]]/(boot|home)?[[:space:]]" "$original_fstab" | grep -v "_netdev"
        echo ""

        # Network mounts (anything with _netdev)
        if grep -q "_netdev" "$original_fstab"; then
            echo "# Network mounts (noauto for safety)"
            grep "_netdev" "$original_fstab" | grep -v "^#"
            echo ""
        fi

        # Local media drives (exFAT, NTFS, etc. mounted to /media/)
        if grep -E "^UUID=.*[[:space:]]/media/" "$original_fstab" > /dev/null; then
            echo "# Local media drives (noauto for safety)"
            grep -E "^UUID=.*[[:space:]]/media/" "$original_fstab"
        fi

    } > "$temp_fstab"

    # Replace the original fstab with organized version
    if ! sudo cp "$temp_fstab" "$original_fstab"; then
        log_error "failed to organize fstab"
        rm -f "$temp_fstab"
        return 1
    fi
    sudo rm -f "$temp_fstab"

    # Reload systemd after fstab reorganization
    if ! run_with_progress "reloading systemd after organization" sudo systemctl daemon-reload 2>/dev/null; then
        log_warning "failed to reload systemd (continuing anyway)"
    fi
}

# Organize fstab entries after all mounts are configured
organize_fstab

log_debug ""
log_info "SAFETY FEATURES ENABLED"
log_step "Device existence checks prevent non-existent UUID errors"
log_step "Network connectivity checks prevent unreachable mount failures"
log_step "All mounts use 'noauto' to prevent boot blocking"
log_step "Failed mounts are gracefully skipped with informative messages"
log_debug ""
log_step "To enable automatic mounting, remove 'noauto' from /etc/fstab entries"