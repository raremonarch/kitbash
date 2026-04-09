from __future__ import annotations

import logging
import os
import tempfile
from pathlib import Path

from kitbash.modules.base import Module

logger = logging.getLogger(__name__)

DEFAULT_TIMEOUT_MINUTES = 15


class SudoTimeout(Module):
    """
    Configure sudo password cache timeout via /etc/sudoers.d/<user>-timeout.

    The timeout (in minutes) can be set via config.modules:
        [modules]
        sudo_timeout = 15     # integer → use as timeout in minutes
        sudo_timeout = true   # boolean → use default (15 minutes)

    Permissions are set to 440 as required by sudoers.d.
    The configuration is validated with `sudo visudo -c` before being kept.
    """

    name = "sudo_timeout"
    tier = 1
    description = "Configure sudo password cache timeout via /etc/sudoers.d"

    def _sudoers_path(self) -> Path:
        user = os.environ.get("USER", "")
        return Path(f"/etc/sudoers.d/{user}-timeout")

    def _timeout_minutes(self) -> int:
        val = self.config.is_enabled(self.name)
        if isinstance(val, bool):
            return DEFAULT_TIMEOUT_MINUTES
        try:
            return int(val)
        except (TypeError, ValueError):
            return DEFAULT_TIMEOUT_MINUTES

    def is_installed(self) -> bool:
        return self._sudoers_path().exists()

    def install(self) -> None:
        user = os.environ.get("USER", "")
        minutes = self._timeout_minutes()
        content = f"Defaults:{user} timestamp_timeout={minutes}\n"
        path = self._sudoers_path()

        with tempfile.NamedTemporaryFile(mode="w", suffix=".sudoers", delete=False) as f:
            f.write(content)
            tmp = f.name

        try:
            self.shell.run(
                ["sudo", "cp", tmp, str(path)],
                description=f"installing sudo timeout config to {path}",
            )
            self.shell.run(
                ["sudo", "chmod", "440", str(path)],
                description="setting sudoers file permissions",
            )
            self.shell.run(
                ["sudo", "visudo", "-c"],
                description="validating sudoers configuration",
            )
        finally:
            Path(tmp).unlink(missing_ok=True)

        logger.info("[%s] Sudo timeout set to %d minutes", self.name, minutes)

    def uninstall(self) -> None:
        path = self._sudoers_path()
        self.shell.run(
            ["sudo", "rm", "-f", str(path)],
            description=f"removing {path}",
        )
