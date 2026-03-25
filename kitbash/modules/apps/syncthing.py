from __future__ import annotations

from kitbash.modules.base import Module, PackageInstallMixin, SystemdServiceMixin


class Syncthing(SystemdServiceMixin, PackageInstallMixin, Module):
    """
    Syncthing — continuous file synchronisation daemon.

    Runs as a systemd user service (not a system service).

    Package name is identical across all supported distros:
        Fedora  (dnf):    syncthing
        Arch    (pacman): syncthing
        Debian  (apt):    syncthing
    """

    name = "syncthing"
    tier = 1
    description = "Continuous file synchronisation daemon"
    packages = ["syncthing"]
    service = "syncthing"
    user_service = True
