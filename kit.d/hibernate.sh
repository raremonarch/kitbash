#!/bin/bash

# Module: hibernate.sh
# Purpose: Configure system hibernation via swapfile on ext4
# Tier: 1 (System Fundamentals)
# Description: Creates a swapfile, registers it in fstab, and adds resume kernel
#              parameters to the systemd-boot entry so the system can hibernate.
#              Uses fallocate for instant allocation. Works with systemd-based
#              initramfs (no resume hook needed — systemd handles it natively).
# Installs: none (configuration only)

SWAPFILE="${_hibernate_swapfile:-/swapfile}"
BOOT_ENTRY="${_hibernate_boot_entry:-/boot/loader/entries/arch.conf}"

# Auto-size to match RAM if not specified (minimum required for hibernation)
RAM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
SWAP_MB="${1:-${_hibernate_swap_size:-$RAM_MB}}"

log_info "Configuring system hibernation (swapfile: ${SWAP_MB}MB)"

# ─── Validate prerequisites ───────────────────────────────────────────────────

if [ ! -f "$BOOT_ENTRY" ]; then
    log_error "Boot entry not found: $BOOT_ENTRY"
    log_error "Set _hibernate_boot_entry in kit.conf to the correct path"
    exit $KIT_EXIT_CONFIG_INVALID
fi

ROOT_FS=$(findmnt -n -o FSTYPE /)
if [ "$ROOT_FS" != "ext4" ]; then
    log_warning "Root filesystem is '$ROOT_FS', not ext4"
    log_warning "Swapfile hibernation on $ROOT_FS may require different setup (e.g. btrfs needs extra steps)"
fi

# ─── Idempotency checks ───────────────────────────────────────────────────────

SWAPFILE_DONE=false
FSTAB_DONE=false
KERNEL_PARAMS_DONE=false

[ -f "$SWAPFILE" ] && SWAPFILE_DONE=true
grep -q "^$SWAPFILE " /etc/fstab 2>/dev/null && FSTAB_DONE=true
grep -q 'resume=' "$BOOT_ENTRY" 2>/dev/null && KERNEL_PARAMS_DONE=true

if $SWAPFILE_DONE && $FSTAB_DONE && $KERNEL_PARAMS_DONE; then
    log_success "Hibernation is already configured"
    exit 0
fi

# ─── Step 1: Create swapfile ─────────────────────────────────────────────────

if ! $SWAPFILE_DONE; then
    log_step "allocating ${SWAP_MB}MB swapfile at $SWAPFILE"

    if ! run_with_progress "allocating swapfile" sudo fallocate -l "${SWAP_MB}M" "$SWAPFILE"; then
        log_error "fallocate failed — trying dd as fallback"
        if ! run_with_progress "allocating swapfile (dd)" \
            sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SWAP_MB" status=none; then
            log_error "Failed to create swapfile at $SWAPFILE"
            exit $KIT_EXIT_MODULE_FAILED
        fi
    fi

    run_with_progress "setting permissions" sudo chmod 600 "$SWAPFILE"
    run_with_progress "formatting swapfile" sudo mkswap "$SWAPFILE"
    run_with_progress "activating swapfile" sudo swapon "$SWAPFILE"
else
    log_debug "swapfile already exists at $SWAPFILE"
fi

# ─── Step 2: Register in /etc/fstab ──────────────────────────────────────────

if ! $FSTAB_DONE; then
    log_step "adding swapfile to /etc/fstab"
    echo "$SWAPFILE none swap defaults 0 0" | sudo tee -a /etc/fstab > /dev/null
else
    log_debug "fstab entry already present"
fi

# ─── Step 3: Determine resume parameters ─────────────────────────────────────

ROOT_UUID=$(findmnt -n -o UUID /)
if [ -z "$ROOT_UUID" ]; then
    log_error "Could not determine UUID of root filesystem"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Physical offset of the first swapfile extent (required for kernel resume)
RESUME_OFFSET=$(sudo filefrag -v "$SWAPFILE" 2>/dev/null | awk '$1 == "0:" {print $4+0}')
if [ -z "$RESUME_OFFSET" ] || [ "$RESUME_OFFSET" -eq 0 ] 2>/dev/null; then
    log_error "Could not determine swapfile physical offset (filefrag output unexpected)"
    exit $KIT_EXIT_MODULE_FAILED
fi

log_debug "resume UUID=$ROOT_UUID offset=$RESUME_OFFSET"

# ─── Step 4: Add resume params to boot entry ─────────────────────────────────

if ! $KERNEL_PARAMS_DONE; then
    log_step "adding resume parameters to $BOOT_ENTRY"
    sudo sed -i "s|^options .*|& resume=UUID=$ROOT_UUID resume_offset=$RESUME_OFFSET|" "$BOOT_ENTRY"

    # Verify the change was applied
    if ! grep -q 'resume=' "$BOOT_ENTRY"; then
        log_error "Failed to update boot entry — check $BOOT_ENTRY manually"
        exit $KIT_EXIT_MODULE_FAILED
    fi
else
    log_debug "kernel resume parameters already set"
fi

log_success "Hibernation configured — reboot required to activate"
log_info "  Test with: systemctl hibernate"
log_info "  Swapfile:  $SWAPFILE (${SWAP_MB}MB)"
log_info "  UUID:      $ROOT_UUID"
log_info "  Offset:    $RESUME_OFFSET"
