"""Fixture-only curve parameters; no production curve or content is written."""

import copy
from dataclasses import FrozenInstanceError, replace

import pytest
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.sequence import CurveConfig, CurveTarget, load_curve, target_for_slot


def settings():
    return dict(
        schema_version=1,
        first=1,
        last=40,
        base=0.1,
        trend=0.01,
        period=5,
        amplitude=0.2,
        landmark_spike=0.3,
        breather_drop=0.1,
        landmarks=[18, 30],
    )


def test_exact_trend_saw_reset_and_landmark_breather_arithmetic():
    config = CurveConfig.from_dict(settings())
    assert target_for_slot(16, config).target == pytest.approx(0.25)
    assert target_for_slot(17, config).target == pytest.approx(0.31)
    assert target_for_slot(20, config).target == pytest.approx(0.49)
    assert target_for_slot(21, config).target == pytest.approx(0.3)
    landmark = target_for_slot(18, config)
    assert landmark.kind == "landmark" and landmark.baseline == pytest.approx(0.37)
    assert landmark.target == pytest.approx(0.67)
    breather = target_for_slot(19, config)
    assert breather.kind == "breather" and breather.baseline == pytest.approx(0.43)
    assert breather.target == pytest.approx(0.33) and breather.target < landmark.target


def test_all_onboarding_slots_are_outside_curve_and_region_offset_is_explicit():
    config = CurveConfig.from_dict(settings())
    for slot in range(1, 16):
        assert target_for_slot(slot, config) == CurveTarget(slot, "onboarding", None, None)
    config = replace(config, first=16)
    assert target_for_slot(16, config).target == 0.1


def test_saturation_tiny_drop_and_single_query_at_large_safe_slot():
    config = CurveConfig.from_dict(settings() | dict(base=1, trend=1))
    assert target_for_slot(18, config).target == 1
    assert target_for_slot(19, config).target == 0.9
    tiny = replace(config, breather_drop=5e-324)
    assert 0 <= target_for_slot(19, tiny).target < target_for_slot(18, tiny).target
    huge = replace(config, last=2**53 - 1)
    assert target_for_slot(huge.last, huge).target == 1


def test_steep_trend_breather_is_easier_than_previous_landmark():
    config = CurveConfig.from_dict(
        settings() | dict(first=16, base=0, trend=0.3, amplitude=0, landmark_spike=0.01)
    )
    previous = target_for_slot(18, config).target
    breather = target_for_slot(19, config)
    assert breather.target < previous
    assert breather.target == pytest.approx(previous - config.breather_drop)


def test_immutable_roundtrip_order_and_no_input_mutation():
    data = settings()
    before = copy.deepcopy(data)
    config = CurveConfig.from_dict(data)
    assert data == before and CurveConfig.from_dict(config.to_dict()) == config
    data["landmarks"].reverse()
    assert CurveConfig.from_dict(dict(reversed(list(data.items())))) == config
    config.to_dict()["landmarks"].append(20)
    assert config.landmarks == (18, 30)
    with pytest.raises(FrozenInstanceError):
        config.base = 0
    with pytest.raises(FrozenInstanceError):
        target_for_slot(18, config).target = 0


@pytest.mark.parametrize(
    "field,value",
    [
        ("first", True),
        ("first", 0),
        ("last", 0),
        ("last", 2**53),
        ("period", 1),
        ("period", 2.0),
        ("base", True),
        ("base", -0.1),
        ("base", 1.1),
        ("trend", float("nan")),
        ("amplitude", float("inf")),
        ("landmark_spike", 0),
        ("breather_drop", 0),
        ("base", 10**1000),
        ("base", "0.1"),
        ("landmarks", [18, 18]),
        ("landmarks", [15]),
        ("landmarks", [40]),
        ("landmarks", [18, 19]),
        ("landmarks", [True]),
        ("landmarks", [18.0]),
    ],
)
def test_invalid_fields_fail_parsed_and_direct_constructors(field, value):
    data = settings() | {field: value}
    with pytest.raises(ValueError):
        CurveConfig.from_dict(data)
    if field == "landmarks":
        value = tuple(value)
    with pytest.raises(ValueError):
        replace(CurveConfig.from_dict(settings()), **{field: value})


def test_shape_slots_target_constructors_and_explicit_file_validation(tmp_path):
    config = CurveConfig.from_dict(settings())
    for data in (None, {}, settings() | {"extra": 1}, settings() | {"schema_version": True}):
        with pytest.raises(ValueError):
            CurveConfig.from_dict(data)
    for slot in (True, 0, 41, 1.0, 2**53):
        with pytest.raises(ValueError):
            target_for_slot(slot, config)
    with pytest.raises(ValueError):
        target_for_slot(16, None)
    with pytest.raises(ValueError):
        CurveTarget(1, "regular", 0, 0)
    with pytest.raises(ValueError):
        CurveTarget(16, "onboarding", None, None)
    with pytest.raises(ValueError):
        CurveTarget(18, "landmark", float("nan"), 0)
    path = tmp_path / "curve.yaml"
    with pytest.raises(ValueError):
        load_curve(path)
    for text in ('{"schema_version":1,"schema_version":1}', '{"base":NaN}', "base: 0"):
        path.write_text(text)
        with pytest.raises(ValueError):
            load_curve(path)
    path.write_bytes(canonical_bytes(settings()))
    before = path.read_bytes()
    assert load_curve(path) == config
    assert path.read_bytes() == before


def test_reversed_positive_region_and_landmark_before_region_fail():
    for update in (dict(first=20, last=19, landmarks=[]), dict(first=20, landmarks=[18])):
        with pytest.raises(ValueError):
            CurveConfig.from_dict(settings() | update)
