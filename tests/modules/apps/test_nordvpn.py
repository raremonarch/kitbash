from __future__ import annotations

from kitbash.config import Config
from kitbash.modules.apps.nordvpn import NordVPN
from tests.conftest import MockPkg, MockShell


def test_install(mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config) -> None:
    m = NordVPN(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "success"
    assert any("install.sh" in " ".join(cmd) for cmd in mock_shell.commands)
    assert any("usermod" in cmd and "nordvpn" in cmd for cmd in mock_shell.commands)
    assert any("nordvpnd" in cmd and "enable" in cmd for cmd in mock_shell.commands)


def test_install_idempotent(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    mock_shell.which_map["nordvpn"] = True
    m = NordVPN(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "skipped"
    assert mock_shell.commands == []


def test_install_enables_system_service(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    m = NordVPN(mock_pkg, mock_config, mock_shell)
    m.run_install()
    enable_cmd = next(
        cmd for cmd in mock_shell.commands
        if "nordvpnd" in cmd and "enable" in cmd
    )
    assert "sudo" in enable_cmd
    assert "--user" not in enable_cmd


def test_uninstall(mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config) -> None:
    mock_shell.which_map["nordvpn"] = True
    m = NordVPN(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "success"
    assert any("nordvpnd" in cmd and "disable" in cmd for cmd in mock_shell.commands)
    assert ("nordvpn",) in mock_pkg.remove_calls


def test_uninstall_disables_before_removing_package(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    mock_shell.which_map["nordvpn"] = True
    m = NordVPN(mock_pkg, mock_config, mock_shell)
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
    m = NordVPN(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "skipped"
    assert mock_pkg.remove_calls == []
