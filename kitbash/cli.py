from __future__ import annotations

from pathlib import Path

import typer
from rich.console import Console
from rich.table import Table

from kitbash import logging as kit_logging
from kitbash.config import DEFAULT_CONFIG_PATH, Config
from kitbash.exceptions import ConfigError
from kitbash.pkg.detect import detect
from kitbash.runner import Runner
from kitbash.setup import _write_alias, alias_is_configured, run_first_time_setup
from kitbash.shell import Shell, SudoSession
from kitbash.state import ModuleResult, State

app = typer.Typer(
    name="kitbash",
    help="Modular system configurator and application installer.",
    add_completion=False,
)
console = Console()


def _build_runner(config_path: Path) -> Runner:
    if config_path == DEFAULT_CONFIG_PATH and (
        not config_path.exists() or not alias_is_configured()
    ):
        run_first_time_setup()
        raise typer.Exit(0)

    try:
        config = Config.load(config_path)
    except ConfigError as e:
        console.print(f"[red]Config error:[/red] {e}")
        raise typer.Exit(1) from e

    shell = Shell()
    pkg = detect()
    state = State()
    return Runner(pkg=pkg, config=config, shell=shell, state=state)


@app.command()
def install(
    module: str | None = typer.Argument(  # noqa: B008
        None, help="Module name to install. Omit to install all enabled."
    ),
    config: Path = typer.Option(  # noqa: B008
        DEFAULT_CONFIG_PATH, "--config", "-c", help="Path to kit.toml"
    ),
    verbose: bool = typer.Option(False, "--verbose", "-v"),  # noqa: B008
) -> None:
    """Install one module or all enabled modules."""
    kit_logging.setup_logging(verbose=verbose)
    runner = _build_runner(config)

    with SudoSession():
        if module:
            try:
                result = runner.run_one(module)
            except ValueError as e:
                console.print(f"[red]Error:[/red] {e}")
                raise typer.Exit(1) from None
            _print_result(result)
        else:
            results = runner.run_all()
            _print_results_table(results)


@app.command()
def uninstall(
    module: str | None = typer.Argument(  # noqa: B008
        None, help="Module name to uninstall. Omit to uninstall all."
    ),
    config: Path = typer.Option(  # noqa: B008
        DEFAULT_CONFIG_PATH, "--config", "-c", help="Path to kit.toml"
    ),
    verbose: bool = typer.Option(False, "--verbose", "-v"),  # noqa: B008
) -> None:
    """Uninstall one module or all installed modules (reverse tier order)."""
    kit_logging.setup_logging(verbose=verbose)
    runner = _build_runner(config)

    with SudoSession():
        if module:
            try:
                result = runner.uninstall_one(module)
            except ValueError as e:
                console.print(f"[red]Error:[/red] {e}")
                raise typer.Exit(1) from None
            _print_result(result)
        else:
            results = runner.uninstall_all()
            _print_results_table(results)


@app.command("list")
def list_modules(
    config: Path = typer.Option(DEFAULT_CONFIG_PATH, "--config", "-c"),  # noqa: B008
) -> None:
    """List all available modules with their tier and description."""
    kit_logging.setup_logging()

    try:
        cfg = Config.load(config)
    except ConfigError:
        cfg = Config.empty()

    shell = Shell()
    pkg = detect()
    state = State()
    runner = Runner(pkg=pkg, config=cfg, shell=shell, state=state)

    all_modules = sorted(runner.discover(), key=lambda c: (c.tier, c.name))

    table = Table(title="Available Modules", show_lines=False)
    table.add_column("Module", style="bold")
    table.add_column("Tier", justify="center")
    table.add_column("Auto-install", justify="center")
    table.add_column("Description")

    for cls in all_modules:
        enabled = cfg.is_enabled(cls.name)
        enabled_str = "[green]yes[/green]" if enabled else "[dim]no[/dim]"
        table.add_row(cls.name, str(cls.tier), enabled_str, cls.description)

    console.print(table)


@app.command()
def status(
    config: Path = typer.Option(DEFAULT_CONFIG_PATH, "--config", "-c"),  # noqa: B008
) -> None:
    """Show install status of all modules."""
    kit_logging.setup_logging()

    try:
        cfg = Config.load(config)
    except ConfigError:
        cfg = Config.empty()

    shell = Shell()
    pkg = detect()
    state = State()
    runner = Runner(pkg=pkg, config=cfg, shell=shell, state=state)

    all_modules = sorted(runner.discover(), key=lambda c: (c.tier, c.name))

    table = Table(title="Module Status", show_lines=False)
    table.add_column("Module", style="bold")
    table.add_column("Tier", justify="center")
    table.add_column("Installed", justify="center")
    table.add_column("Last Run")
    table.add_column("Last Status")

    for cls in all_modules:
        module = cls(pkg, cfg, shell)
        installed = module.is_installed()
        installed_str = "[green]yes[/green]" if installed else "[dim]no[/dim]"

        record = state.get(cls.name)
        last_run = record["last_run"][:19].replace("T", " ") if record else "—"
        last_status = record["status"] if record else "—"

        table.add_row(cls.name, str(cls.tier), installed_str, last_run, last_status)

    console.print(table)


@app.command()
def init() -> None:
    """Run first-time setup: copy config, create alias, open editor."""
    run_first_time_setup()


set_app = typer.Typer(help="Update kitbash settings.")
app.add_typer(set_app, name="set")

wallpaper_app = typer.Typer(help="Manage desktop wallpaper.")
app.add_typer(wallpaper_app, name="wallpaper")


@set_app.command("alias")
def set_alias(name: str = typer.Argument(..., help="Alias name, e.g. kb")) -> None:  # noqa: B008
    """Set or update the shell alias for kitbash."""
    dest, updated = _write_alias(name)
    verb = "Updated" if updated else "Written"
    console.print(f"[green]✓[/green] {verb}: [bold]{name}[/bold] → [dim]{dest}[/dim]")
    console.print(f"  [dim]Reload your shell or run: source {dest}[/dim]")



@wallpaper_app.command("get")
def wallpaper_get() -> None:
    """Print the currently active wallpaper path."""
    from kitbash.wallpaper import get_current

    path = get_current()
    if path:
        console.print(str(path))
    else:
        console.print("[yellow]No wallpaper found.[/yellow]")
        raise typer.Exit(1)


@wallpaper_app.command("set")
def wallpaper_set(
    path: Path = typer.Argument(..., help="Path to the new wallpaper image"),  # noqa: B008
    verbose: bool = typer.Option(False, "--verbose", "-v"),  # noqa: B008
) -> None:
    """Set the desktop wallpaper and apply it live."""
    kit_logging.setup_logging(verbose=verbose)
    from kitbash.wallpaper import set_wallpaper

    if not path.exists():
        console.print(f"[red]Error:[/red] File not found: {path}")
        raise typer.Exit(1)
    shell = Shell()
    with SudoSession():
        set_wallpaper(path, shell)
    console.print(f"[green]✓[/green] Wallpaper set to [bold]{path}[/bold]")



def _print_result(result: ModuleResult) -> None:
    color = {"success": "green", "skipped": "yellow", "failed": "red"}.get(result.status, "white")
    console.print(f"[{color}][{result.status.upper()}][/{color}] {result.name}: {result.message}")
    if result.status == "failed":
        raise typer.Exit(1)


def _print_results_table(results: list[ModuleResult]) -> None:
    table = Table(show_header=True, show_lines=False)
    table.add_column("Module", style="bold")
    table.add_column("Status", justify="center")
    table.add_column("Message")

    for r in results:
        color = {"success": "green", "skipped": "yellow", "failed": "red"}.get(r.status, "white")
        table.add_row(r.name, f"[{color}]{r.status}[/{color}]", r.message)

    console.print(table)

    failed = [r for r in results if r.status == "failed"]
    if failed:
        raise typer.Exit(1)


if __name__ == "__main__":
    app()
