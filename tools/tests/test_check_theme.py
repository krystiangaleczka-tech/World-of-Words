from __future__ import annotations

import importlib.util
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("check_theme", REPO / "tools/check_theme.py")
assert SPEC and SPEC.loader
THEME = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(THEME)


@pytest.fixture
def root(tmp_path: Path) -> Path:
    for output in THEME.OUTPUTS:
        path = tmp_path / output
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"expected")
    (tmp_path / "game/.godot").mkdir()
    (tmp_path / "game/.godot/sentinel").write_text("cache")
    return tmp_path


def fake(monkeypatch, mode="valid", output="docs/design/tokens.css"):
    def run(command, **kwargs):
        game = Path(command[command.index("--path") + 1])
        assert not (game / ".godot").exists()
        if "--script" in command:
            for generated in THEME.OUTPUTS:
                generated_path = game.parent / generated
                generated_path.parent.mkdir(parents=True, exist_ok=True)
                generated_path.write_bytes(b"expected")
            path = game.parent / output
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"expected")
            if mode == "changed":
                path.write_bytes(b"drift")
            if mode == "missing":
                path.unlink()
        step = "import" if "--import" in command else "generate"
        return subprocess.CompletedProcess(
            command, 1 if mode == step else 0, "WARNING: broken" if mode == "warning" else "", ""
        )

    monkeypatch.setattr(THEME.subprocess, "run", run)


@pytest.mark.parametrize("output", THEME.OUTPUTS)
def test_all_outputs_detect_drift_without_source_mutation(
    root: Path, monkeypatch, output: str
) -> None:
    fake(monkeypatch, "changed", output)
    before = {p: (root / p).read_bytes() for p in THEME.OUTPUTS}
    errors = THEME.check(root, "fake-godot")
    assert len(errors) == 1 and output in errors[0] and "run godot" in errors[0]
    assert before == {p: (root / p).read_bytes() for p in THEME.OUTPUTS}
    assert (root / "game/.godot/sentinel").read_text() == "cache"


@pytest.mark.parametrize("mode", ["valid", "missing", "import", "generate", "warning"])
def test_matching_missing_and_engine_failures(root: Path, monkeypatch, mode: str) -> None:
    fake(monkeypatch, mode)
    assert bool(THEME.check(root, "fake-godot")) == (mode != "valid")


def test_missing_source_output_and_cli(root: Path, monkeypatch, capsys) -> None:
    (root / THEME.OUTPUTS[0]).unlink()
    assert THEME.main(["--root", str(root), "--godot", "does-not-exist"]) == 1
    assert THEME.OUTPUTS[0] in capsys.readouterr().err
    (root / THEME.OUTPUTS[0]).write_bytes(b"expected")
    fake(monkeypatch)
    assert THEME.main(["--root", str(root)]) == 0
    assert "14 generated" in capsys.readouterr().out
