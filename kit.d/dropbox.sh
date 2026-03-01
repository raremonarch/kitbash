#!/bin/bash

# Module: dropbox.sh
# Purpose: Install Dropbox daemon (headless tarball install, no Nautilus dependency)
# Tier: 5 (Applications)
#
# Note: The nautilus-dropbox RPM hard-depends on nautilus-extensions, making it
# unsuitable for non-GNOME desktops. This uses the headless tarball instead,
# which installs only the daemon and CLI.

log_info "Installing Dropbox"

DROPBOX_DIST="$HOME/.dropbox-dist"
DROPBOX_CLI="$HOME/.local/bin/dropbox"

# Check if Dropbox daemon is already installed
if [ -x "$DROPBOX_DIST/dropboxd" ]; then
    log_success "Dropbox is already installed"
    exit 0
fi

# Download and extract the Dropbox daemon to ~/.dropbox-dist/
if ! run_with_progress "downloading Dropbox daemon" \
    bash -c "curl -L 'https://www.dropbox.com/download?plat=lnx.x86_64' | tar xzf - -C '$HOME'"; then
    log_error "Failed to download Dropbox daemon"
    exit $KIT_EXIT_NETWORK_ERROR
fi

# Download the Dropbox CLI management script
mkdir -p "$HOME/.local/bin"
if ! run_with_progress "downloading Dropbox CLI" \
    curl -L -o "$DROPBOX_CLI" "https://www.dropbox.com/download?dl=packages/dropbox.py"; then
    log_error "Failed to download Dropbox CLI"
    exit $KIT_EXIT_NETWORK_ERROR
fi
chmod +x "$DROPBOX_CLI"

# Create a systemd user service for auto-start
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/dropbox.service" << 'EOF'
[Unit]
Description=Dropbox Daemon
After=network-online.target

[Service]
ExecStart=%h/.dropbox-dist/dropboxd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

run_with_progress "enabling Dropbox service" \
    bash -c "systemctl --user daemon-reload && systemctl --user enable dropbox"

# Verify
if [ -x "$DROPBOX_DIST/dropboxd" ]; then
    log_success "Dropbox installed successfully"
    log_step "run 'systemctl --user start dropbox' to launch and sign in"
    exit 0
else
    log_error "Dropbox installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
