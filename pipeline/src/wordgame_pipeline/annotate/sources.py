"""Verified KWJP source pins/cache, independent of optional native morphology."""

import hashlib
import re
import urllib.request
from collections.abc import Callable
from pathlib import Path

from ..config import parse_json
from ..stages import _write_atomic
from .frequency import Frequency, parse_frequency


def _matches(value: object, pattern: str) -> bool:
    return isinstance(value, str) and re.fullmatch(pattern, value) is not None


def load_pin(root: Path) -> dict[str, object]:
    pin = parse_json((root / "sources" / "annotation-pl.json").read_text(encoding="utf-8"))
    if not isinstance(pin, dict) or set(pin) != {"morphology", "frequency"}:
        raise ValueError("Invalid annotation source pin")
    morphology, frequency = pin["morphology"], pin["frequency"]
    if not isinstance(morphology, dict) or not isinstance(frequency, dict):
        raise ValueError("Invalid annotation source metadata")
    if set(morphology) != {
        "package",
        "version",
        "dictionary_id",
        "dictionary_date",
        "linux_wheel_sha256",
        "license",
        "source_url",
    } or set(frequency) != {"repository", "commit", "license", "license_url", "files"}:
        raise ValueError("Incomplete annotation source metadata")
    if morphology.get("package") != "morfeusz2" or morphology.get("license") != "BSD-2-Clause":
        raise ValueError("Morphology must use the selected Morfeusz SGJP source")
    if not _matches(morphology["version"], r"[0-9]+\.[0-9]+\.[0-9]+"):
        raise ValueError("Invalid Morfeusz version")
    if not _matches(morphology["dictionary_date"], r"[0-9]{4}-[0-9]{2}-[0-9]{2}"):
        raise ValueError("Invalid SGJP dictionary date")
    if morphology["dictionary_id"] != "pl.sgjp.sgjp-" + morphology["dictionary_date"].replace(
        "-", "."
    ):
        raise ValueError("SGJP dictionary identity/date mismatch")
    if morphology["source_url"] != "https://morfeusz.sgjp.pl/":
        raise ValueError("Unselected morphology source")
    if not _matches(morphology["linux_wheel_sha256"], r"[0-9a-f]{64}"):
        raise ValueError("Invalid Morfeusz wheel hash")
    if frequency.get("repository") != "https://github.com/ipipan/kwjp100-varia":
        raise ValueError("Unselected frequency repository")
    if not _matches(frequency.get("commit"), r"[0-9a-f]{40}"):
        raise ValueError("KWJP requires a full commit SHA")
    if (
        frequency.get("license") != "CC-BY-4.0"
        or frequency["license_url"] != "https://creativecommons.org/licenses/by/4.0/"
    ):
        raise ValueError("KWJP must preserve CC BY 4.0 provenance")
    files = frequency.get("files")
    if not isinstance(files, dict) or set(files) != {"orth", "lemma"}:
        raise ValueError("Both KWJP source files must be pinned")
    for kind, entry in files.items():
        name = "orth_lc" if kind == "orth" else "lemma"
        if not isinstance(entry, dict) or entry.get("file") != f"kwjp100-slowa-{name}-all.csv.gz":
            raise ValueError("Unselected KWJP frequency file")
        if set(entry) != {"file", "bytes", "sha256"}:
            raise ValueError("Invalid KWJP file pin fields")
        if type(entry.get("bytes")) is not int or entry["bytes"] <= 0:
            raise ValueError("Invalid KWJP source size")
        if not _matches(entry.get("sha256"), r"[0-9a-f]{64}"):
            raise ValueError("Invalid KWJP source hash")
    return pin


def verify_engine(analyzer: object, pin: dict[str, object]) -> None:
    expected = pin["morphology"]
    if (
        getattr(analyzer, "version", None) != expected["version"]
        or getattr(analyzer, "dictionary_id", None) != expected["dictionary_id"]
    ):
        raise ValueError("Morfeusz engine/dictionary identity mismatch")


def load_frequency(
    root: Path, pin: dict[str, object], kind: str, fetcher: Callable[[str], bytes] | None = None
) -> dict[str | tuple[str, str], Frequency]:
    source = pin["frequency"]
    entry = source["files"][kind]
    path = root / "build" / "pl" / "sources" / f"kwjp-{entry['sha256']}.csv.gz"
    cached = path.exists()
    if cached:
        raw = path.read_bytes()
    else:
        url = (
            "https://raw.githubusercontent.com/ipipan/kwjp100-varia/"
            f"{source['commit']}/freqlists/{entry['file']}"
        )
        if fetcher is not None:
            raw = fetcher(url)
        else:
            with urllib.request.urlopen(url, timeout=30) as response:
                raw = response.read(entry["bytes"] + 1)
    if len(raw) != entry["bytes"] or hashlib.sha256(raw).hexdigest() != entry["sha256"]:
        raise ValueError("KWJP source size/SHA256 mismatch")
    result = parse_frequency(raw, kind)
    if not cached:
        _write_atomic(path, raw)
    return result
