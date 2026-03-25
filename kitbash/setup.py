from __future__ import annotations

import os
import re
import shutil
import subprocess
from pathlib import Path

from rich.console import Console
from rich.prompt import Confirm, Prompt

console = Console()

CONFIG_DEST = Path.home() / ".config" / "kitbash" / "kit.toml"
BASHRC_D = Path.home() / ".bashrc.d"
EXAMPLE_CONFIG = Path(__file__).parent.parent / "kit.toml.example"

_ALIAS_CHOICES = ["kit", "kb", "none"]
_SHELL_RC: dict[str, Path] = {
    "zsh":  Path.home() / ".zshrc",
    "bash": Path.home() / ".bashrc",
    "fish": Path.home() / ".config" / "fish" / "config.fish",
}

# Matches any existing kitbash alias line, e.g. alias kit="kitbash" or alias kb='kitbash'
_ALIAS_RE = re.compile(r"""^alias\s+\w+=['"]kitbash['"]""", re.MULTILINE)


def _detect_shell() -> str:
    shell_path = os.environ.get("SHELL", "")
    name = Path(shell_path).name
    return name if name in _SHELL_RC else "bash"


def _alias_snippet(alias: str) -> str:
    return f'alias {alias}="kitbash"\n'


def _find_existing_alias(path: Path) -> str | None:
    """Return the alias name if a kitbash alias already exists in this file."""
    if not path.exists():
        return None
    text = path.read_text()
    match = _ALIAS_RE.search(text)
    if match:
        # Extract alias name from e.g. `alias kit="kitbash"`
        return match.group(0).split()[1].split("=")[0]
    return None


def _replace_alias_in_file(path: Path, new_alias: str) -> None:
    text = path.read_text()
    updated = _ALIAS_RE.sub(_alias_snippet(new_alias).rstrip(), text)
    path.write_text(updated)


def alias_is_configured() -> bool:
    """Return True if a kitbash alias already exists in any of the places we'd write to."""
    if BASHRC_D.is_dir():
        return _find_existing_alias(BASHRC_D / "kitbash.sh") is not None
    shell = _detect_shell()
    return _find_existing_alias(_SHELL_RC[shell]) is not None


def _write_alias(alias: str) -> tuple[Path, bool]:
    """
    Write (or update) the kitbash alias.
    Returns (destination path, was_updated) where was_updated=True means an
    existing alias was replaced rather than appended.
    """
    # bashrc.d: always use a dedicated file — easy to overwrite cleanly
    if BASHRC_D.is_dir():
        dest = BASHRC_D / "kitbash.sh"
        was_updated = dest.exists()
        dest.write_text(_alias_snippet(alias))
        return dest, was_updated

    shell = _detect_shell()
    rc = _SHELL_RC[shell]

    if _find_existing_alias(rc):
        _replace_alias_in_file(rc, alias)
        return rc, True

    with rc.open("a") as f:
        f.write(f"\n# kitbash alias (added by kitbash init)\n")
        f.write(_alias_snippet(alias))
    return rc, False


def run_first_time_setup() -> None:
    console.print()
    console.print("[bold]kitbash[/bold] — initializing...")
    console.print("[dim]conducting first run setup[/dim]")
    console.print()

    # ── Config ──────────────────────────────────────────────────────────────
    if CONFIG_DEST.exists():
        console.print(f"[green]✓[/green] Config already exists at [dim]{CONFIG_DEST}[/dim]")
    else:
        CONFIG_DEST.parent.mkdir(parents=True, exist_ok=True)
        example = EXAMPLE_CONFIG if EXAMPLE_CONFIG.exists() else None

        if example:
            shutil.copy(example, CONFIG_DEST)
            console.print(f"[green]✓[/green] Config copied to [dim]{CONFIG_DEST}[/dim]")
        else:
            CONFIG_DEST.write_text("[system]\n\n[modules]\n")
            console.print(f"[green]✓[/green] Blank config created at [dim]{CONFIG_DEST}[/dim]")

    # ── Alias ────────────────────────────────────────────────────────────────
    console.print()

    # Check if an alias already exists anywhere we'd write to
    existing_alias: str | None = None
    existing_in: Path | None = None
    if BASHRC_D.is_dir():
        existing_alias = _find_existing_alias(BASHRC_D / "kitbash.sh")
        existing_in = BASHRC_D / "kitbash.sh"
    else:
        shell = _detect_shell()
        rc = _SHELL_RC[shell]
        existing_alias = _find_existing_alias(rc)
        existing_in = rc

    if existing_alias:
        console.print(
            f"[green]✓[/green] Alias [bold]{existing_alias}[/bold] already set"
            f" in [dim]{existing_in}[/dim]"
        )
        if not Confirm.ask("  Update it?", default=False):
            alias = "none"
        else:
            alias = Prompt.ask("  New alias", choices=_ALIAS_CHOICES, default=existing_alias)
    else:
        alias = Prompt.ask(
            "  Alias for kitbash commands",
            choices=_ALIAS_CHOICES,
            default="kit",
        )

    if alias != "none":
        dest, updated = _write_alias(alias)
        verb = "Updated" if updated else "Written"
        console.print(f"[green]✓[/green] {verb}: [bold]{alias}[/bold] → [dim]{dest}[/dim]")
        console.print(f"  [dim]Reload your shell or run: source {dest}[/dim]")

    # ── Open config ──────────────────────────────────────────────────────────
    console.print()
    if Confirm.ask("  Open config for editing now?", default=True):
        editor = os.environ.get("EDITOR") or os.environ.get("VISUAL") or "nano"
        subprocess.run([editor, str(CONFIG_DEST)])

    console.print()
    console.print("[green]Done![/green] Run [bold]kitbash list[/bold] to see available modules.")
    console.print()
