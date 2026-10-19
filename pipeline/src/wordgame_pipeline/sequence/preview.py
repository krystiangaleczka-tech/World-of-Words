"""Readonly planning report; input declarations do not certify publication."""

import argparse
import hashlib
import re
import sys
from dataclasses import asdict
from pathlib import Path

from ..config import canonical_bytes, load_config, parse_json
from ..dedupe import DuplicatePolicy
from ..scoring.features import extract_features
from ..scoring.model import ScoringConfig, score_features
from ..validate.schema import SchemaRegistry, json_value
from .allocate import AllocationError, ScoredCandidate, allocate
from .curve import CurveConfig
from .slots import Location, Region, Reservation, SlotPlan

ROOT = Path(__file__).resolve().parents[3]


def _object(value: object, fields: str) -> dict:
    if not isinstance(value, dict) or set(value) != set(fields.split()):
        raise ValueError(f"Expected exact object fields: {fields}")
    return value


def _array(value: object) -> list:
    if not isinstance(value, list):
        raise ValueError("Expected JSON array")
    return value


def _digest(value: object) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def _plan(value: object) -> SlotPlan:
    data = _object(value, "regions locations authored released")
    regions = []
    for item in _array(data["regions"]):
        item = _object(item, "id curve")
        regions.append(Region(item["id"], CurveConfig.from_dict(item["curve"])))
    locations = tuple(
        Location(**_object(item, "id region first last")) for item in _array(data["locations"])
    )
    reservations = {
        key: tuple(Reservation(**_object(item, "slot candidate_id")) for item in _array(data[key]))
        for key in ("authored", "released")
    }
    return SlotPlan(tuple(regions), locations, **reservations)


def preview(data: object) -> dict:
    json_value(data)
    data = _object(data, "schema_version language scoring duplicate_policy plan candidates")
    if type(data["schema_version"]) is not int or data["schema_version"] != 1:
        raise ValueError("Expected preview schema_version1")
    if data["language"] != "pl":
        raise ValueError("Preview supports language pl only")
    language, registry = load_config(ROOT, "pl"), SchemaRegistry(ROOT)
    scoring, plan = ScoringConfig.from_dict(data["scoring"]), _plan(data["plan"])
    policy = DuplicatePolicy(**_object(data["duplicate_policy"], "jaccard_threshold seed_spacing"))
    fixed = {r.candidate_id: r.slot for r in (*plan.authored, *plan.released)}
    pool, evidence = [], []
    for item in _array(data["candidates"]):
        item = _object(item, "id level frequencies seed_word")
        level = item["level"]
        registry.validate_schema("level", level)
        if (
            item["id"] != level["id"]
            or not re.fullmatch(r"pl-c-[0-9]{6}", level["id"])
            or type(level.get("slot")) is not int
            or level["slot"] != int(level["id"][-6:])
            or (item["id"] in fixed and level["slot"] != fixed[item["id"]])
        ):
            raise ValueError("Candidate/source campaign identity or reserved slot mismatch")
        score = score_features(extract_features(level, item["frequencies"], language), scoring)
        pool.append(
            ScoredCandidate(
                item["id"],
                tuple(level["letters"]),
                tuple(p["w"] for p in level["words"]),
                item["seed_word"],
                score.total,
                level["source"] == "handmade",
                level["landmark"],
            )
        )
        evidence.append(dict(id=item["id"], source_sha256=_digest(level), score=asdict(score)))
    report = dict(
        schema_version=1,
        scope="planning-preview",
        unverified=[
            "released_geometry",
            "tier_bonus_source_approval",
            "seed_provenance",
            "production_calibration",
        ],
        request_sha256=_digest(data),
        language_config_sha256=_digest(language.to_dict()),
        level_schema_sha256=hashlib.sha256(registry.raw["level"]).hexdigest(),
        scoring_config_sha256=_digest(scoring.to_dict()),
        candidates=sorted(evidence, key=lambda e: e["id"]),
        assignments=[],
        unused=[],
    )
    try:
        result = allocate(plan, pool, policy, language)
    except AllocationError as exc:
        report.update(
            status="blocked",
            failure=dict(
                code=exc.code,
                slot=exc.slot,
                blocked=[asdict(r) for r in exc.blocked],
                conflicts=[asdict(c) for c in exc.conflicts],
            ),
        )
    else:
        report.update(
            status="ok",
            assignments=[
                dict(
                    **asdict(a.requirement),
                    candidate_id=a.candidate.id,
                    difficulty=a.candidate.difficulty,
                    mode=a.mode,
                    deviation=a.deviation,
                    rejected=[asdict(r) for r in a.rejected],
                )
                for a in result.assignments
            ],
            unused=list(result.unused),
        )
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    args = parser.parse_args(argv)
    try:
        report = preview(parse_json(args.input.read_text(encoding="utf-8")))
        output = canonical_bytes(report).decode("utf-8")
    except (OSError, ValueError) as exc:
        print(f"Invalid preview: {exc}", file=sys.stderr)
        return 1
    print(output, end="")
    return 0 if report["status"] == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())
