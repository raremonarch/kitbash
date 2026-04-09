from __future__ import annotations

import logging

from kitbash.modules.base import Module, PackageInstallMixin

logger = logging.getLogger(__name__)


class PipeWire(PackageInstallMixin, Module):
    """
    PipeWire audio stack: PipeWire, WirePlumber session manager, ALSA/PulseAudio bridges.

    Package names are identical across supported distros:
        Fedora  (dnf):    pipewire pipewire-alsa pipewire-pulse wireplumber alsa-utils
        Arch    (pacman): pipewire pipewire-alsa pipewire-pulse wireplumber alsa-utils
        Debian  (apt):    pipewire pipewire-audio wireplumber alsa-utils

    Runs as three user services (no sudo needed):
        pipewire, pipewire-pulse, wireplumber
    """

    name = "pipewire"
    tier = 1
    description = "PipeWire audio stack with WirePlumber session manager"
    packages = ["pipewire", "pipewire-alsa", "pipewire-pulse", "wireplumber", "alsa-utils"]

    _services = ["pipewire", "pipewire-pulse", "wireplumber"]

    def install(self) -> None:
        super().install()  # installs all packages via PackageInstallMixin
        for svc in self._services:
            self.shell.run(
                ["systemctl", "--user", "enable", "--now", svc],
                description=f"enabling user service {svc}",
            )

    def uninstall(self) -> None:
        for svc in self._services:
            self.shell.run(
                ["systemctl", "--user", "disable", "--now", svc],
                description=f"disabling user service {svc}",
                check=False,
            )
        super().uninstall()
