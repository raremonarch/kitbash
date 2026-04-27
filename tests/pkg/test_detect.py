from __future__ import annotations

from unittest.mock import patch

import pytest

from kitbash.exceptions import KitbashError
from kitbash.pkg.apt import AptPackageManager
from kitbash.pkg.detect import _read_os_release, detect
from kitbash.pkg.dnf import DnfPackageManager
from kitbash.pkg.pacman import PacmanPackageManager


def test_read_os_release_returns_dict() -> None:
    result = _read_os_release()
    assert isinstance(result, dict)


def test_detect_fedora() -> None:
    os_release = {"ID": "fedora", "ID_LIKE": ""}
    with (
        patch("kitbash.pkg.detect._read_os_release", return_value=os_release),
        patch("kitbash.shell.Shell"),
    ):
        pkg = detect()
    assert isinstance(pkg, DnfPackageManager)


def test_detect_arch() -> None:
    os_release = {"ID": "arch", "ID_LIKE": ""}
    with (
        patch("kitbash.pkg.detect._read_os_release", return_value=os_release),
        patch("kitbash.shell.Shell"),
    ):
        pkg = detect()
    assert isinstance(pkg, PacmanPackageManager)


def test_detect_ubuntu() -> None:
    os_release = {"ID": "ubuntu", "ID_LIKE": "debian"}
    with (
        patch("kitbash.pkg.detect._read_os_release", return_value=os_release),
        patch("kitbash.shell.Shell"),
    ):
        pkg = detect()
    assert isinstance(pkg, AptPackageManager)


def test_detect_debian_via_id_like() -> None:
    os_release = {"ID": "raspbian", "ID_LIKE": "debian"}
    with (
        patch("kitbash.pkg.detect._read_os_release", return_value=os_release),
        patch("kitbash.shell.Shell"),
    ):
        pkg = detect()
    assert isinstance(pkg, AptPackageManager)


def test_detect_unsupported_raises() -> None:
    os_release = {"ID": "gentoo", "ID_LIKE": ""}
    with (
        patch("kitbash.pkg.detect._read_os_release", return_value=os_release),
        patch("kitbash.shell.Shell"),
        pytest.raises(KitbashError, match="Unsupported distro"),
    ):
        detect()


# ---------------------------------------------------------------------------
# Package name translations
# ---------------------------------------------------------------------------

def test_apt_translates_fd() -> None:
    pkg = AptPackageManager(shell=None)  # type: ignore[arg-type]
    assert pkg.translate("fd") == "fd-find"


def test_dnf_translates_fd() -> None:
    pkg = DnfPackageManager(shell=None)  # type: ignore[arg-type]
    assert pkg.translate("fd") == "fd-find"


def test_pacman_translates_nordvpn() -> None:
    pkg = PacmanPackageManager(shell=None)  # type: ignore[arg-type]
    assert pkg.translate("nordvpn") == "nordvpn-bin"


def test_pacman_no_translation_for_standard_packages() -> None:
    pkg = PacmanPackageManager(shell=None)  # type: ignore[arg-type]
    assert pkg.translate("fzf") == "fzf"
    assert pkg.translate("zoxide") == "zoxide"


def test_user_translation_overrides_builtin() -> None:
    pkg = PacmanPackageManager(shell=None, translations={"nordvpn": "nordvpn-custom"})  # type: ignore[arg-type]
    assert pkg.translate("nordvpn") == "nordvpn-custom"


def test_user_translation_adds_new_mapping() -> None:
    pkg = AptPackageManager(shell=None, translations={"my-tool": "my-tool-deb"})  # type: ignore[arg-type]
    assert pkg.translate("my-tool") == "my-tool-deb"
    assert pkg.translate("fd") == "fd-find"  # built-in still works


def test_detect_passes_translations_to_pacman() -> None:
    from unittest.mock import MagicMock
    from kitbash.config import Config, TranslationsConfig

    config = Config.empty()
    config.translations = TranslationsConfig(pacman={"my-tool": "my-tool-git"})

    os_release = {"ID": "arch", "ID_LIKE": ""}
    with (
        patch("kitbash.pkg.detect._read_os_release", return_value=os_release),
        patch("kitbash.shell.Shell", return_value=MagicMock()),
    ):
        pkg = detect(config)

    assert isinstance(pkg, PacmanPackageManager)
    assert pkg.translate("my-tool") == "my-tool-git"


def test_detect_passes_aur_helper_override() -> None:
    from unittest.mock import MagicMock
    from kitbash.config import Config, PacmanConfig

    config = Config.empty()
    config.pacman = PacmanConfig(aur_helper="yay")

    os_release = {"ID": "arch", "ID_LIKE": ""}
    with (
        patch("kitbash.pkg.detect._read_os_release", return_value=os_release),
        patch("kitbash.shell.Shell", return_value=MagicMock()),
    ):
        pkg = detect(config)

    assert isinstance(pkg, PacmanPackageManager)
    assert pkg._aur_helper_override == "yay"
