from __future__ import annotations

from abc import ABC, abstractmethod


class PackageManager(ABC):

    @abstractmethod
    def install(self, *packages: str) -> None: ...

    @abstractmethod
    def remove(self, *packages: str) -> None: ...

    @abstractmethod
    def is_installed(self, package: str) -> bool: ...

    @abstractmethod
    def update(self) -> None: ...

    @abstractmethod
    def add_repo(self, name: str, **kwargs: str) -> None: ...

    @abstractmethod
    def remove_repo(self, name: str) -> None: ...

    @abstractmethod
    def repo_exists(self, name: str) -> bool: ...

    def translate(self, name: str) -> str:
        """
        Translate a logical package name to this distro's package name.
        User translations (from kit.toml) take precedence over built-in defaults.
        """
        user: dict[str, str] = getattr(self, "_user_translations", {})
        if name in user:
            return user[name]
        return self.PACKAGE_NAMES.get(name, name)

    # Subclasses may override this with distro-specific name mappings
    PACKAGE_NAMES: dict[str, str] = {}
