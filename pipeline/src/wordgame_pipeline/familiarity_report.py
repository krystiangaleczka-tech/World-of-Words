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


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("pipeline"))
    parser.add_argument("--content-root", type=Path, default=Path("game/content"))
    parser.add_argument("--catalog", type=Path)
    args = parser.parse_args(argv)
    catalog_path = args.catalog or args.root / "reviews/pl/familiarity.csv"
    try:
        report = build_report(args.root, args.content_root, catalog_path)
    except (ValueError, OSError, KeyError) as error:
        print(f"Familiarity report: {error}", file=sys.stderr)
        return 1
    sys.stdout.write(canonical_bytes(report).decode("utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
