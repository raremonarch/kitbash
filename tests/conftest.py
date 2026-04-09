from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from kitbash.config import Config
from kitbash.pkg.base import PackageManager
from kitbash.shell import Shell
from kitbash.state import State

# ---------------------------------------------------------------------------
# MockShell
# ---------------------------------------------------------------------------

class MockShell(Shell):
    """Records all commands. Never calls subprocess."""

    def __init__(self) -> None:
        self.commands: list[list[str]] = []
        self.which_map: dict[str, bool] = {}

    def run(
        self,
        cmd: list[str],
        *,
        description: str = "",
        check: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        self.commands.append(cmd)
        return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

    def run_quiet(
        self,
        cmd: list[str],
        *,
        check: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        self.commands.append(cmd)
        return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

    def which(self, name: str) -> bool:
        return self.which_map.get(name, False)


# ---------------------------------------------------------------------------
# MockPkg
# ---------------------------------------------------------------------------

class MockPkg(PackageManager):
    """In-memory package state."""

    def __init__(self) -> None:
        self.installed: set[str] = set()
        self.repos: set[str] = set()
        self.install_calls: list[tuple[str, ...]] = []
        self.remove_calls: list[tuple[str, ...]] = []

    def install(self, *packages: str) -> None:
        self.install_calls.append(packages)
        self.installed.update(packages)

    def remove(self, *packages: str) -> None:
        self.remove_calls.append(packages)
        self.installed -= set(packages)

    def is_installed(self, package: str) -> bool:
        return package in self.installed

    def update(self) -> None:
        pass

    def add_repo(self, name: str, **kwargs: str) -> None:
        self.repos.add(name)

    def remove_repo(self, name: str) -> None:
        self.repos.discard(name)

    def repo_exists(self, name: str) -> bool:
        return name in self.repos

    def mark_installed(self, *packages: str) -> None:
        """Test helper: pre-populate installed packages."""
        self.installed.update(packages)

    def mark_repo(self, name: str) -> None:
        """Test helper: pre-populate a repo."""
        self.repos.add(name)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def mock_shell() -> MockShell:
    return MockShell()


@pytest.fixture
def mock_pkg() -> MockPkg:
    return MockPkg()


@pytest.fixture
def mock_config() -> Config:
    return Config.empty()


@pytest.fixture
def tmp_state(tmp_path: Path) -> State:
    return State(path=tmp_path / "state.json")
