from __future__ import annotations

import tomllib
from dataclasses import dataclass, field
from pathlib import Path

from kitbash.exceptions import ConfigError

DEFAULT_CONFIG_PATH = Path.home() / ".config" / "kitbash" / "kit.toml"

# Validated system fields: field name → supported values
SUPPORTED: dict[str, list[str]] = {
    "wm":       ["niri", "hyprland", "sway"],
    "terminal": ["alacritty", "kitty", "foot", "wezterm"],
    "editor":   ["nvim", "vim", "nano", "emacs", "code"],
    "shell":    ["zsh", "bash", "fish"],
    "sound":    ["pipewire"],
    "greeter":  ["greetd", "sddm"],
}

# System fields that accept any free-form string (no fixed set)
FREEFORM: list[str] = ["hostname", "cursor", "font", "wallpaper"]


@dataclass
class SystemConfig:
    hostname: str = ""
    wm: str = ""
    terminal: str = ""
    editor: str = ""
    shell: str = ""
    sound: str = ""
    greeter: str = ""
    cursor: str = ""
    font: str = ""
    wallpaper: str = ""


@dataclass
class DotfilesConfig:
    repo: str = ""
    branch: str = "main"


@dataclass
class TranslationsConfig:
    """
    Per-manager package name overrides. User entries win over built-in defaults.

    In kit.toml:
        [translations.pacman]
        some-logical-name = "arch-package-name"

        [translations.apt]
        some-logical-name = "debian-package-name"

        [translations.dnf]
        some-logical-name = "fedora-package-name"
    """
    pacman: dict[str, str] = field(default_factory=dict)
    apt: dict[str, str] = field(default_factory=dict)
    dnf: dict[str, str] = field(default_factory=dict)


@dataclass
class PacmanConfig:
    """
    Arch/pacman-specific settings.

    In kit.toml:
        [pacman]
        aur_helper = "paru"   # "paru" | "yay" — omit to auto-detect
    """
    aur_helper: str = ""


@dataclass
class Config:
    system: SystemConfig = field(default_factory=SystemConfig)
    dotfiles: DotfilesConfig = field(default_factory=DotfilesConfig)
    modules: dict[str, bool | str] = field(default_factory=dict)
    translations: TranslationsConfig = field(default_factory=TranslationsConfig)
    pacman: PacmanConfig = field(default_factory=PacmanConfig)

    @classmethod
    def load(cls, path: Path = DEFAULT_CONFIG_PATH) -> Config:
        if not path.exists():
            raise ConfigError(
                f"Config file not found: {path}\n"
                "Copy kit.toml.example to that path and edit it."
            )

        try:
            with open(path, "rb") as f:
                data = tomllib.load(f)
        except tomllib.TOMLDecodeError as e:
            raise ConfigError(f"Invalid TOML in {path}: {e}") from e

        raw_system = data.get("system", {})
        raw_dotfiles = data.get("dotfiles", {})
        raw_translations = data.get("translations", {})
        raw_pacman = data.get("pacman", {})

        system = SystemConfig(
            hostname=raw_system.get("hostname", ""),
            wm=raw_system.get("wm", ""),
            terminal=raw_system.get("terminal", ""),
            editor=raw_system.get("editor", ""),
            shell=raw_system.get("shell", ""),
            sound=raw_system.get("sound", ""),
            greeter=raw_system.get("greeter", ""),
            cursor=raw_system.get("cursor", ""),
            font=raw_system.get("font", ""),
            wallpaper=raw_system.get("wallpaper", ""),
        )

        dotfiles = DotfilesConfig(
            repo=raw_dotfiles.get("repo", ""),
            branch=raw_dotfiles.get("branch", "main"),
        )

        translations = TranslationsConfig(
            pacman=raw_translations.get("pacman", {}),
            apt=raw_translations.get("apt", {}),
            dnf=raw_translations.get("dnf", {}),
        )

        pacman = PacmanConfig(
            aur_helper=raw_pacman.get("aur_helper", ""),
        )

        modules = data.get("modules", {})

        config = cls(
            system=system,
            dotfiles=dotfiles,
            modules=modules,
            translations=translations,
            pacman=pacman,
        )
        config._validate()
        return config

    @classmethod
    def empty(cls) -> Config:
        """Return an empty config — useful in tests."""
        return cls()

    def _validate(self) -> None:
        errors: list[str] = []
        for field_name, supported in SUPPORTED.items():
            value = getattr(self.system, field_name, "")
            if value and value not in supported:
                errors.append(
                    f"  system.{field_name} = {value!r} — "
                    f"supported: {' | '.join(repr(v) for v in supported)}"
                )
        if errors:
            raise ConfigError("Invalid configuration values:\n" + "\n".join(errors))

    def is_enabled(self, module_name: str) -> bool | str:
        """
        Return False if module is disabled/unset.
        Return True if enabled as boolean.
        Return the string value if configured with a string.
        """
        val = self.modules.get(module_name, False)
        if val is False or val == "" or val == "false":
            return False
        return val
