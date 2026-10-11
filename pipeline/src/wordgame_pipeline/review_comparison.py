"""Validate draft judgments and report changes without applying or authenticating them."""

import copy
from dataclasses import asdict
from pathlib import Path

from .candidates.core import WordIndex
from .config import load_config
from .content import digest
from .familiarity import load_catalog
from .familiarity_report import build_report, early_issues
from .p1 import read_json


def compare_reviews(root: Path, content: Path, baseline_path: Path, candidate_path: Path) -> dict:
    """Compare declared per-word annotations after source/content validation."""
    baseline = build_report(root, content, baseline_path)
    receipt = read_json(root / "content-inputs/pl.json")
    index = WordIndex(receipt["records"], load_config(root, "pl"))
    candidate = load_catalog(candidate_path, index.tiers)
    original = {
        review["word"]: review for level in baseline["levels"] for review in level["required"]
    }
    if set(candidate) != set(original):
        missing = sorted(set(original) - set(candidate))
        extra = sorted(set(candidate) - set(original))
        raise ValueError(
            f"candidate required-word coverage differs: missing={missing}, extra={extra}"
        )
    coverage = {"missing": 0, "proposed": 0, "reviewed": 0}
    changes: list[dict] = []
    for word, review in sorted(candidate.items()):
        after = asdict(review)
        coverage[review.status] += 1
        if original[word] != after:
            changes.append({"word": word, "before": original[word], "after": after})
    inspected = copy.deepcopy(baseline)
    for level in inspected["levels"]:
        level["required"] = [asdict(candidate[review["word"]]) for review in level["required"]]
    return {
        "schema_version": 1,
        "inputs": {
            "baseline_sha256": baseline["inputs"]["catalog_sha256"],
            "candidate_sha256": digest(candidate_path.read_bytes()),
            "tiers_sha256": baseline["inputs"]["tiers_sha256"],
            "packs": baseline["inputs"]["packs"],
        },
        "coverage": coverage,
        "changes": changes,
        "early_check": {"slots": 15, "max_band": 2, "issues": early_issues(inspected)},
    }
