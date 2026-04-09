from __future__ import annotations

import pytest

from kitbash.config import Config
from kitbash.modules.system.shell import Zsh
from tests.conftest import MockPkg, MockShell


class _PwEntry:
    def __init__(self, shell: str) -> None:
        self.pw_shell = shell


def test_not_installed_when_package_missing(mock_pkg: MockPkg, mock_shell: MockShell) -> None:
    m = Zsh(mock_pkg, Config.empty(), mock_shell)
    assert not m.is_installed()


def test_not_installed_when_shell_not_zsh(
    mock_pkg: MockPkg, mock_shell: MockShell, monkeypatch: pytest.MonkeyPatch
) -> None:
    mock_pkg.mark_installed("zsh")
    monkeypatch.setattr(
        "kitbash.modules.system.shell.pwd.getpwnam", lambda u: _PwEntry("/bin/bash")
    )
    m = Zsh(mock_pkg, Config.empty(), mock_shell)
    assert not m.is_installed()


def test_installed_when_package_present_and_default_shell(
    mock_pkg: MockPkg, mock_shell: MockShell, monkeypatch: pytest.MonkeyPatch
) -> None:
    mock_pkg.mark_installed("zsh")
    monkeypatch.setattr(
        "kitbash.modules.system.shell.pwd.getpwnam", lambda u: _PwEntry("/usr/bin/zsh")
    )
    m = Zsh(mock_pkg, Config.empty(), mock_shell)
    assert m.is_installed()


def test_install_installs_package_and_sets_shell(
    mock_pkg: MockPkg, mock_shell: MockShell, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        "kitbash.modules.system.shell.pwd.getpwnam", lambda u: _PwEntry("/bin/bash")
    )
    mock_shell.which_map["zsh"] = True
    m = Zsh(mock_pkg, Config.empty(), mock_shell)
    result = m.run_install()
    assert result.status == "success"
    assert "zsh" in mock_pkg.installed
    assert any("usermod" in cmd and "-s" in cmd for cmd in mock_shell.commands)


def test_install_idempotent(
    mock_pkg: MockPkg, mock_shell: MockShell, monkeypatch: pytest.MonkeyPatch
) -> None:
    mock_pkg.mark_installed("zsh")
    monkeypatch.setattr(
        "kitbash.modules.system.shell.pwd.getpwnam", lambda u: _PwEntry("/usr/bin/zsh")
    )
    m = Zsh(mock_pkg, Config.empty(), mock_shell)
    result = m.run_install()
    assert result.status == "skipped"
    assert mock_shell.commands == []


def test_uninstall_resets_shell_then_removes_package(
    mock_pkg: MockPkg, mock_shell: MockShell, monkeypatch: pytest.MonkeyPatch
) -> None:
    mock_pkg.mark_installed("zsh")
    monkeypatch.setattr(
        "kitbash.modules.system.shell.pwd.getpwnam", lambda u: _PwEntry("/usr/bin/zsh")
    )
    m = Zsh(mock_pkg, Config.empty(), mock_shell)
    result = m.run_uninstall()
    assert result.status == "success"
    assert "zsh" not in mock_pkg.installed
    usermod_idx = next(i for i, cmd in enumerate(mock_shell.commands) if "usermod" in cmd)
    assert "/bin/bash" in mock_shell.commands[usermod_idx]
    assert usermod_idx == 0


def test_uninstall_not_installed(mock_pkg: MockPkg, mock_shell: MockShell) -> None:
    m = Zsh(mock_pkg, Config.empty(), mock_shell)
    result = m.run_uninstall()
    assert result.status == "skipped"
    assert mock_pkg.remove_calls == []
