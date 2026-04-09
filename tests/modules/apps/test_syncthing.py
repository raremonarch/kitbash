from __future__ import annotations

from kitbash.config import Config
from kitbash.modules.apps.syncthing import Syncthing
from tests.conftest import MockPkg, MockShell


def test_install(mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config) -> None:
    m = Syncthing(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "success"
    assert "syncthing" in mock_pkg.installed
    assert any(
        "--user" in cmd and "enable" in cmd and "syncthing" in cmd
        for cmd in mock_shell.commands
    )


def test_install_uses_user_service_not_sudo(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    m = Syncthing(mock_pkg, mock_config, mock_shell)
    m.run_install()
    enable_cmd = next(
        cmd for cmd in mock_shell.commands
        if "enable" in cmd and "syncthing" in cmd
    )
    assert "--user" in enable_cmd
    assert "sudo" not in enable_cmd


def test_install_idempotent(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    mock_pkg.mark_installed("syncthing")
    m = Syncthing(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "skipped"
    assert mock_pkg.install_calls == []
    assert mock_shell.commands == []


def test_uninstall(mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config) -> None:
    mock_pkg.mark_installed("syncthing")
    m = Syncthing(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "success"
    assert "syncthing" not in mock_pkg.installed
    assert any(
        "--user" in cmd and "disable" in cmd and "syncthing" in cmd
        for cmd in mock_shell.commands
    )


def test_uninstall_disables_before_removing_package(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    mock_pkg.mark_installed("syncthing")
    m = Syncthing(mock_pkg, mock_config, mock_shell)
    m.run_uninstall()
    disable_idx = next(
        i for i, cmd in enumerate(mock_shell.commands)
        if "disable" in cmd
    )
    assert mock_pkg.remove_calls, "package was never removed"
    assert disable_idx == 0


def test_uninstall_not_installed(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    m = Syncthing(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "skipped"
    assert mock_pkg.remove_calls == []
