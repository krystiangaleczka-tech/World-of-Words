"""Deterministic, read-only campaign statistics for human content review."""

import math
from collections import Counter
from collections.abc import Mapping


def _unit(value: object) -> float:
    if type(value) not in (int, float):
        raise ValueError("Expected finite numeric difficulty, not coercion")
    try:
        number = float(value)
    except OverflowError as exc:
        raise ValueError("Unrepresentable difficulty") from exc
    if not math.isfinite(number) or not 0 <= number <= 1:
        raise ValueError("Expected normalized difficulty in [0,1]")
    return number


def summarize_campaign(levels: list | tuple, *, bucket_edges: tuple) -> dict:
    """Summarize already validated campaign levels without assigning content.

    The caller owns schema, tier, geometry and release-lock validation. Buckets
    are half-open except the last, which also includes score 1.
    """
    if not isinstance(levels, (list, tuple)) or not levels:
        raise ValueError("Expected nonempty finite campaign levels")
    if (
        not isinstance(bucket_edges, tuple)
        or len(bucket_edges) < 2
        or any(type(edge) not in (int, float) for edge in bucket_edges)
    ):
        raise ValueError("Explicit numeric histogram edges are required")
    edges = tuple(_unit(edge) for edge in bucket_edges)
    if edges[0] != 0 or edges[-1] != 1 or any(
        left >= right for left, right in zip(edges, edges[1:], strict=False)
    ):
        raise ValueError("Histogram edges must strictly partition [0,1]")

    by_slot: dict[int, tuple] = {}
    for level in levels:
        if not isinstance(level, Mapping):
            raise ValueError("Expected a campaign level object")
        slot = level.get("slot")
        if (
            type(slot) is not int
            or not 1 <= slot <= 9999
            or slot in by_slot
            or level.get("id") != f"pl-c-{slot:06d}"
        ):
            raise ValueError("Invalid or duplicate campaign identity")
        letters, words, bonus = (
            level.get("letters"),
            level.get("words"),
            level.get("bonus"),
        )
        source, landmark = level.get("source"), level.get("landmark")
        if (
            not isinstance(letters, list)
            or not 3 <= len(letters) <= 8
            or any(not isinstance(tile, str) or len(tile) != 1 for tile in letters)
            or not isinstance(words, list)
            or not words
            or any(
                not isinstance(item, Mapping)
                or not isinstance(item.get("w"), str)
                or not item["w"]
                for item in words
            )
            or len({item["w"] for item in words}) != len(words)
            or not isinstance(bonus, list)
            or any(not isinstance(word, str) for word in bonus)
            or source not in ("handmade", "generated")
            or type(landmark) is not bool
        ):
            raise ValueError("Invalid campaign QA input")
        by_slot[slot] = (
            len(letters),
            len(words),
            len(bonus),
            source,
            landmark,
            _unit(level.get("difficulty")),
        )
    if len(by_slot) != max(by_slot):
        raise ValueError("Campaign slots must be contiguous from one")

    ordered = [by_slot[slot] for slot in sorted(by_slot)]
    sizes = Counter(row[0] for row in ordered)
    source_counts = Counter(row[3] for row in ordered)
    histogram = []
    for index, (lower, upper) in enumerate(zip(edges, edges[1:], strict=False)):
        last = index == len(edges) - 2
        count = sum(
            lower <= row[5] <= upper if last else lower <= row[5] < upper
            for row in ordered
        )
        histogram.append({"lower": lower, "upper": upper, "count": count})
    return {
        "schema_version": 1,
        "slots": len(ordered),
        "by_source": {
            "handmade": source_counts["handmade"],
            "generated": source_counts["generated"],
        },
        "landmarks": sum(row[4] for row in ordered),
        "wheel_sizes": [{"letters": size, "count": sizes[size]} for size in sorted(sizes)],
        "selected_words": sum(row[1] for row in ordered),
        "bonus_words": sum(row[2] for row in ordered),
        "mean_difficulty": math.fsum(row[5] for row in ordered) / len(ordered),
        "difficulty_histogram": histogram,
    }
