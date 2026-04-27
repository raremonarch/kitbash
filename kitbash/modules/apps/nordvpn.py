from __future__ import annotations

import getpass
import logging

from kitbash.modules.base import Module

logger = logging.getLogger(__name__)


class NordVPN(Module):
    """
    NordVPN client.

    Arch:          installed from AUR as nordvpn-bin via paru/yay.
    Fedora/Debian: installed via the official NordVPN installer script.

    After install the current user is added to the nordvpn group for
    non-root CLI access and the nordvpnd daemon is enabled.

    NOTE: A logout/login is required for group membership to take effect.
    Run `nordvpn login` after re-login to authenticate.
    """

    name = "nordvpn"
    tier = 1
    description = "NordVPN client"

    _INSTALLER_URL = "https://downloads.nordcdn.com/apps/linux/install.sh"

    def is_installed(self) -> bool:
        return self.shell.which("nordvpn")

    def install(self) -> None:
        from kitbash.pkg.pacman import PacmanPackageManager

        if isinstance(self.pkg, PacmanPackageManager):
            self.pkg.install_aur("nordvpn-bin")
        else:
            self.shell.run(
                [
                    "bash", "-c",
                    f"set -e; t=$(mktemp); trap 'rm -f \"$t\"' EXIT;"
                    f" curl -sSf '{self._INSTALLER_URL}' > \"$t\"; sudo bash \"$t\" -n",
                ],
                description="running NordVPN installer",
            )

        user = getpass.getuser()
        self.shell.run(
            ["sudo", "usermod", "-aG", "nordvpn", user],
            description="adding user to nordvpn group",
        )
        logger.warning(
            "Log out and back in for nordvpn group membership to take effect"
        )
        self.shell.run(
            ["sudo", "systemctl", "enable", "--now", "nordvpnd"],
            description="enabling nordvpnd",
        )

    def uninstall(self) -> None:
        self.shell.run(
            ["sudo", "systemctl", "disable", "--now", "nordvpnd"],
            description="disabling nordvpnd",
            check=False,
        )
        self.pkg.remove("nordvpn")
