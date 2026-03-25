# kitbash

Modular system configurator and application installer for Linux.

## Setup

```bash
pipx install .
kitbash init
```

> **Developers:** use `pip install -e ".[dev]"` inside a venv for an editable install with test dependencies.

## Usage

```bash
kitbash list                  # show all available modules
kitbash status                # show install status of all modules

kitbash install               # install all enabled modules
kitbash install docker        # install a single module

kitbash uninstall             # uninstall all modules (reverse order)
kitbash uninstall docker      # uninstall a single module
```

## Configuration

`kit.toml` has two sections:

**`[system]`** — required choices that are validated on startup:
```toml
[system]
hostname = "my-workstation"
wm = "niri"          # niri | hyprland | sway
terminal = "alacritty"
editor = "nvim"
shell = "zsh"
sound = "pipewire"
greeter = "greetd"
cursor = "Breeze"
```

**`[modules]`** — optional app installs, all default to false:
```toml
[modules]
docker = true
vscode = true
discord = false
```

Logs are written to `~/.local/state/kitbash/kit.log`.
