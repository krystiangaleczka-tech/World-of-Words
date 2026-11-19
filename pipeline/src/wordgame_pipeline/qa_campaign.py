"""Build an isolated, source-pinned Polish campaign for editorial QA."""

import argparse
import csv
import hashlib
import shutil
import tempfile
from collections import Counter, defaultdict, deque
from dataclasses import dataclass, field
from pathlib import Path

from . import __version__
from .candidates.core import WordIndex
from .config import canonical_bytes, load_config, parse_json
from .content import bundle, provenance, validate_content
from .content_limits import pack_filename
from .dedupe.core import CROSSWORD_SPACING
from .grid import make_level
from .grid.builder import SearchOptions, build_grid
from .grid.geometry import Placement, validate_geometry
from .stages import read_artifact, select_stages
from .validate import SchemaRegistry, validate_level
from .validate.locks import load_release_lock, verify_release_lock

SHIPPED_SLOTS = 65
AUTHORED_SLOTS = 200
CAMPAIGN_SLOTS = 10_000
PACK_SIZE = 100
WHEEL_PATTERN = (5, 6, 6, 7, 6)
ANSWER_PATTERN = (3, 3, 4, 5, 4)
PROPOSAL_BLOB = "24d68444cbf0bbedc1b1dc04eedf5f0f19e6eb12"
SOURCE = {
    "id": "sjp-pl-game",
    "version": "20261101",
    "url": "https://sjp.pl/sl/growy/sjp-20261101.zip",
    "sha256": "cc7c98e4c02f4c8aa1d20cc5f6625e66f02f968a02d9c32e52e029173b41f23a",
    "archive_bytes": 8517270,
    "member": "slowa.txt",
    "member_bytes": 45657324,
    "entry_count": 3246040,
    "encoding": "utf-8",
    "license": "CC-BY-4.0",
    "license_url": "https://creativecommons.org/licenses/by/4.0/",
    "source_url": "https://sjp.pl/sl/growy/",
}


@dataclass(frozen=True)
class Wheel:
    letters: str
    seeds: tuple[str, ...]
    answers: tuple[str, ...]


@dataclass
class History:
    wheels: set[str] = field(default_factory=set)
    answer_sets: set[frozenset[str]] = field(default_factory=set)
    last_slot: dict[str, int] = field(default_factory=dict)

    def available(self, word: str, slot: int) -> bool:
        return slot - self.last_slot.get(word, -CROSSWORD_SPACING) >= CROSSWORD_SPACING

    def record(self, level: dict) -> None:
        slot = level["slot"]
        signature = "".join(sorted(level["letters"]))
        words = frozenset(p["w"] for p in level["words"])
        if slot != len(self.wheels) + 1 or signature in self.wheels:
            raise ValueError(f"Non-contiguous slot or repeated wheel at {slot}")
        if words in self.answer_sets or not all(self.available(word, slot) for word in words):
            raise ValueError(f"Repeated answer set or spacing conflict at {slot}")
        self.wheels.add(signature)
        self.answer_sets.add(words)
        self.last_slot.update(dict.fromkeys(words, slot))


def seed_for(signature: str) -> int:
    return int.from_bytes(hashlib.sha256(signature.encode()).digest()[:8], "big")


def stage_sources(repo_pipeline: Path, target: Path) -> None:
    target.mkdir(parents=True)
    for directory in ("config", "overrides"):
        shutil.copytree(repo_pipeline / directory, target / directory)
    sources = target / "sources"
    sources.mkdir()
    shutil.copyfile(repo_pipeline / "sources/annotation-pl.json", sources / "annotation-pl.json")
    (sources / "sjp-pl.json").write_bytes(canonical_bytes(SOURCE))


def prepare_indexes(staged: Path) -> tuple[WordIndex, WordIndex, dict, str]:
    config = load_config(staged, "pl")
    payload, raw = read_artifact(staged, config, select_stages("tiers", "tiers")[0])
    expected = provenance(staged, config)
    if payload.get("source") != SOURCE or any(
        payload.get(key) != value for key, value in expected.items() if key != "config_sha256"
    ):
        raise ValueError("Candidate build requires the pinned full November tier evidence")
    records = payload["records"]
    level_records = [r for r in records if r["tier"] == "level_ok"]
    lead = WordIndex(level_records, config)
    notes = {r["word"]: r["tier_reason"] for r in level_records}
    return lead, WordIndex(records, config), notes, hashlib.sha256(raw).hexdigest()


def inventory(lead: WordIndex, used: set[str]) -> dict[int, deque[Wheel]]:
    result: dict[int, deque[Wheel]] = {size: deque() for size in range(4, 8)}
    for letters in sorted(lead.index, key=lambda key: (seed_for(key), key)):
        if len(letters) not in result or letters in used:
            continue
        answers = lead.pools(list(letters))["level_ok"]
        if len(answers) >= 2:
            result[len(letters)].append(Wheel(letters, tuple(lead.index[letters]), tuple(answers)))
    return result


def next_layout(
    queues: dict[int, deque[Wheel]], history: History, slot: int
) -> tuple[str, tuple[Placement, ...]]:
    phase = (slot - AUTHORED_SLOTS - 1) % len(WHEEL_PATTERN)
    size_preference = WHEEL_PATTERN[phase]
    options = SearchOptions(
        restarts=1, nodes=12, branches=2, considered=8, selected=ANSWER_PATTERN[phase]
    )
    for size in sorted(queues, key=lambda n: (abs(n - size_preference), n)):
        queue = queues[size]
        for _ in range(len(queue)):
            wheel = queue.popleft()
            words = tuple(word for word in wheel.answers if history.available(word, slot))
            seed = next((word for word in wheel.seeds if history.available(word, slot)), None)
            if seed is not None and len(words) >= 2:
                layout = build_grid(words, seed, seed_for(wheel.letters), options)
                selected = frozenset(p[0] for p in layout)
                if len(selected) >= 2 and selected not in history.answer_sets:
                    return wheel.letters, layout
            queue.append(wheel)
    raise ValueError(f"No unused wheel with a spacing-safe crossword at slot {slot}")


def full_bonus(index: WordIndex, letters: list[str], words: list[str]) -> list[str]:
    pools = index.pools(letters)
    return sorted((set(pools["level_ok"]) | set(pools["bonus_ok"])) - set(words))


def as_level(
    slot: int, letters: list[str], grid: dict, placements: list[dict], bonus: list[str], seed: int
) -> dict:
    return {
        "id": f"pl-c-{slot:06d}",
        "slot": slot,
        "letters": letters,
        "words": placements,
        "bonus": bonus,
        "grid": grid,
        "difficulty": 0.0,
        "landmark": False,
        "source": "generated",
        "seed": seed,
        "pipeline": __version__,
    }


def authored_levels(proposals: Path, index: WordIndex) -> list[dict]:
    raw = proposals.read_bytes()
    blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
    if blob != PROPOSAL_BLOB:
        raise ValueError("Unexpected bytes for the 66 through 200 proposal")
    document = parse_json(raw.decode("utf-8"))
    entries = document["levels"]
    if [entry["slot"] for entry in entries] != list(range(SHIPPED_SLOTS + 1, AUTHORED_SLOTS + 1)):
        raise ValueError("The authored draft must cover slots 66 through 200")
    levels = []
    for entry in entries:
        letters, words = entry["letters"], entry["words"]
        payload = {**entry, "bonus": full_bonus(index, letters, words)}
        native = make_level(payload, index.config, handmade=True)
        levels.append(
            as_level(
                entry["slot"],
                letters,
                native["grid"],
                native["placements"],
                native["bonus"],
                native["seed"],
            )
        )
    return levels


def write_packs(
    output: Path, baseline: Path, manifest: dict, levels: list[dict], registry: SchemaRegistry
) -> tuple[int, str]:
    root = output / "content" / "pl"
    (root / "packs").mkdir(parents=True)
    packs = list(manifest["packs"])
    for entry in packs:
        shutil.copyfile(baseline / entry["file"], root / entry["file"])
    for offset in range(SHIPPED_SLOTS, len(levels), PACK_SIZE):
        group = levels[offset : offset + PACK_SIZE]
        first, last = offset + 1, offset + len(group)
        name = pack_filename(first, last)
        raw = canonical_bytes(
            {"schema_version": 1, "lang": "pl", "kind": "campaign", "levels": group}
        )
        (root / name).write_bytes(raw)
        packs.append(
            {
                "file": name,
                "kind": "campaign",
                "first": first,
                "last": last,
                "sha256": hashlib.sha256(raw).hexdigest(),
            }
        )
    updated = {
        **manifest,
        "slots": len(levels),
        "packs": packs,
        "content_version": manifest["content_version"] + 1,
    }
    (root / "manifest.json").write_bytes(canonical_bytes(updated))
    verified, raw_manifest = bundle(root, registry)
    if verified != levels:
        raise ValueError("Read-back disagrees with the built campaign")
    for entry in manifest["packs"]:
        if (root / entry["file"]).read_bytes() != (baseline / entry["file"]).read_bytes():
            raise ValueError("The first campaign pack failed the byte-preservation check")
    lock = load_release_lock(registry.root, "pl")
    if lock is not None:
        verify_release_lock(lock, verified)
    return len(packs), hashlib.sha256(raw_manifest).hexdigest()


def write_review(output: Path, levels: list[dict], notes: dict) -> None:
    use: dict[str, list[int]] = defaultdict(list)
    with (output / "levels.csv").open("w", encoding="utf-8", newline="") as file:
        rows = csv.writer(file)
        rows.writerow(
            ["slot", "wheel", "answers", "grid_width", "grid_height", "bonus_count", "review"]
        )
        for level in levels:
            slot = level["slot"]
            words = [p["w"] for p in level["words"]]
            if slot > SHIPPED_SLOTS:
                for word in words:
                    use[word].append(slot)
            rows.writerow(
                [
                    slot,
                    "".join(level["letters"]),
                    " ".join(words),
                    level["grid"]["w"],
                    level["grid"]["h"],
                    len(level["bonus"]),
                    "pending" if slot > SHIPPED_SLOTS else "existing",
                ]
            )
    with (output / "word-review.csv").open("w", encoding="utf-8", newline="") as file:
        rows = csv.writer(file)
        rows.writerow(["word", "rule_reason", "slots", "review_status", "decision", "note"])
        for word, slots in sorted(use.items()):
            rows.writerow([word, notes[word], " ".join(map(str, slots)), "pending", "", ""])


def build(staged: Path, proposals: Path, output: Path) -> dict:
    repo = Path.cwd()
    pipeline = repo / "pipeline"
    baseline = repo / "game/content/pl"
    registry = SchemaRegistry(pipeline)
    levels, raw = bundle(baseline, registry)
    if len(levels) != SHIPPED_SLOTS:
        raise ValueError("Expected the pinned 65-level baseline")
    validate_content(pipeline, load_config(pipeline, "pl"), baseline.parent)
    manifest = parse_json(raw.decode("utf-8"))
    lead, index, notes, tiers_hash = prepare_indexes(staged)
    history = History()
    for level in levels:
        history.record(level)
    for level in authored_levels(proposals, index):
        validate_level(level, index, registry)
        history.record(level)
        levels.append(level)
    queues = inventory(lead, history.wheels)
    starting_supply = {str(size): len(queue) for size, queue in queues.items()}
    print(f"Eligible unused wheel supply: {starting_supply}", flush=True)
    for slot in range(AUTHORED_SLOTS + 1, CAMPAIGN_SLOTS + 1):
        signature, layout = next_layout(queues, history, slot)
        letters, words = list(signature), [p[0] for p in layout]
        geometry = validate_geometry(layout, tuple(words))
        placements = [{"w": word, "x": x, "y": y, "dir": d} for word, x, y, d in layout]
        level = as_level(
            slot,
            letters,
            geometry,
            placements,
            full_bonus(index, letters, words),
            seed_for(signature),
        )
        validate_level(level, index, registry)
        history.record(level)
        levels.append(level)
        if slot % 500 == 0:
            print(f"Validated {slot:,} of {CAMPAIGN_SLOTS:,} slots", flush=True)
    if output.exists() or output.is_symlink():
        raise ValueError("Choose a new directory for the QA artifact")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".wow-campaign-", dir=output.parent) as name:
        result = Path(name) / "preview"
        pack_count, manifest_hash = write_packs(result, baseline, manifest, levels, registry)
        write_review(result, levels, notes)
        generated = levels[SHIPPED_SLOTS:]
        report = {
            "status": "pending_editorial_review",
            "slots": len(levels),
            "preserved_slots": SHIPPED_SLOTS,
            "authored_proposals": AUTHORED_SLOTS - SHIPPED_SLOTS,
            "generated_after_proposals": CAMPAIGN_SLOTS - AUTHORED_SLOTS,
            "packs": pack_count,
            "manifest_sha256": manifest_hash,
            "source": SOURCE,
            "tiers_sha256": tiers_hash,
            "proposal_blob": PROPOSAL_BLOB,
            "min_answer_gap": CROSSWORD_SPACING,
            "unique_wheels": len(history.wheels),
            "unique_answer_sets": len(history.answer_sets),
            "candidate_supply_by_wheel_size": starting_supply,
            "appended_answer_counts": dict(
                Counter(str(len(level["words"])) for level in generated)
            ),
        }
        (result / "report.json").write_bytes(canonical_bytes(report))
        (result / "README.md").write_text(
            "# Polish campaign QA draft\n\n"
            "Open levels.csv for slot evidence and word-review.csv for editorial review. "
            "The first 65 levels retain their shipped bytes and bonus evidence. "
            "The appended levels use the November SJP archive, SGJP and KWJP rules. "
            "Difficulty calibration and editorial review are pending. "
            "Use this content for internal testing.\n\n"
            "SJP.PL Słownik do gier, 2026-11-01, CC BY 4.0. "
            "The list was normalized, tiered and used to generate puzzles. "
            "See the repository NOTICE for SGJP and KWJP attribution.\n\n"
            "https://sjp.pl/sl/growy/ · https://creativecommons.org/licenses/by/4.0/\n",
            encoding="utf-8",
        )
        shutil.copyfile(repo / "NOTICE", result / "NOTICE")
        result.rename(output)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    source = commands.add_parser("prepare")
    source.add_argument("staging", type=Path)
    generate = commands.add_parser("build")
    generate.add_argument("staging", type=Path)
    generate.add_argument("proposals", type=Path)
    generate.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.command == "prepare":
        stage_sources(Path("pipeline"), args.staging)
    else:
        report = build(args.staging, args.proposals, args.output)
        print(canonical_bytes(report).decode("utf-8"), end="")


if __name__ == "__main__":
    main()
