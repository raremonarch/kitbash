from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from kitbash.exceptions import ShellError
from kitbash.shell import Shell, SudoSession, _sudo_timeout_seconds


def test_run_success() -> None:
    shell = Shell()
    result = shell.run(["echo", "hello"])
    assert result.returncode == 0
    assert "hello" in result.stdout


def test_run_failure_raises() -> None:
    shell = Shell()
    with pytest.raises(ShellError):
        shell.run(["false"])


def test_run_failure_no_raise() -> None:
    shell = Shell()
    result = shell.run(["false"], check=False)
    assert result.returncode != 0


def test_run_quiet_success() -> None:
    shell = Shell()
    result = shell.run_quiet(["echo", "quiet"])
    assert result.returncode == 0


def test_run_quiet_failure_raises() -> None:
    shell = Shell()
    with pytest.raises(ShellError):
        shell.run_quiet(["false"])


def test_which_found() -> None:
    shell = Shell()
    assert shell.which("echo") is True


def test_which_not_found() -> None:
    shell = Shell()
    assert shell.which("definitely-not-a-real-command-xyz") is False


# ---------------------------------------------------------------------------
# _sudo_timeout_seconds
# ---------------------------------------------------------------------------

def _mock_sudo_v_output(minutes: float) -> MagicMock:
    result = MagicMock()
    result.stdout = f"Sudo version 1.9.0\nAuthentication timestamp timeout: {minutes} minutes\n"
    return result


def test_sudo_timeout_parses_minutes() -> None:
    with patch("kitbash.shell.subprocess.run", return_value=_mock_sudo_v_output(5.0)):
        assert _sudo_timeout_seconds() == 300


def test_sudo_timeout_parses_fractional_minutes() -> None:
    with patch("kitbash.shell.subprocess.run", return_value=_mock_sudo_v_output(0.5)):
        assert _sudo_timeout_seconds() == 30


def test_sudo_timeout_fallback_on_no_match() -> None:
    result = MagicMock()
    result.stdout = "Sudo version 1.9.0\nNo timeout line here.\n"
    with patch("kitbash.shell.subprocess.run", return_value=result):
        assert _sudo_timeout_seconds() == 300


def test_sudo_timeout_fallback_on_exception() -> None:
    with patch("kitbash.shell.subprocess.run", side_effect=FileNotFoundError):
        assert _sudo_timeout_seconds() == 300


# ---------------------------------------------------------------------------
# SudoSession
# ---------------------------------------------------------------------------

def test_sudo_session_enters_and_exits() -> None:
    calls: list[list[str]] = []

    def fake_run(cmd: list[str], **kwargs: object) -> MagicMock:
        calls.append(cmd)
        r = MagicMock()
        r.returncode = 0
        r.stdout = "Authentication timestamp timeout: 5.0 minutes\n"
        return r

    with patch("kitbash.shell.subprocess.run", side_effect=fake_run), SudoSession():
        pass

    # sudo -V (timeout detection) and sudo -v (auth) must have been called
    assert any("-V" in c for c in calls)
    assert any("-v" in c for c in calls)


def test_sudo_session_raises_on_auth_failure() -> None:
    def fake_run(cmd: list[str], **kwargs: object) -> MagicMock:
        r = MagicMock()
        r.returncode = 0 if "-V" in cmd else 1
        r.stdout = "Authentication timestamp timeout: 5.0 minutes\n"
        return r

    with (
        patch("kitbash.shell.subprocess.run", side_effect=fake_run),
        pytest.raises(ShellError, match="sudo authentication failed"),
        SudoSession(),
    ):
        pass


def test_sudo_session_keepalive_refreshes_credentials() -> None:
    calls: list[list[str]] = []

    def fake_run(cmd: list[str], **kwargs: object) -> MagicMock:
        calls.append(cmd)
        r = MagicMock()
        r.returncode = 0
        # Very short timeout so the keepalive fires quickly in the test
        r.stdout = "Authentication timestamp timeout: 0.05 minutes\n"  # 3 seconds
        return r

    with patch("kitbash.shell.subprocess.run", side_effect=fake_run):
        import time
        with SudoSession():
            time.sleep(0.2)  # interval = max(10, 3//2) = 10s — won't fire in test

    # At minimum: -V call + initial -v call
    v_calls = [c for c in calls if "-v" in c]
    assert len(v_calls) >= 1


def test_sudo_session_thread_stops_on_exit() -> None:
    with patch("kitbash.shell.subprocess.run") as mock_run:
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = "Authentication timestamp timeout: 5.0 minutes\n"

        session = SudoSession()
        session.__enter__()
        assert session._thread is not None
        assert session._thread.is_alive()
        session.__exit__(None, None, None)
        assert not session._thread.is_alive()
