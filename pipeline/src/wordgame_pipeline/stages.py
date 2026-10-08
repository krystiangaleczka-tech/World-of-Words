"""Canonical stage selection and versioned, atomic intermediate artifacts."""

import hashlib
import os
import re
import tempfile
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path

from . import __version__
from .config import LanguageConfig, canonical_bytes, parse_json


@dataclass(frozen=True)
class Stage:
    number: int
    name: str
    p1: bool

    @property
    def directory(self) -> str:
        return f"{self.number:02d}-{self.name}"


STAGES = tuple(
    Stage(number, name, number in {1, 2, 3, 5, 6, 7, 9, 13})
    for number, name in enumerate(
        (
            "ingest",
            "normalize",
            "annotate",
            "classify",
            "tiers",
            "candidates",
            "grid",
            "scoring",
            "validate",
            "dedupe",
            "sequence",
            "qa",
            "export",
        ),
        start=1,
    )
)
P1_STAGES = tuple(stage for stage in STAGES if stage.p1)
StageHandler = Callable[[LanguageConfig, object], object]


def select_stages(first: str = "ingest", last: str = "export") -> tuple[Stage, ...]:
    def find(value: str) -> Stage:
        for stage in STAGES:
            if value in (stage.name, str(stage.number), f"{stage.number:02d}"):
                if not stage.p1:
                    raise ValueError(f"Stage {stage.name} is unavailable in P1")
                return stage
        raise ValueError(f"Unknown stage: {value}")

    start, end = find(first), find(last)
    if start.number > end.number:
        raise ValueError("--from must not follow --to")
    return tuple(stage for stage in P1_STAGES if start.number <= stage.number <= end.number)


def artifact_path(root: Path, lang: str, stage: Stage) -> Path:
    if lang != "pl" or stage not in P1_STAGES:
        raise ValueError("Unsupported artifact language/stage")
    return root / "build" / lang / stage.directory / "artifact.json"


def _digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_artifact(root: Path, config: LanguageConfig, stage: Stage) -> tuple[object, bytes]:
    raw = artifact_path(root, config.lang, stage).read_bytes()
    data = parse_json(raw.decode("utf-8"))
    expected = {
        "schema_version": 1,
        "pipeline_version": __version__,
        "lang": config.lang,
        "stage": stage.directory,
        "config_sha256": _digest(canonical_bytes(config.to_dict())),
    }
    if not isinstance(data, dict) or set(data) != set(expected) | {"input_sha256", "payload"}:
        raise ValueError("Invalid stage artifact envelope")
    if type(data["schema_version"]) is not int or any(
        data[key] != value for key, value in expected.items()
    ):
        raise ValueError("Artifact identity, config or version mismatch")
    input_hash = data["input_sha256"]
    if stage.number == 1:
        if input_hash is not None:
            raise ValueError("Ingest artifact must have null input_sha256")
    elif not isinstance(input_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", input_hash):
        raise ValueError("Invalid predecessor hash")
    if canonical_bytes(data) != raw:
        raise ValueError("Artifact is not canonical UTF-8 JSON")
    return data["payload"], raw


def _write_atomic(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def run_build(
    root: Path,
    config: LanguageConfig,
    handlers: Mapping[str, StageHandler],
    first: str = "ingest",
    last: str = "export",
) -> tuple[Path, ...]:
    selected = select_stages(first, last)
    for stage in selected:
        if stage.name not in handlers:
            raise ValueError(f"Stage {stage.name} is not implemented yet")
    payload: object = None
    previous: bytes | None = None
    prior_index = P1_STAGES.index(selected[0]) - 1
    if prior_index >= 0:
        payload, previous = read_artifact(root, config, P1_STAGES[prior_index])
    paths: list[Path] = []
    for stage in selected:
        payload = handlers[stage.name](config, payload)
        envelope = {
            "schema_version": 1,
            "pipeline_version": __version__,
            "lang": config.lang,
            "stage": stage.directory,
            "config_sha256": _digest(canonical_bytes(config.to_dict())),
            "input_sha256": _digest(previous) if previous is not None else None,
            "payload": payload,
        }
        previous = canonical_bytes(envelope)
        path = artifact_path(root, config.lang, stage)
        _write_atomic(path, previous)
        paths.append(path)
    return tuple(paths)
