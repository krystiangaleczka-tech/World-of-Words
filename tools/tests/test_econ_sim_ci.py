"""Exercise real git diffs and the workflow's actual shell blocks without GitHub credentials."""

import json
import os
import shutil
import subprocess
import sys
from textwrap import dedent

import pytest

from tools.econ_sim_ci import ROOT, changed, relevant


def git(repo, *args):
    return subprocess.run(
        ["git", *args], cwd=repo, check=True, capture_output=True, text=True
    ).stdout.strip()


@pytest.fixture
def repo(tmp_path):
    git(tmp_path, "init")
    git(tmp_path, "config", "user.name", "Synthetic test")
    git(tmp_path, "config", "user.email", "test@example.invalid")
    shutil.copytree(ROOT / "game/data/config", tmp_path / "game/data/config")
    (tmp_path / "tools").mkdir()
    for name in ("econ_sim.py", "econ_sim_ci.py"):
        shutil.copy(ROOT / "tools" / name, tmp_path / "tools" / name)
    git(tmp_path, "add", ".")
    git(tmp_path, "commit", "-m", "synthetic baseline")
    return tmp_path


def block(name):
    text = (ROOT / ".github/workflows/ci.yml").read_text().split("  economy-sim:\n")[1]
    text = text.split("      - name: " + name + "\n")[1].split("        run: |\n")[1]
    lines = []
    for line in text.splitlines():
        if not line.startswith("          "):
            break
        lines.append(line)
    return dedent("\n".join(lines)) + "\n"


@pytest.mark.parametrize(
    "prefix", ["economy", "bonus", "hint", "unlocks", "ads", "consent", "meta", "onboarding", "iap"]
)
def test_each_config_prefix_triggers(prefix):
    assert relevant([f"game/data/config/{prefix}.json"])


def test_related_and_unrelated_paths():
    for path in (
        "tools/econ_sim.py",
        "tools/econ_sim_ci.py",
        "tools/tests/test_econ_sim.py",
        "tools/tests/test_econ_sim_ci.py",
        ".github/workflows/ci.yml",
    ):
        assert relevant([path])
    assert not relevant(["README.md", "game/data/config/notes.md", "docs/economy.json"])
    assert not relevant([])


def test_actual_git_changes_initial_push_deletion_and_rename(repo):
    base = git(repo, "rev-parse", "HEAD")
    assert not changed(repo, base)
    assert changed(repo, "")
    assert changed(repo, "0" * 40)
    (repo / "notes.md").write_text("unrelated")
    git(repo, "add", ".")
    git(repo, "commit", "-m", "notes")
    assert not changed(repo, base)
    git(repo, "mv", "game/data/config/economy.json", "game/data/config/economy-new.json")
    git(repo, "commit", "-m", "rename")
    assert changed(repo, base)
    before = git(repo, "rev-parse", "HEAD")
    git(repo, "rm", "game/data/config/economy-new.json")
    git(repo, "commit", "-m", "delete")
    assert changed(repo, before)
    with pytest.raises(subprocess.CalledProcessError):
        changed(repo, "missing-ref")


def test_cli_flags_and_invalid_ref(repo):
    base = git(repo, "rev-parse", "HEAD")
    command = [sys.executable, str(ROOT / "tools/econ_sim_ci.py"), "--repo", str(repo), "--base"]
    assert (
        subprocess.run(command + [base], check=True, capture_output=True, text=True).stdout
        == "changed=false\n"
    )
    assert (
        subprocess.run(command + [""], check=True, capture_output=True, text=True).stdout
        == "changed=true\n"
    )
    result = subprocess.run(command + ["missing"], capture_output=True, text=True)
    assert result.returncode == 2
    assert "cannot determine" in result.stderr


@pytest.mark.parametrize("event", ["pr", "push", "initial"])
def test_actual_workflow_detection_and_four_reports(repo, event):
    base = git(repo, "rev-parse", "HEAD")
    path = repo / "game/data/config/economy.json"
    values = json.loads(path.read_text())
    values["economy.reward.level_complete"]["default"] = 26
    path.write_text(json.dumps(values))
    git(repo, "add", ".")
    git(repo, "commit", "-m", "economic input")
    output, summary = repo / "output", repo / "summary"
    env = dict(
        os.environ,
        GITHUB_OUTPUT=str(output),
        GITHUB_STEP_SUMMARY=str(summary),
        GITHUB_SHA=git(repo, "rev-parse", "HEAD"),
        PR_BASE_SHA=base if event == "pr" else "",
        BEFORE_SHA="0" * 40 if event == "initial" else base,
    )
    detect, generate = (
        block("Detect economy simulation changes"),
        block("Generate readable economy reports"),
    )
    for script in (detect, generate):
        subprocess.run(["bash", "-n"], input=script, text=True, check=True)
    subprocess.run(["bash", "-c", detect], cwd=repo, env=env, check=True)
    assert output.read_text() == "changed=true\n"
    subprocess.run(["bash", "-c", generate], cwd=repo, env=env, check=True, capture_output=True)
    assert sorted(path.name for path in (repo / "builds/economy").iterdir()) == [
        "base-only.json",
        "base-only.md",
        "default.json",
        "default.md",
    ]
    for scenario in ("default", "base-only"):
        report = json.loads((repo / f"builds/economy/{scenario}.json").read_text())
        assert len(report["policies"]["saver"]["rows"]) == 300
        assert report["policies"]["saver"]["sources"]["base"] == 7800
    assert summary.read_text().count("# Hypothetical P2 economy simulation") == 2
    base_only = json.loads((repo / "builds/economy/base-only.json").read_text())
    assert base_only["policies"]["saver"]["sources"]["bonus"] == 0
    assert base_only["assumptions"]["onboarding"] is False
    before = (repo / "builds/economy/default.json").read_bytes()
    subprocess.run(["bash", "-c", generate], cwd=repo, env=env, check=True, capture_output=True)
    assert (repo / "builds/economy/default.json").read_bytes() == before


def test_workflow_skip_detection_and_generation_failure(repo):
    output, summary = repo / "output", repo / "summary"
    env = dict(
        os.environ,
        GITHUB_OUTPUT=str(output),
        GITHUB_STEP_SUMMARY=str(summary),
        GITHUB_SHA="HEAD",
        PR_BASE_SHA="HEAD",
        BEFORE_SHA="",
    )
    subprocess.run(
        ["bash", "-c", block("Detect economy simulation changes")], cwd=repo, env=env, check=True
    )
    assert output.read_text() == "changed=false\n"
    (repo / "game/data/config/economy.json").write_text("{}")
    result = subprocess.run(
        ["bash", "-c", block("Generate readable economy reports")],
        cwd=repo,
        env=env,
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert not (repo / "builds/economy/default.json").exists()
