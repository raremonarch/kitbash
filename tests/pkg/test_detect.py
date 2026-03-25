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
    with patch("kitbash.pkg.detect._read_os_release", return_value=os_release):
        with patch("kitbash.shell.Shell"):
            pkg = detect()
    assert isinstance(pkg, DnfPackageManager)


def test_detect_arch() -> None:
    os_release = {"ID": "arch", "ID_LIKE": ""}
    with patch("kitbash.pkg.detect._read_os_release", return_value=os_release):
        with patch("kitbash.shell.Shell"):
            pkg = detect()
    assert isinstance(pkg, PacmanPackageManager)


def test_detect_ubuntu() -> None:
    os_release = {"ID": "ubuntu", "ID_LIKE": "debian"}
    with patch("kitbash.pkg.detect._read_os_release", return_value=os_release):
        with patch("kitbash.shell.Shell"):
            pkg = detect()
    assert isinstance(pkg, AptPackageManager)


def test_detect_debian_via_id_like() -> None:
    os_release = {"ID": "raspbian", "ID_LIKE": "debian"}
    with patch("kitbash.pkg.detect._read_os_release", return_value=os_release):
        with patch("kitbash.shell.Shell"):
            pkg = detect()
    assert isinstance(pkg, AptPackageManager)


def test_detect_unsupported_raises() -> None:
    os_release = {"ID": "gentoo", "ID_LIKE": ""}
    with patch("kitbash.pkg.detect._read_os_release", return_value=os_release):
        with patch("kitbash.shell.Shell"):
            with pytest.raises(KitbashError, match="Unsupported distro"):
                detect()
