"""Canonical review dossier built from independent validated pipeline diagnostics."""

from dataclasses import asdict

from ..candidates.coverage import CoverageReport
from ..dedupe.summary import ConflictSummary
from ..grid.quality import GridQuality
from ..scoring.drift import ScoreShift
from ..sequence.snapshot import SlotCurveRow


def compile_qa_dossier(
    coverage: CoverageReport,
    grid: GridQuality,
    conflicts: ConflictSummary,
    curve: tuple[SlotCurveRow, ...],
    shifts: tuple[ScoreShift, ...],
) -> dict[str, object]:
    """Package checked diagnostics without interpreting them as approval."""
    if (
        not isinstance(coverage, CoverageReport)
        or not isinstance(grid, GridQuality)
        or not isinstance(conflicts, ConflictSummary)
        or not isinstance(curve, tuple)
        or any(not isinstance(row, SlotCurveRow) for row in curve)
        or not isinstance(shifts, tuple)
        or any(not isinstance(row, ScoreShift) for row in shifts)
    ):
        raise ValueError("Expected immutable typed QA evidence")
    if any(left.slot >= right.slot for left, right in zip(curve, curve[1:], strict=False)):
        raise ValueError("Curve rows must have unique increasing slots")
    if tuple(sorted(shifts, key=lambda row: (-abs(row.delta), row.candidate_id))) != shifts:
        raise ValueError("Score shifts must be deterministically ranked")
    return {
        "schema_version": 1,
        "scope": "offline-review-only",
        "approval": "not-established",
        "candidate_supply": asdict(coverage),
        "grid_quality": asdict(grid),
        "duplicate_conflicts": asdict(conflicts),
        "curve_slots": [asdict(row) for row in curve],
        "scoring_shifts": [asdict(row) for row in shifts],
    }
