"""Review packet combines existing immutable evidence without publishing."""

import copy

import pytest
from wordgame_pipeline.candidates.coverage import CoverageReport
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.dedupe.summary import REASONS, ConflictSummary
from wordgame_pipeline.grid.quality import GridQuality
from wordgame_pipeline.qa.dossier import compile_qa_dossier
from wordgame_pipeline.scoring.drift import ScoreShift
from wordgame_pipeline.sequence.snapshot import SlotCurveRow


def evidence():
    return (
        CoverageReport(2, 3, 2, ((3, 3),), ()),
        GridQuality(3, 3, 2, 5, 1, 5 / 9, True),
        ConflictSummary(3, 0, tuple((reason, 0) for reason in REASONS), (), 0),
        (SlotCurveRow(1, "r", "l", "onboarding", None, None, True, True),),
        (ScoreShift("a", 0.4, 0.5, 0.1),),
    )


def test_canonical_complete_readonly_packaging():
    values = evidence()
    before = copy.deepcopy(values)
    result = compile_qa_dossier(*values)
    assert result["schema_version"] == 1
    assert result["approval"] == "not-established"
    assert result["candidate_supply"]["eligible_wheels"] == 2
    assert result["grid_quality"]["crossings"] == 1
    assert result["curve_slots"][0]["target"] is None
    assert result["scoring_shifts"][0]["candidate_id"] == "a"
    assert canonical_bytes(result) == canonical_bytes(compile_qa_dossier(*values))
    result["curve_slots"][0]["region"] = "tampered"
    assert compile_qa_dossier(*values)["curve_slots"][0]["region"] == "r"
    assert values == before


def test_reject_untyped_evidence_and_unstable_order():
    values = evidence()
    for ix in range(5):
        changed = list(values)
        changed[ix] = []
        with pytest.raises(ValueError):
            compile_qa_dossier(*changed)
    curve = (
        SlotCurveRow(2, "r", "l", "regular", 0.5, 0.5, False, False),
        SlotCurveRow(1, "r", "l", "onboarding", None, None, True, True),
    )
    with pytest.raises(ValueError):
        compile_qa_dossier(*values[:3], curve, values[4])
    shifts = (ScoreShift("b", 0, 0.1, 0.1), ScoreShift("a", 0, 0.4, 0.4))
    with pytest.raises(ValueError):
        compile_qa_dossier(*values[:4], shifts)


def test_empty_diagnostic_subsets_are_not_false_approval():
    coverage, grid, conflicts, _, _ = evidence()
    report = compile_qa_dossier(coverage, grid, conflicts, (), ())
    assert not report["curve_slots"] and not report["scoring_shifts"]
    assert report["approval"] == "not-established"
