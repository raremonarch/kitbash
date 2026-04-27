from __future__ import annotations

from kitbash.modules.base import Module, PackageInstallMixin


class Slurp(PackageInstallMixin, Module):
    """
    slurp — select a region in a Wayland compositor (used with grim).

    Package name is identical across all supported distros:
        Fedora  (dnf):    slurp
        Arch    (pacman): slurp
        Debian  (apt):    slurp
    """

    name = "slurp"
    tier = 1
    description = "Wayland region selector for use with grim"
    packages = ["slurp"]
