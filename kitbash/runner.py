from __future__ import annotations

import importlib
import inspect
import logging
import pkgutil
from typing import TYPE_CHECKING

import kitbash.modules
from kitbash.modules.base import Module
from kitbash.state import ModuleResult, State

if TYPE_CHECKING:
    from kitbash.config import Config
    from kitbash.pkg.base import PackageManager
    from kitbash.shell import Shell

logger = logging.getLogger(__name__)


class Runner:
    def __init__(self, pkg: PackageManager, config: Config, shell: Shell, state: State) -> None:
        self.pkg = pkg
        self.config = config
        self.shell = shell
        self.state = state

    def discover(self) -> list[type[Module]]:
        """Import all submodules of kitbash.modules and return all Module subclasses."""
        _import_all_modules()
        found: list[type[Module]] = []
        for subclass in _all_subclasses(Module):
            if inspect.isabstract(subclass):
                continue
            if not hasattr(subclass, "name"):
                continue
            found.append(subclass)
        return found

    def _sort_key(self, cls: type[Module]) -> tuple[int, int, str]:
        # (tier, priority-inverted, name)
        return (cls.tier, 0 if cls.priority else 1, cls.name)

    def enabled_modules(self) -> list[type[Module]]:
        """Modules that are enabled in config, sorted by tier then priority then name."""
        all_modules = self.discover()
        enabled = [
            cls for cls in all_modules
            if self.config.is_enabled(cls.name)
        ]
        return sorted(enabled, key=self._sort_key)

    def _instantiate(self, cls: type[Module]) -> Module:
        return cls(self.pkg, self.config, self.shell)

    def run_all(self) -> list[ModuleResult]:
        results = []
        for cls in self.enabled_modules():
            module = self._instantiate(cls)
            result = module.run_install()
            self.state.record(result)
            results.append(result)
        self.state.save()
        return results

    def run_one(self, name: str) -> ModuleResult:
        cls = self._find(name)
        module = self._instantiate(cls)
        result = module.run_install()
        self.state.record(result)
        self.state.save()
        return result

    def uninstall_all(self) -> list[ModuleResult]:
        """Uninstall all enabled modules in reverse tier order."""
        results = []
        modules = list(reversed(self.enabled_modules()))
        for cls in modules:
            module = self._instantiate(cls)
            result = module.run_uninstall()
            self.state.record(result)
            results.append(result)
        self.state.save()
        return results

    def uninstall_one(self, name: str) -> ModuleResult:
        cls = self._find(name)
        module = self._instantiate(cls)
        result = module.run_uninstall()
        self.state.record(result)
        self.state.save()
        return result

    def _find(self, name: str) -> type[Module]:
        all_modules = self.discover()
        for cls in all_modules:
            if cls.name == name:
                return cls
        if all_modules:
            available = ", ".join(sorted(cls.name for cls in all_modules))
            raise ValueError(f"Unknown module: {name!r}\nAvailable: {available}")
        else:
            raise ValueError(f"Unknown module: {name!r}\nNo modules are implemented yet.")


def _import_all_modules() -> None:
    """Recursively import all subpackages of kitbash.modules."""
    package = kitbash.modules
    prefix = package.__name__ + "."
    for _finder, modname, _ispkg in pkgutil.walk_packages(
        path=package.__path__,  # type: ignore[attr-defined]
        prefix=prefix,
    ):
        importlib.import_module(modname)


def _all_subclasses(cls: type) -> list[type]:
    result = []
    for sub in cls.__subclasses__():
        result.append(sub)
        result.extend(_all_subclasses(sub))
    return result
