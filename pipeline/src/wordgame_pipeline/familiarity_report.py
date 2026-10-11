"""Report source-backed required-answer familiarity without inferring approval."""

import argparse
import sys
from pathlib import Path

from .candidates.core import WordIndex
from .config import canonical_bytes, load_config
from .content import digest
from .familiarity import load_catalog
from .p1 import check, read_json


def build_report(root: Path, content: Path, catalog_path: Path) -> dict:
    """Replay committed content before joining required answers with review data."""
    check(root, content)
    receipt = read_json(root / "content-inputs/pl.json")
    index = WordIndex(receipt["records"], load_config(root, "pl"))
    catalog = load_catalog(catalog_path, index.tiers)
    manifest = read_json(content / "pl/manifest.json")
    packs: dict[str, str] = {}
    levels: list[dict] = []
    for entry in manifest["packs"]:
        filename = entry["file"]
        path = content / "pl" / filename
        packs[filename] = digest(path.read_bytes())
        levels.extend(read_json(path)["levels"])
    coverage = {"missing": 0, "proposed": 0, "reviewed": 0}
    seen: set[str] = set()
    rows: list[dict] = []
    for level in sorted(levels, key=lambda value: value["slot"]):
        required: list[dict] = []
        for placement in level["words"]:
            word = placement["w"]
            review = catalog.get(word)
            annotation = {
                "word": word,
                "band": review.band if review else None,
                "status": review.status if review else "missing",
                "reviewer": review.reviewer if review else "",
                "rationale": review.rationale if review else "",
            }
            required.append(annotation)
            if word not in seen:
                coverage[annotation["status"]] += 1
                seen.add(word)
        rows.append({"slot": level["slot"], "id": level["id"], "required": required})
    return {
        "schema_version": 1,
        "language": "pl",
        "content_version": manifest["content_version"],
        "inputs": {
            "catalog_sha256": digest(catalog_path.read_bytes()),
            "tiers_sha256": receipt["tiers_sha256"],
            "packs": packs,
        },
        "coverage": coverage,
        "levels": rows,
    }


def early_issues(report: dict, slots: int = 15, max_band: int = 2) -> list[dict]:
    """List unresolved/hard required answers in the requested opening scope."""
    if type(slots) is not int or not 1 <= slots <= len(report["levels"]):
        raise ValueError("early slots must be an integer in 1..level count")
    if type(max_band) is not int or not 1 <= max_band <= 5:
        raise ValueError("maximum band must be an integer in 1..5")
    issues: list[dict] = []
    for level in report["levels"][:slots]:
        for review in level["required"]:
            status, band = review["status"], review["band"]
            reason: str
            if status == "missing":
                reason = "missing"
            elif status == "proposed":
                reason = "proposed"
            elif status != "reviewed":
                raise ValueError(f"unknown review status: {status!r}")
            elif type(band) is not int or not 1 <= band <= 5:
                reason = "unknown_band"
            elif band > max_band:
                reason = "above_max_band"
            else:
                continue
            issues.append(
                {"slot": level["slot"], "id": level["id"], "word": review["word"], "reason": reason}
            )
    return issues


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("pipeline"))
    parser.add_argument("--content-root", type=Path, default=Path("game/content"))
    parser.add_argument("--catalog", type=Path)
    parser.add_argument("--check-early", action="store_true")
    parser.add_argument("--early-slots", type=int)
    parser.add_argument("--max-band", type=int)
    args = parser.parse_args(argv)
    catalog_path = args.catalog or args.root / "reviews/pl/familiarity.csv"
    exit_code = 0
    try:
        if not args.check_early and (args.early_slots is not None or args.max_band is not None):
            raise ValueError("--early-slots and --max-band require --check-early")
        report = build_report(args.root, args.content_root, catalog_path)
        if args.check_early:
            slots = args.early_slots if args.early_slots is not None else 15
            max_band = args.max_band if args.max_band is not None else 2
            issues = early_issues(report, slots, max_band)
            report["early_check"] = {"slots": slots, "max_band": max_band, "issues": issues}
            exit_code = int(bool(issues))
    except (ValueError, OSError, KeyError) as error:
        print(f"Familiarity report: {error}", file=sys.stderr)
        return 1
    sys.stdout.write(canonical_bytes(report).decode("utf-8"))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
