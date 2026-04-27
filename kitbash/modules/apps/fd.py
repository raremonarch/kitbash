from __future__ import annotations

from kitbash.modules.base import Module, PackageInstallMixin


class Fd(PackageInstallMixin, Module):
    """
    fd — fast and user-friendly alternative to find.

    Package name differs by distro:
        Fedora  (dnf):    fd-find
        Arch    (pacman): fd
        Debian  (apt):    fd-find
    """

    name = "fd"
    tier = 1
    description = "Fast and user-friendly alternative to find"
    packages = ["fd"]
