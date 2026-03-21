#!/bin/bash

# Module: greetd.sh
# Purpose: Install and configure greetd + gtkgreet display manager
# Tier: 1 (System Fundamentals)
# Description: greetd display manager with gtkgreet frontend and cage Wayland compositor
# Installs: greetd, gtkgreet, cage
# Config-var: _display_manager
# Config-match: greetd

log_info "Setting up greetd display manager with gtkgreet"

# Check if greetd is already installed
if command -v greetd >/dev/null 2>&1 && command -v gtkgreet >/dev/null 2>&1 && command -v cage >/dev/null 2>&1; then
    log_success "greetd, gtkgreet, and cage are already installed"
    exit 0
fi

# Install greetd, gtkgreet, and cage (Wayland compositor wrapper)
log_step "installing greetd, gtkgreet, and cage packages"
if ! run_with_progress "installing packages" sudo dnf install -y greetd gtkgreet cage; then
    log_error "Failed to install greetd/gtkgreet/cage"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Create greetd configuration
log_step "configuring greetd"
GREETD_CONFIG="/etc/greetd/config.toml"

sudo mkdir -p /etc/greetd

sudo tee "$GREETD_CONFIG" > /dev/null << 'EOF'
[terminal]
vt = 1

[default_session]
command = "cage -s -- gtkgreet -l"
user = "greeter"
EOF

log_debug "greetd configuration created at $GREETD_CONFIG"

# Create gtkgreet CSS theme
log_step "creating gtkgreet theme"
GTKGREET_CSS_USER="$HOME/.config/gtkgreet/style.css"
GTKGREET_CSS_GREETER="/var/lib/greeter/.config/gtkgreet/style.css"

mkdir -p "$HOME/.config/gtkgreet"

cat > "$GTKGREET_CSS_USER" << 'EOF'
/* Catppuccin Frappé theme for gtkgreet */

* {
    font-family: "AudioLink Mono";
}

window {
    background-image: url("/usr/share/backgrounds/wallpaper.jpg");
    background-size: cover;
    background-position: center;
}

/* Dark overlay for readability */
#window-overlay {
    background-color: rgba(35, 38, 52, 0.85);
}

/* Main container */
box {
    background-color: transparent;
}

/* Username/session labels */
label {
    color: #c6d0f5;
    font-size: 14px;
}

/* Input fields */
entry {
    background-color: #303446;
    color: #c6d0f5;
    border: 2px solid #ca9ee6;
    border-radius: 0px;
    padding: 12px;
    font-size: 14px;
    min-width: 300px;
    min-height: 40px;
}

entry:focus {
    border-color: #ca9ee6;
    background-color: #303446;
}

entry selection {
    background-color: #ca9ee6;
    color: #303446;
}

/* Buttons */
button {
    background-color: #303446;
    color: #c6d0f5;
    border: 1px solid #ca9ee6;
    border-radius: 0px;
    padding: 10px 20px;
    font-size: 12px;
    margin: 4px;
}

button:hover {
    background-color: #414559;
    border-color: #babbf1;
}

button:active,
button:checked {
    background-color: #ca9ee6;
    color: #303446;
}

/* Dropdown/ComboBox */
combobox {
    background-color: #303446;
    color: #c6d0f5;
    border: 1px solid #ca9ee6;
    border-radius: 0px;
}

combobox button {
    background-color: transparent;
    border: none;
}

/* Clock/time display if shown */
.clock {
    color: #c6d0f5;
    font-size: 120px;
    font-weight: 300;
}

/* Error messages */
.error {
    color: #e78284;
    font-size: 14px;
}

/* Success messages */
.success {
    color: #a6d189;
    font-size: 14px;
}
EOF

log_debug "gtkgreet CSS theme created at $GTKGREET_CSS_USER"

# Copy CSS to greeter user directory
log_step "installing theme for greeter user"
sudo mkdir -p /var/lib/greeter/.config/gtkgreet
sudo cp "$GTKGREET_CSS_USER" "$GTKGREET_CSS_GREETER"
sudo chown -R greeter:greeter /var/lib/greeter/.config 2>/dev/null || true

log_debug "gtkgreet theme installed for greeter user"

# Disable SDDM if it's enabled
if systemctl is-enabled sddm >/dev/null 2>&1; then
    log_step "disabling SDDM display manager"
    if run_with_progress "disabling SDDM" sudo systemctl disable sddm; then
        log_debug "SDDM disabled successfully"
    else
        log_warning "Failed to disable SDDM"
    fi
fi

# Enable greetd
log_step "enabling greetd display manager"
if run_with_progress "enabling greetd" sudo systemctl enable greetd; then
    log_debug "greetd enabled successfully"
else
    log_error "Failed to enable greetd"
    exit $KIT_EXIT_MODULE_FAILED
fi

log_success "greetd display manager configured successfully"
log_info "Reboot to see the new login screen"

exit 0
