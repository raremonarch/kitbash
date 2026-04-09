from __future__ import annotations

from pathlib import Path

import pytest

from kitbash.config import Config
from kitbash.modules.system.sudo_timeout import DEFAULT_TIMEOUT_MINUTES, SudoTimeout
from tests.conftest import MockPkg, MockShell


def test_not_installed_when_file_absent(
    mock_pkg: MockPkg,
    mock_shell: MockShell,
    mock_config: Config,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(SudoTimeout, "_sudoers_path", lambda self: tmp_path / "user-timeout")
    m = SudoTimeout(mock_pkg, mock_config, mock_shell)
    assert not m.is_installed()


def test_installed_when_file_present(
    mock_pkg: MockPkg,
    mock_shell: MockShell,
    mock_config: Config,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    sudoers = tmp_path / "user-timeout"
    sudoers.write_text("Defaults:user timestamp_timeout=15\n")
    monkeypatch.setattr(SudoTimeout, "_sudoers_path", lambda self: sudoers)
    m = SudoTimeout(mock_pkg, mock_config, mock_shell)
    assert m.is_installed()


def test_install(
    mock_pkg: MockPkg,
    mock_shell: MockShell,
    mock_config: Config,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(SudoTimeout, "_sudoers_path", lambda self: tmp_path / "user-timeout")
    m = SudoTimeout(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "success"
    assert any("sudo" in cmd and "cp" in cmd for cmd in mock_shell.commands)
    assert any("chmod" in cmd and "440" in cmd for cmd in mock_shell.commands)
    assert any("visudo" in cmd for cmd in mock_shell.commands)


def test_install_idempotent(
    mock_pkg: MockPkg,
    mock_shell: MockShell,
    mock_config: Config,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    sudoers = tmp_path / "user-timeout"
    sudoers.write_text("Defaults:user timestamp_timeout=15\n")
    monkeypatch.setattr(SudoTimeout, "_sudoers_path", lambda self: sudoers)
    m = SudoTimeout(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "skipped"
    assert mock_shell.commands == []


def test_uninstall(
    mock_pkg: MockPkg,
    mock_shell: MockShell,
    mock_config: Config,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    sudoers = tmp_path / "user-timeout"
    sudoers.write_text("Defaults:user timestamp_timeout=15\n")
    monkeypatch.setattr(SudoTimeout, "_sudoers_path", lambda self: sudoers)
    m = SudoTimeout(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "success"
    assert any("rm" in cmd and str(sudoers) in cmd for cmd in mock_shell.commands)


def test_default_timeout(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    m = SudoTimeout(mock_pkg, mock_config, mock_shell)
    assert m._timeout_minutes() == DEFAULT_TIMEOUT_MINUTES


def test_custom_timeout_from_config(mock_pkg: MockPkg, mock_shell: MockShell) -> None:
    cfg = Config.empty()
    cfg.modules["sudo_timeout"] = "30"
    m = SudoTimeout(mock_pkg, cfg, mock_shell)
    assert m._timeout_minutes() == 30
