from __future__ import annotations

from kitbash.modules.base import Module, PackageInstallMixin


class Grim(PackageInstallMixin, Module):
    """
    grim — screenshot tool for Wayland compositors.

    Package name is identical across all supported distros:
        Fedora  (dnf):    grim
        Arch    (pacman): grim
        Debian  (apt):    grim
    """

    name = "grim"
    tier = 1
    description = "Screenshot tool for Wayland compositors"
    packages = ["grim"]
