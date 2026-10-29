"""Actual token-reading and fixture-sized COMPACT grid fit tests."""

from pathlib import Path

import pytest
from wordgame_pipeline.validate.compact import load_compact_tokens, validate_compact_grid

ROOT = Path(__file__).resolve().parents[3]
TOKENS = ROOT / "game/ui/tokens.gd"


def test_actual_canonical_tokens_and_bounded_cell_fit():
    tokens = load_compact_tokens(TOKENS)
    assert tokens.cell_min > tokens.gap
    assert validate_compact_grid(
        {"w": 4, "h": 4}, area_width=320, area_height=300,
        body_height=600, tokens=tokens,
    ) == pytest.approx(67)
    assert validate_compact_grid(
        {"w": 1, "h": 1}, area_width=1500, area_height=1200,
        body_height=1200, tokens=tokens,
    ) == tokens.cell_max


def test_too_many_columns_and_insufficient_grid_share_fail():
    tokens = load_compact_tokens(TOKENS)
    with pytest.raises(ValueError, match="CELL_MIN"):
        validate_compact_grid(
            {"w": 8, "h": 8}, area_width=320, area_height=300,
            body_height=600, tokens=tokens,
        )
    with pytest.raises(ValueError, match="body-height"):
        validate_compact_grid(
            {"w": 1, "h": 1}, area_width=1000, area_height=200,
            body_height=600, tokens=tokens,
        )


def test_layout_token_change_changes_the_gate(tmp_path):
    original = TOKENS.read_text(encoding="utf-8")
    sample = tmp_path / "tokens.gd"
    sample.write_text(original.replace(
        "const CELL_MIN: int = 64", "const CELL_MIN: int = 100"
    ))
    with pytest.raises(ValueError, match="CELL_MIN"):
        validate_compact_grid(
            {"w": 4, "h": 4}, area_width=320, area_height=300,
            body_height=600, tokens=load_compact_tokens(sample),
        )
    assert original == TOKENS.read_text(encoding="utf-8")


def test_missing_duplicate_and_wrong_type_tokens_fail(tmp_path):
    original = TOKENS.read_text(encoding="utf-8")
    for data in (
        original.replace("const CELL_MIN: int = 64", ""),
        original.replace("const CELL_MIN: int = 64", "const CELL_MIN: float = 64.0"),
        original.replace(
            "const CELL_MIN: int = 64",
            "const CELL_MIN: int = 64\n\tconst CELL_MIN: int = 64",
        ),
    ):
        path = tmp_path / "tokens.gd"
        path.write_text(data, encoding="utf-8")
        with pytest.raises(ValueError):
            load_compact_tokens(path)


@pytest.mark.parametrize(
    "grid", [
        {"w": True, "h": 1}, {"w": 0, "h": 1}, {"w": 11, "h": 1},
        {"w": 2.0, "h": 3}, {"w": 1}, {"w": 1, "h": 1, "extra": 0},
    ],
)
def test_invalid_grid_rejected(grid):
    with pytest.raises(ValueError):
        validate_compact_grid(
            grid, area_width=320, area_height=300,
            body_height=600, tokens=load_compact_tokens(TOKENS),
        )


@pytest.mark.parametrize("field,value", [
    ("area_width", True), ("area_width", float("nan")), ("area_width", 0),
    ("area_height", float("inf")), ("area_height", -1), ("body_height", 10**400),
])
def test_invalid_size_rejected(field, value):
    kw = dict(area_width=320, area_height=300, body_height=600)
    kw[field] = value
    with pytest.raises(ValueError):
        validate_compact_grid({"w": 4, "h": 4}, tokens=load_compact_tokens(TOKENS), **kw)


def test_no_default_viewport_or_body_rect_is_inferred():
    tokens = load_compact_tokens(TOKENS)
    with pytest.raises(ValueError):
        validate_compact_grid(
            {"w": 4, "h": 4}, area_width=320, area_height=601,
            body_height=600, tokens=tokens,
        )
