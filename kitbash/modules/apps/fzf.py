from __future__ import annotations

from kitbash.modules.base import Module, PackageInstallMixin


class Fzf(PackageInstallMixin, Module):
    """
    fzf — command-line fuzzy finder.

    Package name is identical across all supported distros:
        Fedora  (dnf):    fzf
        Arch    (pacman): fzf
        Debian  (apt):    fzf
    """

    name = "fzf"
    tier = 1
    description = "Command-line fuzzy finder"
    packages = ["fzf"]
