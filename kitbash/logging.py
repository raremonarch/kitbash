from __future__ import annotations

import logging
from datetime import datetime
from pathlib import Path

from rich.console import Console
from rich.logging import RichHandler

LOG_DIR = Path.home() / ".local" / "state" / "kitbash"

console = Console()


def setup_logging(verbose: bool = False, session: str = "") -> Path | None:
    """
    Configure logging.
    - Console: Rich handler, INFO (DEBUG if verbose).
    - File: plain text with timestamps, always DEBUG. Only created when
      a session label is provided (install/uninstall commands).

    Returns the log file path, or None when no file is written.
    """
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    root = logging.getLogger()
    root.setLevel(logging.DEBUG)

    console_handler = RichHandler(
        console=console,
        show_time=False,
        show_path=False,
        markup=True,
        rich_tracebacks=True,
    )
    console_handler.setLevel(logging.DEBUG if verbose else logging.INFO)
    root.addHandler(console_handler)

    if not session:
        return None

    timestamp = datetime.now().strftime("%Y%m%dT%H%M%S")
    safe = session.replace(" ", "-").replace("/", "-")
    log_path = LOG_DIR / f"{safe}-{timestamp}.log"

    file_handler = logging.FileHandler(log_path)
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(
        logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s")
    )
    root.addHandler(file_handler)

    return log_path
