from __future__ import annotations

from kitbash.modules.base import Module, PackageInstallMixin


class Gimp(PackageInstallMixin, Module):
    """
    GIMP — GNU Image Manipulation Program.

    Package name is identical across all supported distros:
        Fedora  (dnf):    gimp
        Arch    (pacman): gimp
        Debian  (apt):    gimp
    """

    name = "gimp"
    tier = 1
    description = "GNU Image Manipulation Program"
    packages = ["gimp"]
