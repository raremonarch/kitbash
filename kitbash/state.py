from __future__ import annotations

import json
import logging
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Literal

logger = logging.getLogger(__name__)

STATE_PATH = Path.home() / ".local" / "state" / "kitbash" / "state.json"

Action = Literal["install", "uninstall"]
Status = Literal["success", "skipped", "failed"]


class ModuleResult:
    def __init__(
        self,
        name: str,
        status: Status,
        message: str = "",
        action: Action = "install",
    ) -> None:
        self.name = name
        self.status = status
        self.message = message
        self.action = action

    def __repr__(self) -> str:
        return f"ModuleResult({self.name!r}, {self.status!r}, {self.message!r})"


class State:
    def __init__(self, path: Path = STATE_PATH) -> None:
        self.path = path
        self._data: dict[str, dict[str, Any]] = {}
        self._load()

    def _load(self) -> None:
        if self.path.exists():
            try:
                with open(self.path) as f:
                    raw = json.load(f)
                self._data = raw.get("modules", {})
            except (json.JSONDecodeError, KeyError):
                logger.warning("State file corrupted, starting fresh: %s", self.path)
                self._data = {}

    def record(self, result: ModuleResult) -> None:
        self._data[result.name] = {
            "last_run": datetime.now(UTC).isoformat(),
            "status": result.status,
            "action": result.action,
            "message": result.message,
        }

    def get(self, module_name: str) -> dict[str, Any] | None:
        return self._data.get(module_name)

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.path, "w") as f:
            json.dump(
                {
                    "modules": self._data,
                    "last_updated": datetime.now(UTC).isoformat(),
                },
                f,
                indent=2,
            )
        logger.debug("State saved to %s", self.path)

    def all_modules(self) -> dict[str, dict[str, Any]]:
        return dict(self._data)
