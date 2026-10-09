"""Executable stage boundary tests; fake handlers do not generate shipped content."""

import hashlib
import json
import shutil
import subprocess
import sys
from dataclasses import FrozenInstanceError, replace
from pathlib import Path

import pytest
from wordgame_pipeline import __version__
from wordgame_pipeline.cli import main
from wordgame_pipeline.config import canonical_bytes, load_config
from wordgame_pipeline.stages import (
    P1_STAGES,
    artifact_path,
    read_artifact,
    run_build,
    select_stages,
)

CONFIG = Path(__file__).parents[1] / "config" / "pl.yaml"


def workspace(root: Path) -> Path:
    (root / "config").mkdir(parents=True)
    shutil.copyfile(CONFIG, root / "config" / "pl.yaml")
    return root


def fake_handlers():
    return {
        stage.name: lambda config, prior, name=stage.name: [*(prior or []), name, config.alphabet]
        for stage in P1_STAGES
    }


def test_pl_config_contract_and_invalid_inputs(tmp_path):
    root = workspace(tmp_path)
    config = load_config(root, "pl")
    assert len(config.alphabet) == 32
    assert set("ĄĆĘŁŃÓŚŹŻ") <= set(config.alphabet)
    assert (config.min_length, config.max_length) == (3, 8)
    with pytest.raises(FrozenInstanceError):
        config.lang = "en"
    for language in ("../pl", "en", "PL", "pl/../../"):
        with pytest.raises(ValueError, match="Unsupported language"):
            load_config(root, language)
    path = root / "config" / "pl.yaml"
    original = config.to_dict()
    for update in (
        {"lang": "en"},
        {"alphabet": "A" * 32},
        {"alphabet": config.alphabet.lower()},
        {"alphabet": config.alphabet.replace("Ż", "X")},
        {"min_length": True},
        {"min_length": 2},
        {"max_length": 9},
        {"max_length": 3.5},
        {"extra": 1},
    ):
        path.write_text(json.dumps(original | update), encoding="utf-8")
        with pytest.raises(ValueError):
            load_config(root, "pl")
    for text in ('{"lang":"pl","lang":"pl"}', "lang: pl", "null", '{"value":NaN}'):
        path.write_text(text, encoding="utf-8")
        with pytest.raises(ValueError):
            load_config(root, "pl")


def test_stage_selection_and_read_only_cli_plan(tmp_path, capsys):
    root = workspace(tmp_path)
    assert [stage.number for stage in select_stages()] == [1, 2, 3, 5, 6, 7, 9, 13]
    assert [stage.name for stage in select_stages("03", "7")] == [
        "annotate",
        "tiers",
        "candidates",
        "grid",
    ]
    for first, last in (("unknown", "export"), ("classify", "export"), ("grid", "tiers")):
        with pytest.raises(ValueError):
            select_stages(first, last)
    args = ["build", "--lang", "pl", "--root", str(root), "--plan"]
    assert main(args) == 0
    expected = "".join(f"build/pl/{stage.directory}/artifact.json\n" for stage in P1_STAGES)
    assert capsys.readouterr().out == expected
    console = shutil.which("wg")
    assert console is not None
    for command in ([console, *args], [sys.executable, "-m", "wordgame_pipeline", *args]):
        result = subprocess.run(command, cwd=tmp_path, capture_output=True, text=True, check=False)
        assert result.returncode == 0, result.stderr
        assert result.stdout == expected
    assert not (root / "build").exists()
    assert main([*args, "--from", "classify"]) == 1
    assert "unavailable in P1" in capsys.readouterr().err
    assert not (root / "build").exists()


def test_deterministic_artifacts_and_resume(tmp_path):
    root = workspace(tmp_path / "one")
    second = workspace(tmp_path / "two")
    config = load_config(root, "pl")
    handlers = fake_handlers()
    paths = run_build(root, config, handlers)
    other_paths = run_build(second, config, handlers)
    assert [path.read_bytes() for path in paths] == [path.read_bytes() for path in other_paths]
    originals = {path: path.read_bytes() for path in paths}
    run_build(root, config, handlers, "tiers", "export")
    assert {path: path.read_bytes() for path in paths} == originals
    previous = None
    for stage in P1_STAGES:
        payload, raw = read_artifact(root, config, stage)
        data = json.loads(raw)
        assert data["pipeline_version"] == __version__
        assert data["input_sha256"] == (
            hashlib.sha256(previous).hexdigest() if previous is not None else None
        )
        assert stage.name in payload
        assert config.alphabet in payload
        assert "Ą".encode() in raw
        assert raw == canonical_bytes(data)
        previous = raw
    predecessor = paths[2]
    good = predecessor.read_bytes()
    for update in (
        {"lang": "en"},
        {"stage": "01-ingest"},
        {"schema_version": True},
        {"pipeline_version": "999"},
        {"input_sha256": "bad"},
        {"config_sha256": "0" * 64},
    ):
        predecessor.write_bytes(canonical_bytes(json.loads(good) | update))
        with pytest.raises(ValueError):
            run_build(root, config, handlers, "tiers", "export")
    predecessor.write_bytes(good + b" ")
    with pytest.raises(ValueError, match="canonical"):
        run_build(root, config, handlers, "tiers", "export")
    predecessor.write_bytes(good)
    with pytest.raises(ValueError, match="config"):
        run_build(root, replace(config, max_length=7), handlers, "tiers", "export")
    predecessor.unlink()
    with pytest.raises(FileNotFoundError):
        run_build(root, config, handlers, "tiers", "export")
    assert paths[-1].read_bytes() == originals[paths[-1]], "resume failures do not overwrite output"


def test_unimplemented_or_invalid_output_does_not_replace_artifact(tmp_path, capsys):
    root = workspace(tmp_path)
    config = load_config(root, "pl")
    with pytest.raises(ValueError, match="normalize.*not implemented"):
        run_build(root, config, {"ingest": lambda _config, _prior: []})
    assert not (root / "build").exists(), "preflight all handlers before executing any"
    assert main(["build", "--lang", "pl", "--root", str(root)]) == 1
    assert "candidates is not implemented" in capsys.readouterr().err
    assert not (root / "build").exists()
    path = run_build(root, config, fake_handlers(), last="ingest")[0]
    original = path.read_bytes()
    for payload in (float("nan"), object(), {1: "nonstring key"}):
        with pytest.raises((ValueError, TypeError)):
            run_build(
                root,
                config,
                {"ingest": lambda _config, _prior, value=payload: value},
                last="ingest",
            )
        assert path.read_bytes() == original
        assert list(path.parent.iterdir()) == [path], "temporary artifacts are cleaned up"
    with pytest.raises(ValueError, match="Unsupported artifact"):
        artifact_path(root, "../pl", P1_STAGES[0])
