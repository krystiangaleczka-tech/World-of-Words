"""Planning fixtures copy shipped words; no generated fixture is published."""

import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import pytest
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.scoring.features import FEATURE_NAMES
from wordgame_pipeline.sequence.curve import CurveConfig
from wordgame_pipeline.sequence.preview import preview

ROOT = Path(__file__).resolve().parents[2]
PACK = next((ROOT.parent / "game/content/pl/packs").glob("*.json"))


def request(total=17):
    levels = json.loads(PACK.read_bytes())["levels"][:20]
    entries = []
    for level in levels:
        # Test-only metadata and explicit fixture seed, not production authorship evidence.
        if level["slot"] > 15:
            level["source"] = "generated"
        entries.append(
            dict(
                id=level["id"],
                level=level,
                frequencies={p["w"]: None for p in level["words"]},
                seed_word=level["words"][0]["w"],
            )
        )
    reservations = [dict(slot=i, candidate_id=entries[i - 1]["id"]) for i in range(1, 16)]
    return dict(
        schema_version=1,
        language="pl",
        scoring=dict(
            schema_version=1,
            features={
                name: dict(
                    weight=int(name == "letter_count"), minimum=0, maximum=8, direction="higher"
                )
                for name in FEATURE_NAMES
            },
        ),
        duplicate_policy=dict(jaccard_threshold=1, seed_spacing=100),
        plan=dict(
            regions=[
                dict(id="r", curve=CurveConfig(1, total, 0.5, 0, 5, 0, 0.2, 0.1, ()).to_dict())
            ],
            locations=[dict(id="l", region="r", first=1, last=total)],
            authored=reservations,
            released=copy.deepcopy(reservations[:3]),
        ),
        candidates=entries,
    )


def test_fresh_scores_provenance_reservations_and_no_input_or_content_mutation():
    data, shipped = request(), PACK.read_bytes()
    before = copy.deepcopy(data)
    report = preview(data)
    assert data == before and PACK.read_bytes() == shipped
    assert report["status"] == "ok" and report["scope"] == "planning-preview"
    assert "released_geometry" in report["unverified"]
    assert "seed_provenance" in report["unverified"]
    assert report["request_sha256"] == hashlib.sha256(canonical_bytes(data)).hexdigest()
    for row, source in zip(report["candidates"], data["candidates"], strict=True):
        assert row["id"] == source["id"]
        assert row["source_sha256"] == hashlib.sha256(canonical_bytes(source["level"])).hexdigest()
        assert row["score"]["total"] == len(source["level"]["letters"]) / 8
        assert row["score"]["total"] != source["level"]["difficulty"]
        assert row["score"]["config_sha256"] == report["scoring_config_sha256"]
        assert len(row["score"]["features"]) == len(FEATURE_NAMES)
    assert [r["candidate_id"] for r in report["assignments"][:15]] == [
        c["id"] for c in data["candidates"][:15]
    ]
    assert report["assignments"][0]["mode"] == "released"
    assert report["assignments"][3]["mode"] == "authored"
    assert report["assignments"][15]["mode"] == "nearest"
    assert report["assignments"][0]["deviation"] is None
    assert all(r["region"] == "r" and r["location"] == "l" for r in report["assignments"])
    assert report["unused"] == sorted(report["unused"])


def test_deterministic_bytes_key_order_and_changed_evidence():
    data = request()
    result = canonical_bytes(preview(data))
    assert canonical_bytes(preview(data)) == result
    assert canonical_bytes(preview(json.loads(json.dumps(data, sort_keys=True)))) == result
    reordered = copy.deepcopy(data)
    reordered["candidates"].reverse()
    first, second = preview(data), preview(reordered)
    assert first["assignments"] == second["assignments"]
    assert first["candidates"] == second["candidates"]
    assert first["request_sha256"] != second["request_sha256"]
    data["candidates"][0]["level"]["difficulty"] = 123
    changed = preview(data)
    assert changed["candidates"][0]["score"] == first["candidates"][0]["score"]
    assert changed["candidates"][0]["source_sha256"] != first["candidates"][0]["source_sha256"]
    assert changed["request_sha256"] != first["request_sha256"]
    data["candidates"][0]["frequencies"][data["candidates"][0]["seed_word"]] = 0
    assert preview(data)["candidates"][0]["score"] != changed["candidates"][0]["score"]


def test_blocked_reports_have_exact_evidence_and_no_partial_assignment():
    data = request(total=16)
    first, last = data["candidates"][0], data["candidates"][15]
    last["level"].update(
        {key: copy.deepcopy(first["level"][key]) for key in ("letters", "words", "grid")}
    )
    last["frequencies"], last["seed_word"] = first["frequencies"].copy(), first["seed_word"]
    data["candidates"] = data["candidates"][:16]
    result = preview(data)
    assert result["status"] == "blocked" and result["assignments"] == result["unused"] == []
    assert result["failure"]["code"] == "greedy_blocked" and result["failure"]["slot"] == 16
    rejection = result["failure"]["blocked"][0]
    assert rejection["candidate_id"] == last["id"] and rejection["conflicts"]
    assert "word_spacing" in rejection["conflicts"][0]["reasons"]
    data["candidates"][0]["level"]["source"] = "generated"
    assert preview(data)["failure"]["code"] == "fixed_incompatible"


def test_fixed_source_slot_and_landmark_authorship():
    data = request()
    # Same identity in request and level, but wrong fixed reservation position.
    data["plan"]["authored"][0]["candidate_id"] = data["candidates"][19]["id"]
    data["plan"]["released"] = []
    with pytest.raises(ValueError, match="reserved slot mismatch"):
        preview(data)
    data = request(total=19)
    data["plan"]["regions"][0]["curve"]["landmarks"] = [18]
    data["plan"]["authored"].append(dict(slot=18, candidate_id=data["candidates"][17]["id"]))
    data["candidates"][17]["level"].update(source="handmade", landmark=True)
    assert preview(data)["assignments"][17]["curve"]["kind"] == "landmark"
    data["candidates"][17]["level"]["source"] = "generated"
    with pytest.raises(ValueError):
        preview(data)


@pytest.mark.parametrize(
    "path,value",
    [
        (("extra",), 1),
        (("schema_version",), True),
        (("language",), "en"),
        (("scoring", "extra"), 0),
        (("duplicate_policy", "seed_spacing"), 99),
        (("plan", "regions"), {}),
        (("plan", "locations", 0, "extra"), 1),
        (("plan", "authored", 0, "extra"), 1),
        (("candidates",), {}),
        (("candidates", 0, "authored"), True),
        (("candidates", 0, "id"), "pl-c-000099"),
        (("candidates", 0, "level", "id"), "pl-d-000001"),
        (("candidates", 0, "level", "slot"), 99),
        (("candidates", 0, "level", "slot"), True),
        (("candidates", 0, "level", "source"), "unknown"),
        (("candidates", 0, "level", "grid", "w"), 10),
        (("candidates", 0, "level", "words", 0, "x"), 9),
        (("candidates", 0, "frequencies"), {}),
        (("candidates", 0, "seed_word"), "BRAK"),
        (("candidates", 0, "level", "difficulty"), float("nan")),
    ],
)
def test_invalid_request_fields_values_schema_geometry_seed(path, value):
    data = request()
    target = data
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    with pytest.raises(ValueError):
        preview(data)


def test_missing_fields_duplicate_ids_and_nonjson_callers():
    data = request()
    del data["candidates"][0]["seed_word"]
    with pytest.raises(ValueError):
        preview(data)
    data = request()
    data["candidates"].append(copy.deepcopy(data["candidates"][0]))
    with pytest.raises(ValueError):
        preview(data)
    for value in (None, [], {1: "bad"}, {"cycle": None}):
        if isinstance(value, dict) and "cycle" in value:
            value["cycle"] = value
        with pytest.raises(ValueError):
            preview(value)


def cli(path, cwd):
    return subprocess.run(
        [sys.executable, "-m", "wordgame_pipeline.sequence.preview", str(path)],
        cwd=cwd,
        capture_output=True,
        check=False,
    )


def test_cli_canonical_readonly_from_unrelated_cwd_and_all_exit_statuses(tmp_path):
    path = tmp_path / "input.json"
    data = request()
    path.write_bytes(canonical_bytes(data))
    before = path.read_bytes()
    result = cli(path, tmp_path)
    assert result.returncode == 0 and not result.stderr
    assert result.stdout == canonical_bytes(preview(data))
    assert path.read_bytes() == before and list(tmp_path.iterdir()) == [path]
    data["candidates"] = data["candidates"][:15]
    path.write_bytes(canonical_bytes(data))
    result = cli(path, tmp_path)
    assert result.returncode == 2 and not result.stderr
    blocked = json.loads(result.stdout)
    assert result.stdout == canonical_bytes(blocked)
    assert blocked["failure"]["code"] == "pool_too_small" and blocked["assignments"] == []
    for invalid in ('{"schema_version":1,"schema_version":1}', '{"value":NaN}', '{"value":1e999}'):
        path.write_text(invalid)
        result = cli(path, tmp_path)
        assert result.returncode == 1 and result.stderr and not result.stdout
        assert path.read_text() == invalid
    path.unlink()
    result = cli(path, tmp_path)
    assert result.returncode == 1 and result.stderr and not result.stdout
    assert list(tmp_path.iterdir()) == []
