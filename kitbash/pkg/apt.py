from __future__ import annotations

import logging

from kitbash.pkg.base import PackageManager
from kitbash.shell import Shell

logger = logging.getLogger(__name__)


class AptPackageManager(PackageManager):

    name = "apt"

    PACKAGE_NAMES: dict[str, str] = {
        "breeze-cursor-theme": "breeze-cursor-theme",
    }

    def __init__(self, shell: Shell) -> None:
        self.shell = shell

    def install(self, *packages: str) -> None:
        translated = [self.translate(p) for p in packages]
        logger.info("Installing %s using apt", ", ".join(translated))
        self.shell.run(
            ["sudo", "apt-get", "install", "-y", *translated],
            description=f"installing {', '.join(translated)}",
        )

    def remove(self, *packages: str) -> None:
        translated = [self.translate(p) for p in packages]
        logger.info("Removing %s using apt", ", ".join(translated))
        self.shell.run(
            ["sudo", "apt-get", "remove", "-y", *translated],
            description=f"removing {', '.join(translated)}",
        )

    def is_installed(self, package: str) -> bool:
        translated = self.translate(package)
        result = self.shell.run_quiet(
            ["dpkg-query", "-W", "-f=${Status}", translated],
            check=False,
        )
        return "install ok installed" in result.stdout

    def update(self) -> None:
        self.shell.run(["sudo", "apt-get", "update"], description="updating package lists")

    def add_repo(self, name: str, **kwargs: str) -> None:
        if self.repo_exists(name):
            logger.info("Repository %s already configured", name)
            return
        logger.info("Adding apt repository: %s", name)
        url = kwargs.get("url", "")
        self.shell.run(
            ["sudo", "add-apt-repository", "-y", url],
            description=f"adding repo {name}",
        )

    def remove_repo(self, name: str) -> None:
        if not self.repo_exists(name):
            return
        logger.info("Removing apt repository: %s", name)
        self.shell.run(
            ["sudo", "add-apt-repository", "--remove", "-y", name],
            description=f"removing repo {name}",
        )

    def repo_exists(self, name: str) -> bool:
        result = self.shell.run_quiet(
            ["apt-cache", "policy"],
            check=False,
        )
        return name in result.stdout
