from __future__ import annotations

import logging
import os
import pwd

from kitbash.modules.base import Module, PackageInstallMixin

logger = logging.getLogger(__name__)

# Map shell name → package name (same across Fedora/Arch/Debian)
_SHELL_PACKAGES: dict[str, str] = {
    "zsh":  "zsh",
    "fish": "fish",
    "bash": "bash",
}


class Zsh(PackageInstallMixin, Module):
    """
    Install zsh and set it as the default login shell.

    is_installed requires both the package to be present AND zsh to be
    the current login shell for the running user — partial state triggers
    a full install pass so the shell-change step is never silently skipped.
    """

    name = "zsh"
    tier = 1
    description = "Install zsh and set as default login shell"
    packages = ["zsh"]

    def _zsh_path(self) -> str:
        result = self.shell.run_quiet(["which", "zsh"], check=False)
        return result.stdout.strip() if result.returncode == 0 else "/usr/bin/zsh"

    def _current_shell(self) -> str:
        try:
            user = os.environ.get("USER", "")
            return pwd.getpwnam(user).pw_shell
        except KeyError:
            return ""

    def is_installed(self) -> bool:
        if not self.pkg.is_installed("zsh"):
            return False
        return self._current_shell().endswith("/zsh")

    def install(self) -> None:
        super().install()  # PackageInstallMixin installs the package

        zsh_path = self._zsh_path()

        # Ensure zsh is listed in /etc/shells (required for chsh/usermod)
        shells = self.shell.run_quiet(["cat", "/etc/shells"], check=False)
        if zsh_path not in shells.stdout:
            logger.info("Adding %s to /etc/shells", zsh_path)
            self.shell.run(
                ["sudo", "sh", "-c", f"echo {zsh_path!r} >> /etc/shells"],
                description="adding zsh to /etc/shells",
            )

        user = os.environ.get("USER", "")
        self.shell.run(
            ["sudo", "usermod", "-s", zsh_path, user],
            description=f"setting zsh as default shell for {user!r}",
        )
        logger.info("[%s] Log out and back in for the shell change to take effect", self.name)

    def uninstall(self) -> None:
        user = os.environ.get("USER", "")
        self.shell.run(
            ["sudo", "usermod", "-s", "/bin/bash", user],
            description=f"resetting default shell for {user!r} to bash",
            check=False,
        )
        super().uninstall()  # PackageInstallMixin removes the package
