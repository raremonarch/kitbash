from __future__ import annotations

import pytest

from kitbash.config import Config
from kitbash.modules.apps.nordvpn import NordVPN
from kitbash.pkg.pacman import PacmanPackageManager
from tests.conftest import MockPkg, MockShell


class MockPacmanPkg(PacmanPackageManager):
    """PacmanPackageManager that records calls without running subprocess."""

    def __init__(self) -> None:
        self.install_calls: list[tuple[str, ...]] = []
        self.install_aur_calls: list[tuple[str, ...]] = []
        self.remove_calls: list[tuple[str, ...]] = []
        self.installed: set[str] = set()

    def install(self, *packages: str) -> None:
        self.install_calls.append(packages)
        self.installed.update(packages)

    def install_aur(self, *packages: str) -> None:
        self.install_aur_calls.append(packages)
        self.installed.update(packages)

    def remove(self, *packages: str) -> None:
        self.remove_calls.append(packages)

    def is_installed(self, package: str) -> bool:
        return package in self.installed

    def update(self) -> None:
        pass


@pytest.fixture
def mock_pacman() -> MockPacmanPkg:
    return MockPacmanPkg()


# ---------------------------------------------------------------------------
# Non-Arch path (installer script)
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Arch/Pacman path (AUR)
# ---------------------------------------------------------------------------

def test_install_arch_uses_aur(
    mock_pacman: MockPacmanPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    m = NordVPN(mock_pacman, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "success"
    assert ("nordvpn-bin",) in mock_pacman.install_aur_calls
    assert mock_pacman.install_calls == []
    assert not any("install.sh" in " ".join(cmd) for cmd in mock_shell.commands)


def test_install_arch_still_enables_service_and_adds_group(
    mock_pacman: MockPacmanPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    m = NordVPN(mock_pacman, mock_config, mock_shell)
    m.run_install()
    assert any("usermod" in cmd and "nordvpn" in cmd for cmd in mock_shell.commands)
    assert any("nordvpnd" in cmd and "enable" in cmd for cmd in mock_shell.commands)


def test_uninstall_arch_removes_nordvpn_bin(
    mock_pacman: MockPacmanPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    mock_shell.which_map["nordvpn"] = True
    m = NordVPN(mock_pacman, mock_config, mock_shell)
    m.run_uninstall()
    assert ("nordvpn",) in mock_pacman.remove_calls
