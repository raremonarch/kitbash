from __future__ import annotations

from pathlib import Path

from kitbash.state import ModuleResult, State


def test_record_and_retrieve(tmp_path: Path) -> None:
    state = State(path=tmp_path / "state.json")
    result = ModuleResult("docker", "success", "Installed", action="install")
    state.record(result)

    record = state.get("docker")
    assert record is not None
    assert record["status"] == "success"
    assert record["action"] == "install"


def test_save_and_reload(tmp_path: Path) -> None:
    path = tmp_path / "state.json"
    state = State(path=path)
    state.record(ModuleResult("vscode", "skipped", "Already installed"))
    state.save()

    state2 = State(path=path)
    record = state2.get("vscode")
    assert record is not None
    assert record["status"] == "skipped"


def test_get_missing_module(tmp_path: Path) -> None:
    state = State(path=tmp_path / "state.json")
    assert state.get("nonexistent") is None


def test_all_modules(tmp_path: Path) -> None:
    state = State(path=tmp_path / "state.json")
    state.record(ModuleResult("a", "success", ""))
    state.record(ModuleResult("b", "failed", "err"))
    modules = state.all_modules()
    assert set(modules.keys()) == {"a", "b"}


def test_corrupted_state_file(tmp_path: Path) -> None:
    path = tmp_path / "state.json"
    path.write_text("not valid json{{{")
    # Should not raise — falls back to empty state
    state = State(path=path)
    assert state.all_modules() == {}
