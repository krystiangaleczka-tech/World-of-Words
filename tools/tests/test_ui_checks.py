from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("ui_checks", REPO / "tools/ui_checks.py")
assert SPEC and SPEC.loader
UI = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(UI)


def script(body: str) -> str:
    return (
        "extends Control\nfunc test() -> void:\n"
        + "\n".join("\t" + line for line in body.splitlines())
        + "\n"
    )


@pytest.mark.parametrize(
    "body",
    [
        "color = Color(1, 0, 0)",
        'color = Color("red")',
        "color = Color.from_hsv(0.2, 1, 1)",
        'color = "#ab12ff"',
        't.tween_property(\n self, "scale", Vector2.ONE,\n 0.3\n)',
        "t.tween_method(callback, 0, 1, 2)",
        "t.tween_interval(0.1)",
        'add_theme_font_size_override("font_size", 32)',
        'add_theme_constant_override("margin_left", 8)',
        "style.corner_radius_top_left = 12",
        "custom_minimum_size = Vector2(120, 144)",
    ],
)
def test_raw_visual_values_fail(body: str) -> None:
    errors = UI.gd_errors(script(body), "tokens", set())
    assert errors and all(line >= 3 and "R-UI-3" in reason for line, reason in errors)


@pytest.mark.parametrize(
    "body",
    [
        "color = Color(Tokens.Palette.TEXT, alpha)",
        "modulate = Color.WHITE",
        't.tween_property(self, "scale", Vector2.ONE, Tokens.dur(Tokens.Motion.FAST))',
        'add_theme_constant_override("margin_left", Tokens.Space.M + int(maxf(inset, 0)))',
        'text = "Color(1, 0, 0)" # Color(1, 0, 0)',
        "offset_left = 0",
    ],
)
def test_tokens_and_comments_are_valid(body: str) -> None:
    assert not UI.gd_errors(script(body), "tokens", set())


@pytest.mark.parametrize(
    "body",
    [
        'text = "Play"',
        'label.tooltip_text = "Hello"',
        'set_text("Play")',
        'draw_string(font, pos, "Hello")',
        'add_item("Shop")',
        'add_tab("Home")',
        'label.text = tr("home.play") + " now"',
        'label.text = "%s" % ["Hello"]',
        'label.placeholder_text = "Word"',
        'label.accessibility_name = "Hint"',
        'text = tr("missing.key")',
    ],
)
def test_literal_copy_and_unknown_keys_fail(body: str) -> None:
    assert UI.gd_errors(script(body), "strings", {"home.play"})


@pytest.mark.parametrize(
    "body",
    [
        'text = tr("home.play")',
        'text = "%s: %.2f\\n%s" % [tr("home.play"), amount, word]',
        'text = ""',
        "text = word",
        "draw_string(font, pos, letter)",
        'text = ProjectSettings.get_setting("application/config/version", "")',
        'text = tr("home.play") # "Hello"',
    ],
)
def test_keys_formats_dynamic_words_and_metadata_are_valid(body: str) -> None:
    assert not UI.gd_errors(script(body), "strings", {"home.play"})


@pytest.mark.parametrize(
    "mode,property",
    [
        ("tokens", "modulate = Color(1, 0, 0, 1)"),
        ("tokens", "theme_override_font_sizes/font_size = 32"),
        ("tokens", "theme_override_constants/margin_left = 12"),
        ("strings", 'text = "Play"'),
        ("strings", 'tooltip_text = "Help"'),
        ("strings", 'text = "unterminated'),
    ],
)
def test_scene_failures(mode: str, property: str) -> None:
    assert UI.scene_errors(
        '[gd_scene format=3]\n[node name="Main" type="Control"]\n' + property, mode, set()
    )


def test_scene_keys_and_empty_copy_valid() -> None:
    assert not UI.scene_errors(
        '[gd_scene format=3]\n[node name="Main" type="Label"]\ntext = "home.play"\n',
        "strings",
        {"home.play"},
    )
    assert UI.scene_errors('[node name="broken"\ntext = ""', "strings", set())


@pytest.fixture
def root(tmp_path: Path) -> Path:
    for scope in UI.SCOPES:
        (tmp_path / scope).mkdir(parents=True)
    (tmp_path / "game/locale").mkdir()
    (tmp_path / "game/locale/home.csv").write_text("keys,pl,en\nhome.play,Graj,Play\n")
    return tmp_path


def test_scope_parse_failure_and_missing_roots(root: Path) -> None:
    (root / "game/features/bad.gd").write_text("extends???")
    (root / "game/ui/tokens.gd").write_text(script("color = Color(1, 0, 0)"))
    errors = UI.scan(root, "tokens")
    assert len(errors) == 1 and "cannot parse" in errors[0]
    (root / "game/features/bad.gd").unlink()
    (root / "game/features").rmdir()
    assert "required scan directory" in UI.scan(root, "tokens")[0]
    (root / "game/locale/home.csv").unlink()
    assert any("missing locale" in e for e in UI.scan(root, "strings"))


@pytest.mark.parametrize(
    "name,body", [("tokens", "color = Color(1, 0, 0)"), ("strings", 'text = "Play"')]
)
def test_cli_exit_and_line_diagnostic(root: Path, name: str, body: str) -> None:
    path = root / "game/features/sample.gd"
    path.write_text(script(body))
    result = subprocess.run(
        [sys.executable, str(REPO / f"tools/check_{name}.py"), "--root", str(root)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 1 and "game/features/sample.gd:3:" in result.stderr
    path.write_text(script('text = tr("home.play")'))
    result = subprocess.run(
        [sys.executable, str(REPO / f"tools/check_{name}.py"), "--root", str(root)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0 and "OK:" in result.stdout


def test_typed_declarations_are_guarded() -> None:
    assert UI.gd_errors("extends Control\nvar font_size: int = 32\n", "tokens", set())
    assert UI.gd_errors('extends Label\nvar text: String = "Play"\n', "strings", set())


def test_multiline_scene_arrays_and_code_like_copy() -> None:
    source = (
        '[gd_scene format=3]\n[node name="Main" type="Node"]\n'
        'values = [\n1,\n2\n]\ntext = "Color(1, 0, 0)"\n'
    )
    assert not UI.scene_errors(source, "tokens", set())
    assert UI.scene_errors(
        '[gd_scene format=3]\n[node name="Timer" type="Timer"]\nwait_time = 1', "tokens", set()
    )


@pytest.mark.parametrize(
    "body",
    [
        "tween.tween_interval(.5)",
        "tween.tween_interval(1e-1)",
        'add_theme_font_size_override("font_size", 0x20)',
        'add_theme_constant_override("margin_left", 0b1000)',
        "font_size = 1_000",
        "custom_minimum_size.x = 144",
        "color = Color.hex(0xff0000ff)",
        "color = Color.hex64(0xffff00000000ffff)",
    ],
)
def test_alternate_numeric_forms_and_colour_factories_fail(body: str) -> None:
    assert UI.gd_errors(script(body), "tokens", set())


@pytest.mark.parametrize(
    "source",
    [
        "",
        "; comment only",
        "[gd_scene format=3]\n = 5",
        "[gd_scene format=3]\nbad property = 5",
        '[node name="Main" type="Node"]\nvalue = 5',
    ],
)
def test_basic_scene_structure_fails_closed(source: str) -> None:
    assert UI.scene_errors(source, "tokens", set())


def test_colour_factory_owner_and_other_factories() -> None:
    assert UI.gd_errors(script("color = Color.from_ok_hsl(.2, .3, .4)"), "tokens", set())
    assert not UI.gd_errors(script('result = Helper.from_string("red")'), "tokens", set())
