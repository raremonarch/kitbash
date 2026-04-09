from __future__ import annotations

import logging
import socket

from kitbash.modules.base import Module

logger = logging.getLogger(__name__)


class Hostname(Module):
    """
    Set the system hostname via hostnamectl.

    Reads the desired hostname from config.system.hostname.
    Uninstall is a no-op — hostname changes cannot be automatically reverted.
    """

    name = "hostname"
    tier = 0
    priority = True
    description = "Set system hostname via hostnamectl"

    def _target(self) -> str:
        return self.config.system.hostname

    def is_installed(self) -> bool:
        hostname = self._target()
        if not hostname:
            return True  # nothing configured, nothing to do
        return socket.gethostname() == hostname

    def install(self) -> None:
        hostname = self._target()
        if not hostname:
            logger.warning("[%s] No hostname configured in system.hostname — skipping", self.name)
            return
        self.shell.run(
            ["sudo", "hostnamectl", "hostname", hostname],
            description=f"setting hostname to {hostname!r}",
        )

    def uninstall(self) -> None:
        logger.info(
            "[%s] Hostname changes cannot be automatically reverted — "
            "use 'sudo hostnamectl hostname <name>' to change manually",
            self.name,
        )
