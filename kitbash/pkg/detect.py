from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

from kitbash.exceptions import KitbashError
from kitbash.pkg.base import PackageManager

if TYPE_CHECKING:
    from kitbash.config import Config


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


def detect(config: Config | None = None) -> PackageManager:
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
        translations = config.translations.dnf if config else {}
        return DnfPackageManager(shell, translations=translations)

    if distro_id in ("arch", "manjaro") or "arch" in id_like:
        translations = config.translations.pacman if config else {}
        aur_helper = config.pacman.aur_helper if config else ""
        return PacmanPackageManager(shell, translations=translations, aur_helper=aur_helper)

    if distro_id in ("debian", "ubuntu") or "debian" in id_like or "ubuntu" in id_like:
        translations = config.translations.apt if config else {}
        return AptPackageManager(shell, translations=translations)

    raise KitbashError(
        f"Unsupported distro: {distro_id!r}. "
        "Supported: Fedora, Arch, Debian/Ubuntu."
    )
