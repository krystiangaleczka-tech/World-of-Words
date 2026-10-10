"""Audio metadata, real assets and named-call validation enforced by existing CI."""

import json
import shutil
from pathlib import Path

import pytest

from tools.check_registries import load_audio, scan_calls
from tools.generate_placeholder_audio import TONES, recording

ROOT = Path(__file__).resolve().parents[2]


def test_shipped_audio_is_source_attributed_and_reproducible():
    cues, errors = load_audio(ROOT)
    assert errors == []
    assert set(cues) == set(TONES)
    assert "CC0-1.0" in (ROOT / "game/assets/audio/p1/NOTICE.md").read_text()
    for cue, params in TONES.items():
        assert (ROOT / f"game/assets/audio/p1/{cue}.wav").read_bytes() == recording(*params)


@pytest.fixture
def root(tmp_path):
    for folder in ("game/services/audio", "game/data/audio", "game/assets/audio/p1"):
        shutil.copytree(ROOT / folder, tmp_path / folder)
    return tmp_path


@pytest.mark.parametrize("problem", ["unknown_field", "missing_asset", "bad_wav", "missing_schema"])
def test_broken_audio_fails_closed(root, problem):
    path = root / "game/data/audio/cues.json"
    data = json.loads(path.read_bytes())
    if problem == "unknown_field":
        data["cues"]["tile_touch"]["unknown"] = True
        path.write_text(json.dumps(data))
    elif problem == "missing_asset":
        (root / "game/assets/audio/p1/tile_touch.wav").unlink()
    elif problem == "bad_wav":
        (root / "game/assets/audio/p1/tile_touch.wav").write_bytes(b"broken")
    else:
        (root / "game/services/audio/registry.schema.json").unlink()
    assert load_audio(root)[1]


def test_literal_audio_calls_are_registered_and_dynamic_calls_are_counted(root):
    source = root / "game/features/probe.gd"
    source.parent.mkdir(parents=True)
    source.write_text('extends Node\nfunc run():\n\tAudio.play(&"typo")\n\tAudio.play(variable)\n')
    cues, _ = load_audio(root)
    errors, dynamic = scan_calls(root, {}, {}, cues)
    assert len(errors) == 1 and "unregistered Audio.play" in errors[0]
    assert dynamic == 1
    source.write_text('extends Node\nfunc run():\n\tAudio.play(&"tile_touch")\n')
    assert scan_calls(root, {}, {}, cues) == ([], 0)
