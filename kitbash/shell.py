from __future__ import annotations

import logging
import subprocess
import threading
from types import TracebackType
from typing import TYPE_CHECKING

from rich.console import Console
from rich.status import Status

from kitbash.exceptions import ShellError

if TYPE_CHECKING:
    pass

logger = logging.getLogger(__name__)
console = Console()


def _sudo_timeout_seconds() -> int:
    """
    Read the sudo credential cache timeout from `sudo -V` output.
    Returns the timeout in seconds, falling back to 300 (5 min) if unreadable.

    Example sudo -V line:
        Authentication timestamp timeout: 5.0 minutes
    """
    try:
        result = subprocess.run(["sudo", "-V"], capture_output=True, text=True)
        for line in result.stdout.splitlines():
            if "timestamp timeout" in line.lower():
                # e.g. "Authentication timestamp timeout: 5.0 minutes"
                value_str = line.split(":")[-1].split()[0]
                minutes = float(value_str)
                return max(1, int(minutes * 60))
    except Exception:
        pass
    return 300  # 5-minute fallback


class SudoSession:
    """
    Context manager that prompts for sudo upfront and keeps credentials
    alive in a background thread for the duration of the block.

    Automatically detects the system's sudo timeout and refreshes at
    half that interval, so installs of any length stay authenticated.

    Usage:
        with SudoSession():
            runner.run_all()
    """

    def __enter__(self) -> SudoSession:
        timeout = _sudo_timeout_seconds()
        self._interval = max(10, timeout // 2)
        logger.debug(
            "sudo timeout: %ds — keepalive interval: %ds",
            timeout,
            self._interval,
        )
        result = subprocess.run(["sudo", "-v"], check=False)
        if result.returncode != 0:
            raise ShellError("sudo authentication failed")
        self._stop = threading.Event()
        self._thread = threading.Thread(
            target=self._keepalive, daemon=True
        )
        self._thread.start()
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: TracebackType | None,
    ) -> None:
        self._stop.set()
        self._thread.join()
        logger.debug("sudo keepalive stopped")

    def _keepalive(self) -> None:
        while not self._stop.wait(self._interval):
            logger.debug("Refreshing sudo credentials")
            subprocess.run(["sudo", "-v"], capture_output=True, check=False)


class Shell:
    """
    Subprocess wrapper that shows Rich progress on the console and
    sends full command output to the log file.
    """

    def run(
        self,
        cmd: list[str],
        *,
        description: str = "",
        check: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        """Run a command, showing a spinner on the console."""
        label = description or " ".join(cmd[:2])
        logger.debug("Running: %s", " ".join(cmd))

        with Status(f"  {label}", console=console):
            result = subprocess.run(
                cmd,
                text=True,
                capture_output=True,
            )

        logger.debug("stdout: %s", result.stdout)
        if result.stderr:
            logger.debug("stderr: %s", result.stderr)

        if check and result.returncode != 0:
            logger.error("Command failed (%d): %s", result.returncode, " ".join(cmd))
            logger.error("stderr: %s", result.stderr)
            raise ShellError(
                f"Command failed (exit {result.returncode}): {' '.join(cmd)}\n{result.stderr}"
            )

        return result

    def run_quiet(
        self,
        cmd: list[str],
        *,
        check: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        """Run a command with no console output — log file only."""
        logger.debug("Running (quiet): %s", " ".join(cmd))

        result = subprocess.run(
            cmd,
            text=True,
            capture_output=True,
        )

        logger.debug("stdout: %s", result.stdout)
        if result.stderr:
            logger.debug("stderr: %s", result.stderr)

        if check and result.returncode != 0:
            raise ShellError(
                f"Command failed (exit {result.returncode}): {' '.join(cmd)}\n{result.stderr}"
            )

        return result

    def which(self, name: str) -> bool:
        """Return True if `name` is on PATH."""
        result = subprocess.run(
            ["which", name],
            capture_output=True,
        )
        return result.returncode == 0
