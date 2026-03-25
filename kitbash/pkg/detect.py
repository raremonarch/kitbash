from __future__ import annotations

from pathlib import Path

from kitbash.exceptions import KitbashError
from kitbash.pkg.base import PackageManager


def _read_os_release() -> dict[str, str]:
    result: dict[str, str] = {}
    os_release = Path("/etc/os-release")
    if not os_release.exists():
        return result
    for line in os_release.read_text().splitlines():
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            key, _, value = line.partition("=")
            result[key] = value.strip('"')
    return result


def detect() -> PackageManager:
    """Read /etc/os-release and return the appropriate PackageManager."""
    from kitbash.pkg.apt import AptPackageManager
    from kitbash.pkg.dnf import DnfPackageManager
    from kitbash.pkg.pacman import PacmanPackageManager
    from kitbash.shell import Shell

    info = _read_os_release()
    distro_id = info.get("ID", "").lower()
    id_like = info.get("ID_LIKE", "").lower()

    shell = Shell()

    if distro_id in ("fedora",) or "fedora" in id_like:
        return DnfPackageManager(shell)
    if distro_id in ("arch", "manjaro") or "arch" in id_like:
        return PacmanPackageManager(shell)
    if distro_id in ("debian", "ubuntu") or "debian" in id_like or "ubuntu" in id_like:
        return AptPackageManager(shell)

    raise KitbashError(
        f"Unsupported distro: {distro_id!r}. "
        "Supported: Fedora, Arch, Debian/Ubuntu."
    )
