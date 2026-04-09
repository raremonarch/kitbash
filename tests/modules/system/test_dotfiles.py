from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from kitbash.config import Config
from kitbash.modules.system.dotfiles import Dotfiles
from tests.conftest import MockPkg, MockShell


def _config(repo: str = "https://github.com/user/dotfiles.git", branch: str = "main") -> Config:
    cfg = Config.empty()
    cfg.dotfiles.repo = repo
    cfg.dotfiles.branch = branch
    return cfg


class _DotfilesMockShell(MockShell):
    """MockShell that returns a configurable stdout for `git remote get-url`."""

    def __init__(self, remote_url: str = "") -> None:
        super().__init__()
        self.remote_url = remote_url

    def run_quiet(
        self,
        cmd: list[str],
        *,
        check: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        if "remote" in cmd and "get-url" in cmd:
            if self.remote_url:
                return subprocess.CompletedProcess(cmd, 0, stdout=self.remote_url + "\n", stderr="")
            return subprocess.CompletedProcess(cmd, 1, stdout="", stderr="no remote")
        return super().run_quiet(cmd, check=check)


def test_not_installed_when_no_git_dir(
    mock_pkg: MockPkg, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    home = tmp_path / "home"
    home.mkdir()
    shell = _DotfilesMockShell()
    m = Dotfiles(mock_pkg, _config(), shell)
    monkeypatch.setattr(m, "_home", lambda: home)
    assert not m.is_installed()


def test_not_installed_when_remote_mismatch(
    mock_pkg: MockPkg, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    home = tmp_path / "home"
    home.mkdir()
    (home / ".git").mkdir()
    shell = _DotfilesMockShell(remote_url="https://github.com/other/dotfiles.git")
    m = Dotfiles(mock_pkg, _config("https://github.com/user/dotfiles.git"), shell)
    monkeypatch.setattr(m, "_home", lambda: home)
    assert not m.is_installed()


def test_installed_when_git_dir_and_remote_match(
    mock_pkg: MockPkg, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    home = tmp_path / "home"
    home.mkdir()
    (home / ".git").mkdir()
    shell = _DotfilesMockShell(remote_url="https://github.com/user/dotfiles.git")
    m = Dotfiles(mock_pkg, _config("https://github.com/user/dotfiles.git"), shell)
    monkeypatch.setattr(m, "_home", lambda: home)
    assert m.is_installed()


def test_install_inits_and_syncs(
    mock_pkg: MockPkg, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    home = tmp_path / "home"
    home.mkdir()
    shell = _DotfilesMockShell()  # no remote URL → get-url fails → add remote
    m = Dotfiles(mock_pkg, _config(), shell)
    monkeypatch.setattr(m, "_home", lambda: home)
    result = m.run_install()
    assert result.status == "success"
    assert any("init" in cmd for cmd in shell.commands)
    assert any("remote" in cmd and "add" in cmd and "origin" in cmd for cmd in shell.commands)
    assert any("fetch" in cmd and "origin" in cmd for cmd in shell.commands)
    assert any("reset" in cmd and "--hard" in cmd for cmd in shell.commands)


def test_install_skips_init_if_git_exists(
    mock_pkg: MockPkg, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    home = tmp_path / "home"
    home.mkdir()
    (home / ".git").mkdir()
    shell = _DotfilesMockShell(remote_url="https://github.com/user/dotfiles.git")
    m = Dotfiles(mock_pkg, _config(), shell)
    monkeypatch.setattr(m, "_home", lambda: home)
    result = m.run_install()
    assert result.status == "skipped"
    assert not any("init" in cmd for cmd in shell.commands)


def test_install_updates_remote_if_url_changed(
    mock_pkg: MockPkg, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    home = tmp_path / "home"
    home.mkdir()
    (home / ".git").mkdir()
    shell = _DotfilesMockShell(remote_url="https://github.com/old/dotfiles.git")
    m = Dotfiles(mock_pkg, _config("https://github.com/user/dotfiles.git"), shell)
    monkeypatch.setattr(m, "_home", lambda: home)
    result = m.run_install()
    assert result.status == "success"
    assert any("remote" in cmd and "set-url" in cmd for cmd in shell.commands)


def test_install_skips_when_no_repo(
    mock_pkg: MockPkg, tmp_path: Path, monkeypatch: pytest.MonkeyPatch, mock_shell: MockShell
) -> None:
    home = tmp_path / "home"
    home.mkdir()
    m = Dotfiles(mock_pkg, _config(repo=""), mock_shell)
    monkeypatch.setattr(m, "_home", lambda: home)
    result = m.run_install()
    assert result.status == "success"
    assert mock_shell.commands == []


def test_repo_shorthand_expanded(mock_pkg: MockPkg, mock_shell: MockShell) -> None:
    m = Dotfiles(mock_pkg, _config(repo="user/dotfiles"), mock_shell)
    assert m._repo() == "https://github.com/user/dotfiles.git"


def test_uninstall_is_noop(
    mock_pkg: MockPkg, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    home = tmp_path / "home"
    home.mkdir()
    (home / ".git").mkdir()
    shell = _DotfilesMockShell(remote_url="https://github.com/user/dotfiles.git")
    m = Dotfiles(mock_pkg, _config(), shell)
    monkeypatch.setattr(m, "_home", lambda: home)
    result = m.run_uninstall()
    assert result.status == "success"
    assert shell.commands == []
