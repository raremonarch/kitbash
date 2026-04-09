from __future__ import annotations

import logging
from pathlib import Path

from rich.console import Console
from rich.logging import RichHandler

LOG_PATH = Path.home() / ".local" / "state" / "kitbash" / "kit.log"

console = Console()


def setup_logging(verbose: bool = False) -> None:
    """
    Configure dual logging:
    - Console: Rich handler, INFO level (DEBUG if verbose)
    - File: Plain text handler with timestamps, always DEBUG
    """
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

    root = logging.getLogger()
    root.setLevel(logging.DEBUG)

    # Console handler via Rich
    console_handler = RichHandler(
        console=console,
        show_time=False,
        show_path=False,
        markup=True,
        rich_tracebacks=True,
    )
    console_handler.setLevel(logging.DEBUG if verbose else logging.INFO)
    root.addHandler(console_handler)

    # File handler — plain text, always DEBUG
    file_handler = logging.FileHandler(LOG_PATH)
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(
        logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s")
    )
    root.addHandler(file_handler)
