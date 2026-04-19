from __future__ import annotations

from kitbash.config import Config
from kitbash.modules.apps.gimp import Gimp
from tests.conftest import MockPkg, MockShell


def test_install(mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config) -> None:
    m = Gimp(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "success"
    assert "gimp" in mock_pkg.installed


def test_install_idempotent(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    mock_pkg.mark_installed("gimp")
    m = Gimp(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "skipped"
    assert mock_pkg.install_calls == []


def test_uninstall(mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config) -> None:
    mock_pkg.mark_installed("gimp")
    m = Gimp(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "success"
    assert "gimp" not in mock_pkg.installed


def test_uninstall_not_installed(
    mock_pkg: MockPkg, mock_shell: MockShell, mock_config: Config
) -> None:
    m = Gimp(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "skipped"
    assert mock_pkg.remove_calls == []
