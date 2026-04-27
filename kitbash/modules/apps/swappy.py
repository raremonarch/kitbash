from __future__ import annotations

from kitbash.modules.base import Module, PackageInstallMixin


class Swappy(PackageInstallMixin, Module):
    """
    swappy — Wayland screenshot annotation tool.

    Package name is identical across all supported distros:
        Fedora  (dnf):    swappy
        Arch    (pacman): swappy
        Debian  (apt):    swappy
    """

    name = "swappy"
    tier = 1
    description = "Wayland screenshot annotation tool"
    packages = ["swappy"]
