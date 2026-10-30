"""Read-only upper bound on unique campaign wheels from trusted tier evidence.

This intentionally does not call WordIndex.automatic()/pools(): those construct
complete bonus lists for every multiset and would make a 30k preflight expensive.
"""

from dataclasses import dataclass

from .core import WordIndex


@dataclass(frozen=True)
class CampaignCapacity:
    target_slots: int
    shipped_slots: int
    source_wheels: int
    unused_source_wheels: int
    theoretical_max_slots: int
    missing_unique_wheels: int


def audit_campaign_capacity(
    index: WordIndex, existing_wheels: list | tuple, *, target_slots: int
) -> CampaignCapacity:
    """Audit an upper bound only; no geometry, lexical approval or slot allocation."""
    if not isinstance(index, WordIndex):
        raise ValueError("Expected validated Polish word index")
    if type(target_slots) is not int or target_slots < 1:
        raise ValueError("Campaign target must be a positive integer")
    if not isinstance(existing_wheels, (list, tuple)):
        raise ValueError("Expected campaign wheel sequence")

    shipped: set[str] = set()
    for letters in existing_wheels:
        if (
            not isinstance(letters, (list, tuple))
            or not index.config.min_length <= len(letters) <= index.config.max_length
            or any(
                not isinstance(letter, str)
                or len(letter) != 1
                or letter not in index.config.alphabet
                for letter in letters
            )
        ):
            raise ValueError("Invalid existing campaign wheel")
        signature = "".join(sorted(letters))
        if signature in shipped:
            raise ValueError("Repeated existing campaign letter multiset")
        shipped.add(signature)
    if target_slots < len(shipped):
        raise ValueError("Campaign target smaller than existing released slots")

    available = {
        "".join(sorted(word))
        for word, tier in index.tiers.items()
        if tier == "level_ok"
    }
    unused = len(available - shipped)
    theoretical = len(shipped) + unused
    return CampaignCapacity(
        target_slots=target_slots,
        shipped_slots=len(shipped),
        source_wheels=len(available),
        unused_source_wheels=unused,
        theoretical_max_slots=theoretical,
        missing_unique_wheels=max(0, target_slots - theoretical),
    )
