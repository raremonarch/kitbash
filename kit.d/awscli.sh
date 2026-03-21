#!/bin/bash

# Module: awscli.sh
# Purpose: Install AWS Command Line Interface v2 (awscli)
# Tier: 4 (Applications)
# Description: AWS CLI v2 downloaded and installed to /usr/local/bin
# Installs: aws (binary: /usr/local/bin/aws)

log_info "Setting up AWS CLI v2"

# Check if AWS CLI v2 is already installed
if command -v aws >/dev/null 2>&1; then
    AWS_VERSION=$(aws --version 2>&1 | head -n1 || echo "unknown")

    # Check if it's v2
    if echo "$AWS_VERSION" | grep -q "aws-cli/2"; then
        log_debug "AWS CLI v2 is already installed: $AWS_VERSION"
        log_success "AWS CLI v2 is already installed"
        exit 0
    else
        log_warning "AWS CLI v1 detected: $AWS_VERSION"
        log_info "Upgrading to AWS CLI v2 for SSO support"
        # Remove v1 if present
        if rpm -q awscli >/dev/null 2>&1; then
            log_step "removing AWS CLI v1"
            if ! run_with_progress "removing awscli v1 package" \
                sudo dnf remove -y awscli; then
                log_warning "Failed to remove AWS CLI v1, continuing anyway"
            fi
        fi
    fi
fi

# Install AWS CLI v2 from official installer
log_step "downloading AWS CLI v2 installer"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

if ! run_with_progress "downloading awscliv2.zip" \
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TEMP_DIR/awscliv2.zip"; then
    log_error "Failed to download AWS CLI v2"
    exit $KIT_EXIT_NETWORK_ERROR
fi

# Unzip and install
log_step "installing AWS CLI v2"
if ! run_with_progress "extracting installer" \
    unzip -q "$TEMP_DIR/awscliv2.zip" -d "$TEMP_DIR"; then
    log_error "Failed to extract AWS CLI v2 installer"
    exit $KIT_EXIT_MODULE_FAILED
fi

if ! run_with_progress "running AWS CLI v2 installer" \
    sudo "$TEMP_DIR/aws/install" --update; then
    log_error "Failed to install AWS CLI v2"
    log_error "Check ~/kit.log for details"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v aws >/dev/null 2>&1; then
    AWS_VERSION=$(aws --version 2>&1 | head -n1 || echo "installed")
    if echo "$AWS_VERSION" | grep -q "aws-cli/2"; then
        log_debug "AWS CLI v2 installed successfully: $AWS_VERSION"
    else
        log_error "AWS CLI v2 installation verification failed - wrong version"
        exit $KIT_EXIT_MODULE_FAILED
    fi
else
    log_error "AWS CLI v2 installation verification failed - command not found"
    exit $KIT_EXIT_MODULE_FAILED
fi

log_success "AWS CLI v2 installation completed successfully"
log_info "Note: Use 'aws configure sso' for SSO setup or 'aws configure' for access keys"
log_info "Note: Credentials stored in ~/.aws/credentials, config in ~/.aws/config"
exit 0
