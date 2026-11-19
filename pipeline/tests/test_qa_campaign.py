"""Check spacing and deterministic selection without fetching the dictionary."""

from collections import deque

import pytest
from wordgame_pipeline.qa_campaign import History, Wheel, next_layout


def test_recent_support_words_defer_a_wheel_without_losing_it() -> None:
    history = History(last_slot={"TAK": 102, "KAT": 102})
    deferred = Wheel("AAKRT", ("KARTA",), ("KARTA", "KAT", "TAK"))
    spare = Wheel("DMOY", ("DOMY",), ("DOMY", "DOM", "DYM"))
    queues = {4: deque([spare]), 5: deque([deferred])}

    first, layout = next_layout(queues, history, 201)

    assert first == "DMOY"
    assert "DOMY" in {p[0] for p in layout}
    assert tuple(queues[5]) == (deferred,)
    second, reactivated = next_layout(queues, history, 202)
    assert second == "AAKRT"
    assert len(reactivated) >= 2
    assert deferred.answers == ("KARTA", "KAT", "TAK")


def test_same_wheel_and_slot_produce_the_same_layout() -> None:
    wheel = Wheel("AAKRT", ("KARTA",), ("KARTA", "KAT", "TAK"))
    assert next_layout({5: deque([wheel])}, History(), 201) == next_layout(
        {5: deque([wheel])}, History(), 201
    )


def test_history_rejects_repeats_without_consuming_slot() -> None:
    history = History()
    history.record({"slot": 1, "letters": list("AKT"), "words": [{"w": "KAT"}]})
    with pytest.raises(ValueError, match="spacing conflict"):
        history.record(
            {"slot": 2, "letters": list("AAKRT"), "words": [{"w": "KAT"}, {"w": "KARTA"}]}
        )
    assert history.wheels == {"AKT"}
    assert not history.available("KAT", 100)
    assert history.available("KAT", 101)
