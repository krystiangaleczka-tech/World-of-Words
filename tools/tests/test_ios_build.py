from __future__ import annotations

from pathlib import Path

import pytest

from tools.ios_build import prepare_preset

SOURCE = """[preset.0]
name="Android Debug"
platform="Android"
[preset.0.options]
package/unique_name="org.worldofwords.prototype.debug"

[preset.2]
name="iOS Debug"
platform="iOS"
[preset.2.options]
application/app_store_team_id=""
application/bundle_identifier=""
application/min_ios_version="17.0"
"""


def test_ios_configuration_preserves_android_preset(tmp_path: Path) -> None:
    path = tmp_path / "export_presets.cfg"
    path.write_text(SOURCE)
    prepare_preset(path, "ABCDE12345", "org.example.wordgame")
    changed = path.read_text()
    assert changed.split("[preset.2]\n")[0] == SOURCE.split("[preset.2]\n")[0]
    assert 'application/app_store_team_id="ABCDE12345"' in changed
    assert 'application/bundle_identifier="org.example.wordgame"' in changed
    assert 'application/min_ios_version="17.0"' in changed


@pytest.mark.parametrize(
    ("team", "bundle"),
    [
        ("", "org.example.game"),
        ("123", "org.example.game"),
        ("aBCDE12345", "org.example.game"),
        ("ABCDE12345", ""),
        ("ABCDE12345", "not-a-bundle"),
        ("ABCDE12345", "org.example.game;rm -rf ."),
        ("ABCDE12345", "org.example.\nsecret"),
    ],
)
def test_invalid_parameters_do_not_mutate(tmp_path: Path, team: str, bundle: str) -> None:
    path = tmp_path / "export_presets.cfg"
    path.write_text(SOURCE)
    with pytest.raises(ValueError):
        prepare_preset(path, team, bundle)
    assert path.read_text() == SOURCE


def test_missing_or_preconfigured_ios_rejected(tmp_path: Path) -> None:
    path = tmp_path / "export_presets.cfg"
    cases = (
        SOURCE.split("[preset.2]\n")[0],
        SOURCE.replace(
            'application/app_store_team_id=""', 'application/app_store_team_id="ABCDE12345"'
        ),
    )
    for source in cases:
        path.write_text(source)
        with pytest.raises(ValueError):
            prepare_preset(path, "ABCDE12345", "org.example.game")
        assert path.read_text() == source


def test_repo_presets_keep_android_identifiers() -> None:
    path = Path(__file__).resolve().parents[2] / "game/export_presets.cfg"
    source = path.read_text()
    assert source.count('[preset.2]\nname="iOS Debug"\n') == 1
    assert 'application/min_ios_version="17.0"' in source
    assert 'package/unique_name="org.worldofwords.prototype.debug"' in source
    assert 'package/unique_name="org.worldofwords.prototype"' in source
