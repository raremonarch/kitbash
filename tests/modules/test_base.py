from __future__ import annotations

from pathlib import Path

import pytest

from kitbash.config import Config
from kitbash.modules.base import (
    BashrcDMixin,
    BinaryInstallMixin,
    Module,
    PackageInstallMixin,
    RepoMixin,
    SystemdServiceMixin,
)
from tests.conftest import MockPkg, MockShell


# ---------------------------------------------------------------------------
# Minimal concrete Module for testing Module ABC
# ---------------------------------------------------------------------------

class SimpleModule(PackageInstallMixin, Module):
    name = "simple"
    tier = 1
    description = "A simple test module"
    packages = ["pkg-a", "pkg-b"]


# ---------------------------------------------------------------------------
# PackageInstallMixin
# ---------------------------------------------------------------------------

def test_package_install_not_installed(mock_pkg, mock_shell, mock_config) -> None:
    m = SimpleModule(mock_pkg, mock_config, mock_shell)
    assert not m.is_installed()


def test_package_install_run_install(mock_pkg, mock_shell, mock_config) -> None:
    m = SimpleModule(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "success"
    assert mock_pkg.installed == {"pkg-a", "pkg-b"}


def test_package_install_idempotent(mock_pkg, mock_shell, mock_config) -> None:
    mock_pkg.mark_installed("pkg-a", "pkg-b")
    m = SimpleModule(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "skipped"
    assert mock_pkg.install_calls == []


def test_package_uninstall(mock_pkg, mock_shell, mock_config) -> None:
    mock_pkg.mark_installed("pkg-a", "pkg-b")
    m = SimpleModule(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "success"
    assert not mock_pkg.installed


def test_package_uninstall_not_installed(mock_pkg, mock_shell, mock_config) -> None:
    m = SimpleModule(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "skipped"
    assert mock_pkg.remove_calls == []


# ---------------------------------------------------------------------------
# Module failure paths
# ---------------------------------------------------------------------------

class BrokenInstallModule(PackageInstallMixin, Module):
    name = "_broken_install"
    tier = 1
    packages = ["broken-pkg"]

    def install(self) -> None:
        raise RuntimeError("install exploded")


class BrokenUninstallModule(PackageInstallMixin, Module):
    name = "_broken_uninstall"
    tier = 1
    packages = ["broken-pkg"]

    def uninstall(self) -> None:
        raise RuntimeError("uninstall exploded")


def test_run_install_failure_returns_failed(mock_pkg, mock_shell, mock_config) -> None:
    m = BrokenInstallModule(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "failed"
    assert "install exploded" in result.message
    assert result.action == "install"


def test_run_uninstall_failure_returns_failed(mock_pkg, mock_shell, mock_config) -> None:
    mock_pkg.mark_installed("broken-pkg")
    m = BrokenUninstallModule(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "failed"
    assert "uninstall exploded" in result.message
    assert result.action == "uninstall"


# ---------------------------------------------------------------------------
# SystemdServiceMixin
# ---------------------------------------------------------------------------

class ServiceModule(SystemdServiceMixin, PackageInstallMixin, Module):
    name = "servicemod"
    tier = 1
    packages = ["my-daemon"]
    service = "my-daemon"


def test_systemd_install_enables_service(mock_pkg, mock_shell, mock_config) -> None:
    m = ServiceModule(mock_pkg, mock_config, mock_shell)
    m.run_install()
    assert any("enable" in cmd and "my-daemon" in cmd for cmd in mock_shell.commands)


def test_systemd_uninstall_disables_service(mock_pkg, mock_shell, mock_config) -> None:
    mock_pkg.mark_installed("my-daemon")
    m = ServiceModule(mock_pkg, mock_config, mock_shell)
    m.run_uninstall()
    assert any("disable" in cmd and "my-daemon" in cmd for cmd in mock_shell.commands)


# ---------------------------------------------------------------------------
# RepoMixin
# ---------------------------------------------------------------------------

class RepoModule(RepoMixin, PackageInstallMixin, Module):
    name = "repomod"
    tier = 1
    packages = ["repomod-app"]

    def add_repo(self) -> None:
        self.pkg.add_repo("repomod-stable", url="https://example.com")

    def remove_repo(self) -> None:
        self.pkg.remove_repo("repomod-stable")


def test_repo_install_adds_repo(mock_pkg, mock_shell, mock_config) -> None:
    m = RepoModule(mock_pkg, mock_config, mock_shell)
    m.run_install()
    assert mock_pkg.repo_exists("repomod-stable")
    assert "repomod-app" in mock_pkg.installed


def test_repo_uninstall_removes_repo(mock_pkg, mock_shell, mock_config) -> None:
    mock_pkg.mark_installed("repomod-app")
    mock_pkg.mark_repo("repomod-stable")
    m = RepoModule(mock_pkg, mock_config, mock_shell)
    m.run_uninstall()
    assert not mock_pkg.repo_exists("repomod-stable")
    assert "repomod-app" not in mock_pkg.installed


# ---------------------------------------------------------------------------
# BashrcDMixin
# ---------------------------------------------------------------------------

class BashrcModule(BashrcDMixin, Module):
    name = "bashrcmod"
    tier = 1
    bashrc_d_filename = "bashrcmod.sh"
    bashrc_d_content = 'export PATH="$HOME/.local/bin:$PATH"\n'

    # BashrcDMixin provides is_installed/install/uninstall
    # but Module ABC requires them — satisfy the abstract check
    def install(self) -> None:
        BashrcDMixin.install(self)

    def uninstall(self) -> None:
        BashrcDMixin.uninstall(self)


def test_bashrc_d_install(mock_pkg, mock_shell, mock_config, tmp_path, monkeypatch) -> None:
    monkeypatch.setattr("kitbash.modules.base.BASHRC_D", tmp_path / ".bashrc.d")
    m = BashrcModule(mock_pkg, mock_config, mock_shell)
    assert not m.is_installed()
    result = m.run_install()
    assert result.status == "success"
    written = (tmp_path / ".bashrc.d" / "bashrcmod.sh").read_text()
    assert "PATH" in written


def test_bashrc_d_install_idempotent(mock_pkg, mock_shell, mock_config, tmp_path, monkeypatch) -> None:
    bashrc_d = tmp_path / ".bashrc.d"
    monkeypatch.setattr("kitbash.modules.base.BASHRC_D", bashrc_d)
    bashrc_d.mkdir()
    (bashrc_d / "bashrcmod.sh").write_text("existing")
    m = BashrcModule(mock_pkg, mock_config, mock_shell)
    result = m.run_install()
    assert result.status == "skipped"


def test_bashrc_d_uninstall(mock_pkg, mock_shell, mock_config, tmp_path, monkeypatch) -> None:
    bashrc_d = tmp_path / ".bashrc.d"
    monkeypatch.setattr("kitbash.modules.base.BASHRC_D", bashrc_d)
    bashrc_d.mkdir()
    snippet = bashrc_d / "bashrcmod.sh"
    snippet.write_text("content")
    m = BashrcModule(mock_pkg, mock_config, mock_shell)
    result = m.run_uninstall()
    assert result.status == "success"
    assert not snippet.exists()


# ---------------------------------------------------------------------------
# BinaryInstallMixin
# ---------------------------------------------------------------------------

class BinaryModule(BinaryInstallMixin, Module):
    name = "binarymod"
    tier = 1
    download_url = "https://example.com/tool-{version}.tar.gz"
    version = "1.0.0"

    @property
    def install_path(self) -> Path:
        return self._install_path

    def install(self) -> None:
        BinaryInstallMixin.install(self)

    def uninstall(self) -> None:
        BinaryInstallMixin.uninstall(self)


def test_binary_is_installed_false(mock_pkg, mock_shell, mock_config, tmp_path) -> None:
    m = BinaryModule(mock_pkg, mock_config, mock_shell)
    m._install_path = tmp_path / "tool"
    assert not m.is_installed()


def test_binary_is_installed_true(mock_pkg, mock_shell, mock_config, tmp_path) -> None:
    binary = tmp_path / "tool"
    binary.touch()
    m = BinaryModule(mock_pkg, mock_config, mock_shell)
    m._install_path = binary
    assert m.is_installed()


def test_binary_uninstall(mock_pkg, mock_shell, mock_config, tmp_path) -> None:
    binary = tmp_path / "tool"
    binary.touch()
    m = BinaryModule(mock_pkg, mock_config, mock_shell)
    m._install_path = binary
    m.run_uninstall()
    assert any("rm" in cmd and str(binary) in cmd for cmd in mock_shell.commands)
