"""Prevent legal notice drift without relying on raw text inclusion in exports."""

import json
import subprocess
import sys
from pathlib import Path

import pytest

from tools.generate_credits import NOTICES, ROOT, generate, render


def test_resource_preserves_unicode_quotes_newlines_and_backslashes():
    notice = 'Copyright © — "author"\nline two\\path\tend\n'
    resource = render(notice)
    assert resource.startswith('[gd_resource type="Resource" format=3]\n')
    encoded = resource.split("metadata/notice = ", 1)[1]
    assert json.loads(encoded) == notice


def test_tracked_resources_are_current():
    assert generate(ROOT, check=True) == []


@pytest.mark.parametrize("state", ["missing", "stale"])
def test_check_is_nonmutating_and_regeneration_repairs_exact_notice(tmp_path, state):
    for source, target in NOTICES.items():
        canonical = tmp_path / source
        canonical.parent.mkdir(parents=True, exist_ok=True)
        canonical.write_text("Full legal text ©\n", encoding="utf-8")
        if state == "stale":
            (tmp_path / target).write_text("stale", encoding="utf-8")
    assert generate(tmp_path, check=True) == list(NOTICES.values())
    for target in NOTICES.values():
        output = tmp_path / target
        if state == "stale":
            assert output.read_text() == "stale"
        else:
            assert not output.exists()
    assert generate(tmp_path, check=False) == list(NOTICES.values())
    assert generate(tmp_path, check=True) == []
    for source, target in NOTICES.items():
        encoded = (tmp_path / target).read_text().split("metadata/notice = ")[1]
        assert json.loads(encoded) == (tmp_path / source).read_text()


def test_cli_resolves_repository_from_any_working_directory(tmp_path):
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools/generate_credits.py"), "--check"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
    assert "Credits resources current" in result.stdout
    assert list(tmp_path.iterdir()) == []
