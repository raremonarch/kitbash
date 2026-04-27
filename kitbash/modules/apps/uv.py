from __future__ import annotations

from kitbash.modules.base import Module, PackageInstallMixin


class Uv(PackageInstallMixin, Module):
    """
    uv — fast Python package and project manager.

    Package name is identical across all supported distros:
        Fedora  (dnf):    uv
        Arch    (pacman): uv
        Debian  (apt):    uv
    """

    name = "uv"
    tier = 1
    description = "Fast Python package and project manager"
    packages = ["uv"]
