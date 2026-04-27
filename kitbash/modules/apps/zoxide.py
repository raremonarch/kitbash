from __future__ import annotations

from kitbash.modules.base import Module, PackageInstallMixin


class Zoxide(PackageInstallMixin, Module):
    """
    zoxide — smarter cd command that learns your habits.

    Package name is identical across all supported distros:
        Fedora  (dnf):    zoxide
        Arch    (pacman): zoxide
        Debian  (apt):    zoxide
    """

    name = "zoxide"
    tier = 1
    description = "Smarter cd command that learns your habits"
    packages = ["zoxide"]
