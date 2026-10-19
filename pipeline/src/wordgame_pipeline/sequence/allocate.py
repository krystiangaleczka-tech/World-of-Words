"""Deterministic greedy preview with fixed future reservations; no publication."""

from dataclasses import dataclass

from ..config import LanguageConfig
from ..dedupe import DuplicateConflict, DuplicatePolicy, audit_duplicates
from .curve import _unit
from .slots import SlotPlan, SlotRequirement, _identity


@dataclass(frozen=True)
class ScoredCandidate:
    id: str
    letters: tuple[str, ...]
    words: tuple[str, ...]
    seed_word: str
    difficulty: float
    authored: bool
    landmark: bool

    def __post_init__(self) -> None:
        _identity(self.id)
        object.__setattr__(self, "difficulty", _unit(self.difficulty))
        if (
            not isinstance(self.letters, tuple)
            or not self.letters
            or any(not isinstance(c, str) for c in self.letters)
            or not isinstance(self.words, tuple)
            or not self.words
            or any(not isinstance(w, str) for w in self.words)
            or len(set(self.words)) != len(self.words)
            or not isinstance(self.seed_word, str)
            or self.seed_word not in self.words
            or type(self.authored) is not bool
            or type(self.landmark) is not bool
            or (self.landmark and not self.authored)
        ):
            raise ValueError("Invalid immutable candidate data or authorship flags")

    def record(self, slot: int) -> dict:
        return dict(
            id=self.id,
            pool="campaign",
            slot=slot,
            letters=list(self.letters),
            words=list(self.words),
            seed_word=self.seed_word,
        )


@dataclass(frozen=True)
class Rejection:
    candidate_id: str
    reason: str
    conflicts: tuple[DuplicateConflict, ...]


@dataclass(frozen=True)
class Assignment:
    requirement: SlotRequirement
    candidate: ScoredCandidate
    mode: str
    deviation: float | None
    rejected: tuple[Rejection, ...]


@dataclass(frozen=True)
class Allocation:
    assignments: tuple[Assignment, ...]
    unused: tuple[str, ...]


class AllocationError(ValueError):
    def __init__(
        self,
        code: str,
        slot: int | None = None,
        blocked: tuple[Rejection, ...] = (),
        conflicts: tuple[DuplicateConflict, ...] = (),
    ) -> None:
        self.code, self.slot, self.blocked, self.conflicts = code, slot, blocked, conflicts
        super().__init__(f"{code} at slot {slot}" if slot is not None else code)


def allocate(
    plan: SlotPlan, candidates: list | tuple, policy: DuplicatePolicy, language: LanguageConfig
) -> Allocation:
    if not isinstance(plan, SlotPlan) or not isinstance(candidates, (list, tuple)):
        raise ValueError("Expected slot plan and finite candidate collection")
    audit_duplicates([], policy, language)
    pool = {}
    for candidate in candidates:
        if not isinstance(candidate, ScoredCandidate) or candidate.id in pool:
            raise ValueError("Expected unique immutable scored candidates")
        audit_duplicates([candidate.record(1)], policy, language)
        pool[candidate.id] = candidate
    fixed = {r.slot: r.candidate_id for r in (*plan.authored, *plan.released)}
    for slot, identity in sorted(fixed.items()):
        if identity not in pool:
            raise AllocationError("fixed_missing", slot)
        requirement, candidate = plan.requirement(slot), pool[identity]
        if (requirement.authored != candidate.authored) or (
            requirement.curve.kind == "landmark"
        ) != candidate.landmark:
            raise AllocationError("fixed_incompatible", slot)
    if plan.total > len(pool):
        raise AllocationError("pool_too_small")
    chosen = {slot: pool[identity] for slot, identity in sorted(fixed.items())}
    conflicts = audit_duplicates([c.record(slot) for slot, c in chosen.items()], policy, language)
    if conflicts:
        raise AllocationError("fixed_conflict", conflicts=conflicts)
    reserved, used, rejected_by_slot = set(fixed.values()), set(fixed.values()), {}
    for slot in range(1, plan.total + 1):
        if slot in chosen:
            continue
        target = plan.requirement(slot).curve.target
        ranked = sorted(
            (c for c in pool.values() if c.id not in used and c.id not in reserved),
            key=lambda c: (abs(c.difficulty - target), c.id),
        )
        rejected = []
        for candidate in ranked:
            if candidate.authored:
                rejected.append(Rejection(candidate.id, "unreserved_authored", ()))
                continue
            conflicts = tuple(
                conflict
                for previous_slot, previous in sorted(chosen.items())
                for conflict in audit_duplicates(
                    [candidate.record(slot), previous.record(previous_slot)], policy, language
                )
            )
            if conflicts:
                rejected.append(Rejection(candidate.id, "duplicate", conflicts))
                continue
            chosen[slot] = candidate
            used.add(candidate.id)
            rejected_by_slot[slot] = tuple(rejected)
            break
        else:
            raise AllocationError("greedy_blocked", slot, tuple(rejected))
    assignments = []
    for slot, candidate in sorted(chosen.items()):
        requirement = plan.requirement(slot)
        mode = (
            "released"
            if requirement.released
            else "authored"
            if requirement.authored
            else "nearest"
        )
        deviation = (
            None
            if requirement.curve.target is None
            else abs(candidate.difficulty - requirement.curve.target)
        )
        assignments.append(
            Assignment(requirement, candidate, mode, deviation, rejected_by_slot.get(slot, ()))
        )
    return Allocation(tuple(assignments), tuple(sorted(set(pool) - used)))
