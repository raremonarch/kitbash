# Example usage: curl -fsSL https://raw.githubusercontent.com/raremonarch/kitbash/main/install.sh | bash

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

# Run installation
install_kit
