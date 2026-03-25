from __future__ import annotations

from tests.conftest import MockPkg


def test_mock_pkg_install() -> None:
    pkg = MockPkg()
    pkg.install("docker-ce", "docker-ce-cli")
    assert "docker-ce" in pkg.installed
    assert "docker-ce-cli" in pkg.installed


def test_mock_pkg_remove() -> None:
    pkg = MockPkg()
    pkg.mark_installed("docker-ce")
    pkg.remove("docker-ce")
    assert "docker-ce" not in pkg.installed


def test_mock_pkg_is_installed() -> None:
    pkg = MockPkg()
    pkg.mark_installed("vim")
    assert pkg.is_installed("vim") is True
    assert pkg.is_installed("emacs") is False


def test_mock_pkg_repo_ops() -> None:
    pkg = MockPkg()
    assert not pkg.repo_exists("my-repo")
    pkg.add_repo("my-repo", url="https://example.com")
    assert pkg.repo_exists("my-repo")
    pkg.remove_repo("my-repo")
    assert not pkg.repo_exists("my-repo")


def test_translate_fallback() -> None:
    pkg = MockPkg()
    # MockPkg has no PACKAGE_NAMES, so translate returns the name unchanged
    assert pkg.translate("anything") == "anything"
