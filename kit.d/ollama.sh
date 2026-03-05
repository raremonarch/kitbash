#!/bin/bash

# Module: ollama.sh
# Purpose: Install Ollama AI runtime as systemd service
# Tier: 5 (Applications)
# Description: Ollama AI model runtime installed from tarball as a systemd service
# Installs: ollama (binary: /usr/bin/ollama, systemd service: ollama)

log_info "Installing Ollama manually"

# Check if upgrading from prior version and remove old libraries
if [ -d "/usr/lib/ollama" ]; then
    log_step "removing old Ollama libraries"
    sudo rm -rf /usr/lib/ollama
fi

# Download and extract the package
if ! run_with_progress "downloading Ollama for Linux AMD64" curl -LO https://ollama.com/download/ollama-linux-amd64.tgz; then
    log_error "Failed to download Ollama package"
    exit 1
fi

if ! run_with_progress "extracting Ollama package" sudo tar -C /usr -xzf ollama-linux-amd64.tgz; then
    log_error "Failed to extract Ollama package"
    exit 1
fi

# Clean up downloaded archive
log_step "cleaning up downloaded archive"
rm ollama-linux-amd64.tgz

# Create ollama user and group for the service
log_step "creating ollama user and group"
sudo useradd -r -s /bin/false -U -m -d /usr/share/ollama ollama 2>/dev/null || true
sudo usermod -a -G ollama $(whoami)

# Create systemd service file
log_step "creating systemd service file"
sudo tee /etc/systemd/system/ollama.service > /dev/null << 'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=$PATH"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service
run_with_progress "reloading systemd daemon" sudo systemctl daemon-reload
run_with_progress "enabling Ollama service" sudo systemctl enable ollama

# Start the service
run_with_progress "starting Ollama service" sudo systemctl start ollama

# Wait a moment for service to start
log_step "waiting for service to start"
sleep 3

# Verify installation
log_step "verifying Ollama installation"
if sudo systemctl is-active --quiet ollama; then
    log_debug "Ollama service is running successfully"

    # Test ollama command
    if command -v ollama >/dev/null 2>&1; then
        log_debug "Ollama binary is accessible"
        ollama --version >> "$LOG_FILE" 2>&1
        log_success "Ollama installation completed successfully"
        log_debug "You can now run 'ollama pull <model>' to download models"
        log_debug "Example: ollama pull llama3.2"
    else
        log_error "Ollama binary not found in PATH"
        exit 1
    fi
else
    log_error "Ollama service failed to start - check logs with: sudo journalctl -e -u ollama"
    exit 1
fi