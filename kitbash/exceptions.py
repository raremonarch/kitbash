class KitbashError(Exception):
    """Base exception for all kitbash errors."""


class ConfigError(KitbashError):
    """Invalid or missing configuration."""


class ModuleError(KitbashError):
    """Module install/uninstall failed."""


class PackageError(KitbashError):
    """Package manager operation failed."""


class ShellError(KitbashError):
    """Shell command failed."""
