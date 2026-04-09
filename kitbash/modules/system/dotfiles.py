from __future__ import annotations

import logging
from pathlib import Path

from kitbash.modules.base import Module

logger = logging.getLogger(__name__)


class Dotfiles(Module):
    """
    Manage $HOME as a bare-style git repository for dotfiles.

    Workflow:
        1. git init $HOME (if .git is absent)
        2. Add or update the `origin` remote
        3. git fetch origin
        4. git reset --hard origin/<branch>

    is_installed is True once $HOME/.git exists with the correct remote set —
    meaning the initial clone is complete. Re-running will still sync if needed
    because install() is idempotent (fetch + reset --hard is safe to repeat).

    Uninstall only warns — removing $HOME/.git would destroy all git history
    and is far too destructive to automate.

    Repo shorthand: "owner/repo" is expanded to
    https://github.com/owner/repo.git automatically.
    """

    name = "dotfiles"
    tier = 0
    priority = True
    description = "Manage $HOME as a git repository for dotfiles"

    def _repo(self) -> str:
        repo = self.config.dotfiles.repo
        if repo and "://" not in repo and not repo.startswith("git@"):
            repo = f"https://github.com/{repo.removesuffix('.git')}.git"
        return repo

    def _branch(self) -> str:
        return self.config.dotfiles.branch or "main"

    def _home(self) -> Path:
        return Path.home()

    def is_installed(self) -> bool:
        if not (self._home() / ".git").is_dir():
            return False
        result = self.shell.run_quiet(
            ["git", "-C", str(self._home()), "remote", "get-url", "origin"],
            check=False,
        )
        return result.returncode == 0 and result.stdout.strip() == self._repo()

    def install(self) -> None:
        home = self._home()
        repo = self._repo()
        branch = self._branch()

        if not repo:
            logger.warning(
                "[%s] No repo configured in dotfiles.repo — skipping", self.name
            )
            return

        if not (home / ".git").is_dir():
            self.shell.run(
                ["git", "-C", str(home), "init"],
                description="initializing $HOME as git repository",
            )
            self.shell.run(
                ["git", "-C", str(home), "branch", "-m", branch],
                description=f"setting default branch to {branch!r}",
            )

        result = self.shell.run_quiet(
            ["git", "-C", str(home), "remote", "get-url", "origin"],
            check=False,
        )
        if result.returncode != 0:
            self.shell.run(
                ["git", "-C", str(home), "remote", "add", "origin", repo],
                description="adding remote origin",
            )
        elif result.stdout.strip() != repo:
            self.shell.run(
                ["git", "-C", str(home), "remote", "set-url", "origin", repo],
                description="updating remote origin URL",
            )

        self.shell.run(
            ["git", "-C", str(home), "fetch", "origin"],
            description="fetching from origin",
        )
        self.shell.run(
            ["git", "-C", str(home), "reset", "--hard", f"origin/{branch}"],
            description=f"resetting to origin/{branch}",
        )

    def uninstall(self) -> None:
        logger.warning(
            "[%s] Dotfiles repo cannot be automatically removed — "
            "removing %s/.git would destroy all git history. "
            "To remove manually: rm -rf %s/.git",
            self.name,
            self._home(),
            self._home(),
        )
