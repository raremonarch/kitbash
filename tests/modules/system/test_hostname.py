from __future__ import annotations

import pytest

from kitbash.config import Config
from kitbash.modules.system.hostname import Hostname
from tests.conftest import MockPkg, MockShell


def _config(hostname: str) -> Config:
    cfg = Config.empty()
    cfg.system.hostname = hostname
    return cfg


def test_not_installed_when_hostname_differs(
    mock_pkg: MockPkg, mock_shell: MockShell, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr("kitbash.modules.system.hostname.socket.gethostname", lambda: "other")
    m = Hostname(mock_pkg, _config("myhostname"), mock_shell)
    assert not m.is_installed()


def test_installed_when_hostname_matches(
    mock_pkg: MockPkg, mock_shell: MockShell, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        "kitbash.modules.system.hostname.socket.gethostname", lambda: "myhostname"
    )
    m = Hostname(mock_pkg, _config("myhostname"), mock_shell)
    assert m.is_installed()


def test_installed_when_no_hostname_configured(
    mock_pkg: MockPkg, mock_shell: MockShell, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr("kitbash.modules.system.hostname.socket.gethostname", lambda: "anything")
    m = Hostname(mock_pkg, _config(""), mock_shell)
    assert m.is_installed()


def test_install_calls_hostnamectl(
    mock_pkg: MockPkg, mock_shell: MockShell, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr("kitbash.modules.system.hostname.socket.gethostname", lambda: "other")
    m = Hostname(mock_pkg, _config("myhostname"), mock_shell)
    result = m.run_install()
    assert result.status == "success"
    assert any("hostnamectl" in cmd and "myhostname" in cmd for cmd in mock_shell.commands)


def test_install_idempotent(
    mock_pkg: MockPkg, mock_shell: MockShell, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        "kitbash.modules.system.hostname.socket.gethostname", lambda: "myhostname"
    )
    m = Hostname(mock_pkg, _config("myhostname"), mock_shell)
    result = m.run_install()
    assert result.status == "skipped"
    assert mock_shell.commands == []


def test_install_skips_when_no_hostname(
    mock_pkg: MockPkg, mock_shell: MockShell, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr("kitbash.modules.system.hostname.socket.gethostname", lambda: "current")
    m = Hostname(mock_pkg, _config(""), mock_shell)
    result = m.run_install()
    assert result.status == "skipped"
    assert mock_shell.commands == []


def test_uninstall_is_noop(
    mock_pkg: MockPkg, mock_shell: MockShell, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        "kitbash.modules.system.hostname.socket.gethostname", lambda: "myhostname"
    )
    m = Hostname(mock_pkg, _config("myhostname"), mock_shell)
    result = m.run_uninstall()
    assert result.status == "success"
    assert mock_shell.commands == []
