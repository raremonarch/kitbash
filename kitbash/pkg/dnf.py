from __future__ import annotations

import logging

from kitbash.pkg.base import PackageManager
from kitbash.shell import Shell

logger = logging.getLogger(__name__)


class DnfPackageManager(PackageManager):

    name = "dnf"

    PACKAGE_NAMES: dict[str, str] = {
        "breeze-cursors": "breeze-cursor-theme",
        "fd": "fd-find",
    }

    def __init__(self, shell: Shell, *, translations: dict[str, str] | None = None) -> None:
        self.shell = shell
        self._user_translations: dict[str, str] = translations or {}

    def install(self, *packages: str) -> None:
        translated = [self.translate(p) for p in packages]
        logger.info("Installing %s using dnf", ", ".join(translated))
        self.shell.run(
            ["sudo", "dnf", "install", "-y", *translated],
            description=f"installing {', '.join(translated)}",
        )

    def remove(self, *packages: str) -> None:
        translated = [self.translate(p) for p in packages]
        logger.info("Removing %s using dnf", ", ".join(translated))
        self.shell.run(
            ["sudo", "dnf", "remove", "-y", *translated],
            description=f"removing {', '.join(translated)}",
        )

    def is_installed(self, package: str) -> bool:
        translated = self.translate(package)
        result = self.shell.run_quiet(
            ["rpm", "-q", translated],
            check=False,
        )
        return result.returncode == 0

    def update(self) -> None:
        self.shell.run(
            ["sudo", "dnf", "check-update"], check=False, description="checking for updates"
        )

    def add_repo(self, name: str, **kwargs: str) -> None:
        if self.repo_exists(name):
            logger.info("Repository %s already configured", name)
            return
        logger.info("Adding dnf repository: %s", name)
        url = kwargs.get("url", "")
        gpg_key = kwargs.get("gpg_key", "")
        cmd = [
            "sudo", "dnf", "config-manager", "addrepo",
            f"--id={name}",
            f"--set=baseurl={url}",
            f"--set=name={name}",
            "--set=enabled=1",
            "--set=gpgcheck=1" if gpg_key else "--set=gpgcheck=0",
        ]
        if gpg_key:
            cmd.append(f"--set=gpgkey={gpg_key}")
        self.shell.run(cmd, description=f"adding repo {name}")

    def remove_repo(self, name: str) -> None:
        if not self.repo_exists(name):
            return
        logger.info("Disabling dnf repository: %s", name)
        self.shell.run(
            ["sudo", "dnf", "config-manager", "setopt", f"{name}.enabled=0"],
            description=f"disabling repo {name}",
        )

    def repo_exists(self, name: str) -> bool:
        result = self.shell.run_quiet(
            ["dnf", "repolist", "--all"],
            check=False,
        )
        return name in result.stdout

    def enable_copr(self, repo: str) -> None:
        """Enable a Fedora COPR repository (e.g. 'owner/repo')."""
        logger.info("Enabling COPR repository: %s", repo)
        self.shell.run(
            ["sudo", "dnf", "copr", "enable", "-y", repo],
            description=f"enabling COPR {repo}",
        )

    def disable_copr(self, repo: str) -> None:
        logger.info("Disabling COPR repository: %s", repo)
        self.shell.run(
            ["sudo", "dnf", "copr", "disable", "-y", repo],
            description=f"disabling COPR {repo}",
        )
