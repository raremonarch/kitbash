from __future__ import annotations

from pathlib import Path

import pytest

from kitbash.config import Config
from kitbash.modules.base import Module, PackageInstallMixin
from kitbash.runner import Runner
from kitbash.state import State
from tests.conftest import MockPkg, MockShell

# ---------------------------------------------------------------------------
# Stub modules registered only for these tests
# ---------------------------------------------------------------------------

class StubAlpha(PackageInstallMixin, Module):
    name = "_test_alpha"
    tier = 0
    packages = ["alpha-pkg"]
    description = "Alpha stub"


class StubBeta(PackageInstallMixin, Module):
    name = "_test_beta"
    tier = 1
    packages = ["beta-pkg"]
    description = "Beta stub"


class StubGamma(PackageInstallMixin, Module):
    name = "_test_gamma"
    tier = 1
    packages = ["gamma-pkg"]
    description = "Gamma stub"


def _make_runner(pkg: MockPkg, shell: MockShell, enabled: list[str], tmp_path: Path) -> Runner:
    modules_dict: dict[str, bool | str] = {name: True for name in enabled}
    config = Config(modules=modules_dict)
    state = State(path=tmp_path / "state.json")
    return Runner(pkg=pkg, config=config, shell=shell, state=state)


def test_discover_finds_stub_modules(
    mock_pkg: MockPkg, mock_shell: MockShell, tmp_path: Path
) -> None:
    runner = _make_runner(mock_pkg, mock_shell, [], tmp_path)
    names = {cls.name for cls in runner.discover()}
    assert "_test_alpha" in names
    assert "_test_beta" in names


def test_enabled_modules_filtered(mock_pkg: MockPkg, mock_shell: MockShell, tmp_path: Path) -> None:
    runner = _make_runner(mock_pkg, mock_shell, ["_test_alpha"], tmp_path)
    enabled = runner.enabled_modules()
    names = [cls.name for cls in enabled]
    assert "_test_alpha" in names
    assert "_test_beta" not in names


def test_enabled_modules_sorted_by_tier(
    mock_pkg: MockPkg, mock_shell: MockShell, tmp_path: Path
) -> None:
    runner = _make_runner(mock_pkg, mock_shell, ["_test_beta", "_test_alpha"], tmp_path)
    enabled = runner.enabled_modules()
    names = [cls.name for cls in enabled]
    assert names.index("_test_alpha") < names.index("_test_beta")


def test_run_all_installs_enabled(mock_pkg: MockPkg, mock_shell: MockShell, tmp_path: Path) -> None:
    runner = _make_runner(mock_pkg, mock_shell, ["_test_alpha", "_test_beta"], tmp_path)
    results = runner.run_all()
    statuses = {r.name: r.status for r in results}
    assert statuses["_test_alpha"] == "success"
    assert statuses["_test_beta"] == "success"
    assert "alpha-pkg" in mock_pkg.installed
    assert "beta-pkg" in mock_pkg.installed


def test_run_all_skips_already_installed(
    mock_pkg: MockPkg, mock_shell: MockShell, tmp_path: Path
) -> None:
    mock_pkg.mark_installed("alpha-pkg")
    runner = _make_runner(mock_pkg, mock_shell, ["_test_alpha"], tmp_path)
    results = runner.run_all()
    assert results[0].status == "skipped"
    assert mock_pkg.install_calls == []


def test_run_one(mock_pkg: MockPkg, mock_shell: MockShell, tmp_path: Path) -> None:
    runner = _make_runner(mock_pkg, mock_shell, ["_test_alpha"], tmp_path)
    result = runner.run_one("_test_alpha")
    assert result.status == "success"


def test_run_one_unknown_raises(mock_pkg: MockPkg, mock_shell: MockShell, tmp_path: Path) -> None:
    runner = _make_runner(mock_pkg, mock_shell, [], tmp_path)
    with pytest.raises(ValueError, match="Unknown module"):
        runner.run_one("_test_does_not_exist")


def test_run_one_unknown_no_modules_message(
    mock_pkg: MockPkg, mock_shell: MockShell, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runner = _make_runner(mock_pkg, mock_shell, [], tmp_path)
    monkeypatch.setattr(runner, "discover", lambda: [])
    with pytest.raises(ValueError, match="No modules are implemented yet"):
        runner.run_one("anything")


def test_uninstall_all_reverse_order(
    mock_pkg: MockPkg, mock_shell: MockShell, tmp_path: Path
) -> None:
    mock_pkg.mark_installed("alpha-pkg", "beta-pkg")
    runner = _make_runner(mock_pkg, mock_shell, ["_test_alpha", "_test_beta"], tmp_path)
    results = runner.uninstall_all()
    # beta (tier=1) should be uninstalled before alpha (tier=0)
    names = [r.name for r in results]
    assert names.index("_test_beta") < names.index("_test_alpha")


def test_state_recorded_after_run(mock_pkg: MockPkg, mock_shell: MockShell, tmp_path: Path) -> None:
    runner = _make_runner(mock_pkg, mock_shell, ["_test_alpha"], tmp_path)
    runner.run_one("_test_alpha")
    state = State(path=tmp_path / "state.json")
    record = state.get("_test_alpha")
    assert record is not None
    assert record["status"] == "success"
