from hypothesis import given
from hypothesis import strategies as st

import wow_pipeline


def test_package_imports() -> None:
    assert wow_pipeline.__doc__


@given(st.text())
def test_casefold_idempotent(word: str) -> None:
    assert word.casefold().casefold() == word.casefold()
