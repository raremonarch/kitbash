from __future__ import annotations

import logging
from abc import ABC, abstractmethod
from pathlib import Path
from typing import TYPE_CHECKING

from kitbash.state import ModuleResult

if TYPE_CHECKING:
    from kitbash.config import Config
    from kitbash.pkg.base import PackageManager
    from kitbash.shell import Shell

logger = logging.getLogger(__name__)

BASHRC_D = Path.home() / ".bashrc.d"


# ---------------------------------------------------------------------------
# Module base class
# ---------------------------------------------------------------------------

class Module(ABC):
    name: str
    tier: int = 1
    priority: bool = False  # if True, sorts before other same-tier modules
    description: str = ""

    def __init__(
        self, pkg: PackageManager, config: Config, shell: Shell
    ) -> None:
        self.pkg = pkg
        self.config = config
        self.shell = shell

    @abstractmethod
    def is_installed(self) -> bool: ...

    @abstractmethod
    def install(self) -> None: ...

    @abstractmethod
    def uninstall(self) -> None: ...

    def run_install(self) -> ModuleResult:
        """Idempotency guard: skips if already installed."""
        if self.is_installed():
            logger.info("[%s] Already installed — skipping", self.name)
            return ModuleResult(
                self.name, "skipped", "Already installed", action="install"
            )
        try:
            self.install()
            logger.info("[%s] Installed successfully", self.name)
            return ModuleResult(
                self.name, "success", "Installed", action="install"
            )
        except Exception as e:
            logger.error("[%s] Install failed: %s", self.name, e)
            return ModuleResult(self.name, "failed", str(e), action="install")

    def run_uninstall(self) -> ModuleResult:
        """Skips gracefully if not installed."""
        if not self.is_installed():
            logger.info("[%s] Not installed — skipping uninstall", self.name)
            return ModuleResult(
                self.name, "skipped", "Not installed", action="uninstall"
            )
        try:
            self.uninstall()
            logger.info("[%s] Uninstalled successfully", self.name)
            return ModuleResult(
                self.name, "success", "Uninstalled", action="uninstall"
            )
        except Exception as e:
            logger.error("[%s] Uninstall failed: %s", self.name, e)
            return ModuleResult(
                self.name, "failed", str(e), action="uninstall"
            )


# ---------------------------------------------------------------------------
# Mixins
# ---------------------------------------------------------------------------

class PackageInstallMixin:
    """
    Provides install/uninstall/is_installed based on a `packages` list.
    All packages in the list must be installed for is_installed to return True.
    """
    packages: list[str]

    def is_installed(self) -> bool:
        return all(
            self.pkg.is_installed(p) for p in self.packages  # type: ignore[attr-defined]
        )

    def install(self) -> None:
        self.pkg.install(*self.packages)  # type: ignore[attr-defined]

    def uninstall(self) -> None:
        self.pkg.remove(*self.packages)  # type: ignore[attr-defined]


class SystemdServiceMixin:
    """
    Wraps install/uninstall with systemd service enable/start and stop/disable.

    Requires `service: str` on the subclass.
    Set `user_service = True` for services managed with `systemctl --user`
    (no sudo, runs in the user's session). Defaults to False (system service).

    Designed to be used alongside PackageInstallMixin via super() chaining.
    """
    service: str
    user_service: bool = False

    def _systemctl(self) -> list[str]:
        if self.user_service:
            return ["systemctl", "--user"]
        return ["sudo", "systemctl"]

    def install(self) -> None:
        super().install()  # type: ignore[misc]
        scope = "user" if self.user_service else "system"
        logger.info(
            "Enabling %s service: %s (systemctl)", scope, self.service
        )
        self.shell.run(  # type: ignore[attr-defined]
            [*self._systemctl(), "enable", "--now", self.service],
            description=f"enabling {self.service}",
        )

    def uninstall(self) -> None:
        scope = "user" if self.user_service else "system"
        logger.info("Disabling %s service: %s", scope, self.service)
        self.shell.run(  # type: ignore[attr-defined]
            [*self._systemctl(), "disable", "--now", self.service],
            description=f"disabling {self.service}",
            check=False,
        )
        super().uninstall()  # type: ignore[misc]

    def service_active(self) -> bool:
        result = self.shell.run_quiet(  # type: ignore[attr-defined]
            [*self._systemctl(), "is-active", self.service],
            check=False,
        )
        return bool(result.returncode == 0)


class RepoMixin:
    """
    Wraps install/uninstall with repository add/remove.
    Subclasses must implement add_repo() and remove_repo().
    """

    @abstractmethod
    def add_repo(self) -> None: ...

    @abstractmethod
    def remove_repo(self) -> None: ...

    def install(self) -> None:
        logger.info(
            "Adding repository for %s", self.name  # type: ignore[attr-defined]
        )
        self.add_repo()
        super().install()  # type: ignore[misc]

    def uninstall(self) -> None:
        super().uninstall()  # type: ignore[misc]
        logger.info(
            "Removing repository for %s", self.name  # type: ignore[attr-defined]
        )
        self.remove_repo()


class BinaryInstallMixin:
    """
    Downloads a binary/tarball, extracts it, and copies to install_path.
    Uninstall removes the installed binary.

    Subclasses must set:
        download_url: str     URL to download (supports {version} placeholder)
        install_path: Path    Where the binary ends up
        version: str          Optional version string (default: "latest")
    """
    download_url: str
    install_path: Path
    version: str = "latest"

    def is_installed(self) -> bool:
        return self.install_path.exists()

    def install(self) -> None:
        import tempfile
        import urllib.request

        url = self.download_url.format(version=self.version)
        logger.debug("Downloading %s", url)

        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "download"
            urllib.request.urlretrieve(url, dest)
            self._extract_and_install(dest, Path(tmp))

    def _extract_and_install(self, archive: Path, workdir: Path) -> None:
        """Override this if the archive layout is non-standard."""
        import tarfile
        import zipfile

        if archive.suffix in (".gz", ".tgz") or str(archive).endswith(
            ".tar.gz"
        ):
            with tarfile.open(archive) as tf:
                tf.extractall(workdir)
        elif archive.suffix == ".zip":
            with zipfile.ZipFile(archive) as zf:
                zf.extractall(workdir)

        self.shell.run(  # type: ignore[attr-defined]
            ["sudo", "cp", str(archive), str(self.install_path)],
            description=f"installing to {self.install_path}",
        )
        self.shell.run(  # type: ignore[attr-defined]
            ["sudo", "chmod", "+x", str(self.install_path)],
            description="setting executable bit",
        )

    def uninstall(self) -> None:
        self.shell.run(  # type: ignore[attr-defined]
            ["sudo", "rm", "-f", str(self.install_path)],
            description=f"removing {self.install_path}",
        )


class BashrcDMixin:
    """
    Writes a shell snippet to ~/.bashrc.d/<bashrc_d_filename>.
    Uninstall removes that file.

    Subclasses must set:
        bashrc_d_filename: str      e.g. "claude.sh"
        bashrc_d_content: str       The shell content to write
    """
    bashrc_d_filename: str
    bashrc_d_content: str

    def _bashrc_d_path(self) -> Path:
        return BASHRC_D / self.bashrc_d_filename

    def is_installed(self) -> bool:
        return self._bashrc_d_path().exists()

    def install(self) -> None:
        BASHRC_D.mkdir(parents=True, exist_ok=True)
        self._bashrc_d_path().write_text(self.bashrc_d_content)
        logger.debug("Wrote %s", self._bashrc_d_path())

    def uninstall(self) -> None:
        path = self._bashrc_d_path()
        if path.exists():
            path.unlink()
            logger.debug("Removed %s", path)
