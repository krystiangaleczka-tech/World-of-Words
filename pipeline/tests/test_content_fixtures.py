"""The game's content fixture (T-0041) must satisfy the shared T-0040 schemas."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path

FIXTURE = Path(__file__).resolve().parents[2] / "game/tests/fixtures/content/pl"
SPEC = importlib.util.spec_from_file_location(
    "content_schema_contract", Path(__file__).with_name("test_content_schemas.py")
)
assert SPEC is not None and SPEC.loader is not None
CONTRACT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONTRACT)


def test_fixture_manifest_matches_schema() -> None:
    manifest = json.loads((FIXTURE / "manifest.json").read_text(encoding="utf-8"))
    assert CONTRACT.errors("manifest", manifest) == []


def test_fixture_packs_match_schema_and_manifest_hashes() -> None:
    manifest = json.loads((FIXTURE / "manifest.json").read_text(encoding="utf-8"))
    for entry in manifest["packs"]:
        raw = (FIXTURE / entry["file"]).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == entry["sha256"]
        pack = json.loads(raw)
        assert CONTRACT.errors("pack", pack) == []
        assert [level["slot"] for level in pack["levels"]] == list(
            range(entry["first"], entry["last"] + 1)
        )
