from __future__ import annotations

from pathlib import Path

import pytest

from kitbash.config import Config
from kitbash.exceptions import ConfigError

VALID_TOML = """
[system]
hostname = "mybox"
wm = "niri"
terminal = "alacritty"
editor = "nvim"
shell = "zsh"
sound = "pipewire"
greeter = "greetd"
cursor = "Breeze"

[dotfiles]
repo = "https://github.com/user/dots.git"
branch = "main"

[modules]
docker = true
vscode = false
"""


def test_load_valid(tmp_path: Path) -> None:
    cfg_file = tmp_path / "kit.toml"
    cfg_file.write_text(VALID_TOML)
    config = Config.load(cfg_file)
    assert config.system.hostname == "mybox"
    assert config.system.wm == "niri"
    assert config.system.terminal == "alacritty"
    assert config.system.editor == "nvim"
    assert config.system.shell == "zsh"
    assert config.system.sound == "pipewire"
    assert config.system.greeter == "greetd"
    assert config.dotfiles.repo == "https://github.com/user/dots.git"
    assert config.dotfiles.branch == "main"
    assert config.modules["docker"] is True
    assert config.modules["vscode"] is False  # noqa: E501


def test_load_missing_raises(tmp_path: Path) -> None:
    with pytest.raises(ConfigError, match="not found"):
        Config.load(tmp_path / "nonexistent.toml")


def test_load_invalid_toml(tmp_path: Path) -> None:
    cfg_file = tmp_path / "kit.toml"
    cfg_file.write_text("this is not = valid [[toml")
    with pytest.raises(ConfigError, match="Invalid TOML"):
        Config.load(cfg_file)


def test_unsupported_wm_raises(tmp_path: Path) -> None:
    cfg_file = tmp_path / "kit.toml"
    cfg_file.write_text('[system]\nwm = "awesome"\n')
    with pytest.raises(ConfigError, match="system.wm"):
        Config.load(cfg_file)


def test_unsupported_terminal_raises(tmp_path: Path) -> None:
    cfg_file = tmp_path / "kit.toml"
    cfg_file.write_text('[system]\nterminal = "xterm"\n')
    with pytest.raises(ConfigError, match="system.terminal"):
        Config.load(cfg_file)


def test_multiple_invalid_fields_reported_together(tmp_path: Path) -> None:
    cfg_file = tmp_path / "kit.toml"
    cfg_file.write_text('[system]\nwm = "awesome"\nterminal = "xterm"\n')
    with pytest.raises(ConfigError) as exc_info:
        Config.load(cfg_file)
    msg = str(exc_info.value)
    assert "system.wm" in msg
    assert "system.terminal" in msg


def test_empty_system_fields_skip_validation(tmp_path: Path) -> None:
    # Unset fields are fine — validation only fires when a value is present
    cfg_file = tmp_path / "kit.toml"
    cfg_file.write_text("[system]\nhostname = \"mybox\"\n")
    config = Config.load(cfg_file)
    assert config.system.wm == ""


def test_dotfiles_defaults(tmp_path: Path) -> None:
    cfg_file = tmp_path / "kit.toml"
    cfg_file.write_text("[system]\n")
    config = Config.load(cfg_file)
    assert config.dotfiles.branch == "main"
    assert config.dotfiles.repo == ""


def test_is_enabled_true(tmp_path: Path) -> None:
    cfg_file = tmp_path / "kit.toml"
    cfg_file.write_text("[modules]\ndocker = true\n")
    config = Config.load(cfg_file)
    assert config.is_enabled("docker") is True


def test_is_enabled_false(tmp_path: Path) -> None:
    cfg_file = tmp_path / "kit.toml"
    cfg_file.write_text("[modules]\ndocker = false\n")
    config = Config.load(cfg_file)
    assert config.is_enabled("docker") is False


def test_is_enabled_unset() -> None:
    assert Config.empty().is_enabled("docker") is False


def test_is_enabled_string_value(tmp_path: Path) -> None:
    cfg_file = tmp_path / "kit.toml"
    cfg_file.write_text('[modules]\nterminal = "alacritty"\n')
    config = Config.load(cfg_file)
    assert config.is_enabled("terminal") == "alacritty"


def test_empty_config() -> None:
    config = Config.empty()
    assert config.system.hostname == ""
    assert config.modules == {}
    assert config.dotfiles.branch == "main"
