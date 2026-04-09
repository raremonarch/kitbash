from __future__ import annotations

from kitbash.config import Config
from kitbash.modules.system.pipewire import PipeWire
from tests.conftest import MockPkg, MockShell

_ALL_PKGS = ("pipewire", "pipewire-alsa", "pipewire-pulse", "wireplumber", "alsa-utils")
_SERVICES = ("pipewire", "pipewire-pulse", "wireplumber")


def test_install(mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config) -> None:
    m = PipeWire(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "success"
    assert mock_pkg.installed >= set(_ALL_PKGS)
    for svc in _SERVICES:
        assert any(
            "--user" in cmd and "enable" in cmd and svc in cmd
            for cmd in mock_shell.commands
        )


def test_install_uses_user_services_not_sudo(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    m = PipeWire(mock_pkg, mock_config, mock_shell)
    m.run_install()
    enable_cmds = [cmd for cmd in mock_shell.commands if "enable" in cmd]
    for cmd in enable_cmds:
        assert "--user" in cmd
        assert "sudo" not in cmd


def test_install_idempotent(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    mock_pkg.mark_installed(*_ALL_PKGS)
    m = PipeWire(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "skipped"
    assert mock_pkg.install_calls == []
    assert mock_shell.commands == []


def test_uninstall(mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config) -> None:
    mock_pkg.mark_installed(*_ALL_PKGS)
    m = PipeWire(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "success"
    assert not mock_pkg.installed
    for svc in _SERVICES:
        assert any(
            "--user" in cmd and "disable" in cmd and svc in cmd
            for cmd in mock_shell.commands
        )


def test_uninstall_disables_before_removing_packages(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    mock_pkg.mark_installed(*_ALL_PKGS)
    m = PipeWire(mock_pkg, mock_config, mock_shell)
    m.run_uninstall()
    first_disable = next(i for i, cmd in enumerate(mock_shell.commands) if "disable" in cmd)
    assert first_disable == 0
    assert mock_pkg.remove_calls, "packages were never removed"


def test_uninstall_not_installed(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    m = PipeWire(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "skipped"
    assert mock_pkg.remove_calls == []
