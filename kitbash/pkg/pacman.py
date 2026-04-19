from __future__ import annotations

import logging

from kitbash.pkg.base import PackageManager
from kitbash.shell import Shell

logger = logging.getLogger(__name__)


class PacmanPackageManager(PackageManager):

    name = "pacman"

    PACKAGE_NAMES: dict[str, str] = {
        "breeze-cursor-theme": "breeze",
    }

    def __init__(self, shell: Shell) -> None:
        self.shell = shell
        self._aur_helper: str | None = None

    @property
    def aur_helper(self) -> str:
        if self._aur_helper is None:
            for helper in ("paru", "yay"):
                if self.shell.which(helper):
                    self._aur_helper = helper
                    break
            else:
                self._aur_helper = "paru"  # will be bootstrapped on first use
        return self._aur_helper

    def install(self, *packages: str) -> None:
        translated = [self.translate(p) for p in packages]
        logger.info("Installing %s using pacman", ", ".join(translated))
        self.shell.run(
            ["sudo", "pacman", "-Sy", "--noconfirm", *translated],
            description=f"installing {', '.join(translated)}",
        )

    def install_aur(self, *packages: str) -> None:
        logger.info("Installing %s using %s (AUR)", ", ".join(packages), self.aur_helper)
        self.shell.run(
            [self.aur_helper, "-S", "--noconfirm", *packages],
            description=f"installing AUR: {', '.join(packages)}",
        )

    def remove(self, *packages: str) -> None:
        translated = [self.translate(p) for p in packages]
        logger.info("Removing %s using pacman", ", ".join(translated))
        self.shell.run(
            ["sudo", "pacman", "-Rs", "--noconfirm", *translated],
            description=f"removing {', '.join(translated)}",
        )

    def is_installed(self, package: str) -> bool:
        translated = self.translate(package)
        result = self.shell.run_quiet(
            ["pacman", "-Q", translated],
            check=False,
        )
        return result.returncode == 0

    def update(self) -> None:
        self.shell.run(["sudo", "pacman", "-Sy"], description="syncing package databases")

    def add_repo(self, name: str, **kwargs: str) -> None:
        logger.warning("add_repo not supported on Arch; use AUR or manual pacman.conf edits")

    def remove_repo(self, name: str) -> None:
        logger.warning("remove_repo not supported on Arch")

    def repo_exists(self, name: str) -> bool:
        result = self.shell.run_quiet(["pacman-conf", "--repo-list"], check=False)
        return name in result.stdout.splitlines()
