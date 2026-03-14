# Usage:
#   Install:   curl -fsSL https://raw.githubusercontent.com/raremonarch/kitbash/main/install.sh | bash
#   Uninstall: curl -fsSL https://raw.githubusercontent.com/raremonarch/kitbash/main/install.sh | bash -s -- --uninstall
#   Or if already cloned: bash ~/code/raremonarch/kitbash/install.sh --uninstall

repo_name=kitbash
gh_username=raremonarch

target_dir="$HOME/code/$gh_username/$repo_name"
alias_name="${KITBASH_ALIAS:-kit}"

# Function to add or update kit alias in .bashrc
set_alias_kit() {
    local alias_path="$1"
    if grep -q "${alias_name}.*kit-start.sh" "$HOME/.bashrc" 2>/dev/null; then
        sed -i.bak "/${alias_name}.*kit-start.sh/c\alias ${alias_name}=$alias_path" "$HOME/.bashrc"
    else
        echo "alias ${alias_name}=$alias_path" >> "$HOME/.bashrc"
    fi
}

# Function to uninstall kitbash
uninstall_kit() {
    local removed=0

    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
        echo "Removed $target_dir"
        removed=1
    else
        echo "Kitbash directory not found at $target_dir — skipping"
    fi

    if grep -q "${alias_name}.*kit-start.sh" "$HOME/.bashrc" 2>/dev/null; then
        sed -i.bak "/${alias_name}.*kit-start.sh/d" "$HOME/.bashrc"
        echo "Removed '${alias_name}' alias from ~/.bashrc"
        removed=1
    else
        echo "Alias '${alias_name}' not found in ~/.bashrc — skipping"
    fi

    if [ $removed -eq 1 ]; then
        echo ""
        echo "Kitbash uninstalled. Run 'source ~/.bashrc' to apply alias removal."
    fi
}

# Function to install kitbash
install_kit() {
    if [ -d "$target_dir" ]; then
        echo "Kitbash already installed at $target_dir"
    else
        mkdir -p "$(dirname "$target_dir")"
        git clone -q https://github.com/$gh_username/$repo_name "$target_dir"
        chmod +x "$target_dir/kit-start.sh"
    fi

    # Set up the alias
    set_alias_kit "$target_dir/kit-start.sh"

    echo ""
    echo " _  _____ _____ ____    _    ____  _   _ "
    echo "| |/ /_ _|_   _| __ )  / \  / ___|| | | |"
    echo "| ' / | |  | | |  _ \ / _ \ \___ \| |_| |"
    echo "| . \ | |  | | | |_) / ___ \ ___) |  _  |"
    echo "|_|\_\___| |_| |____/_/   \_\____/|_| |_|"
    echo ""
    echo "Setup complete! Alias '${alias_name}' added to ~/.bashrc"
    echo ""
    echo "To use the alias now, run:"
    echo "  source ~/.bashrc"
    echo ""
    echo "Or simply open a new terminal window."
}

# Run installation or uninstallation
case "${1:-}" in
    --uninstall) uninstall_kit ;;
    *)           install_kit ;;
esac
