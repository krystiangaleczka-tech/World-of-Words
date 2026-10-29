"""Feature explanations are deterministic and side-effect free."""

from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.scoring.contributions import ContributionRow, rank_feature_contributions
from wordgame_pipeline.scoring.features import FEATURE_NAMES
from wordgame_pipeline.scoring.model import ScoringConfig


def config():
    return ScoringConfig.from_dict(
        {
            "schema_version": 1,
            "features": {
                name: {
                    "weight": int(name == "letter_count"),
                    "minimum": 0,
                    "maximum": 8,
                    "direction": "higher",
                }
                for name in FEATURE_NAMES
            },
        }
    )


def evidence():
    return {name: 4 if name == "letter_count" else 0 for name in FEATURE_NAMES}


def test_one_nonzero_contribution_and_threshold():
    values = evidence()
    assert rank_feature_contributions(values, config(), minimum_contribution=0) == (
        ContributionRow("letter_count", 4, 0.5, 0.5),
    )
    assert rank_feature_contributions(values, config(), minimum_contribution=0.5) == ()
    assert values == evidence()
    row = rank_feature_contributions(values, config(), minimum_contribution=0)[0]
    with pytest.raises(FrozenInstanceError):
        row.raw = 5


@pytest.mark.parametrize("bad", [True, -1, 1.1, float("nan"), "0", 10**400])
def test_bad_threshold(bad):
    with pytest.raises(ValueError):
        rank_feature_contributions(evidence(), config(), minimum_contribution=bad)


def test_invalid_features_or_config_rejected():
    with pytest.raises(ValueError):
        rank_feature_contributions({}, config(), minimum_contribution=0)
    with pytest.raises(ValueError):
        rank_feature_contributions(evidence(), None, minimum_contribution=0)
    with pytest.raises(ValueError):
        rank_feature_contributions(
            evidence() | {"letter_count": float("inf")}, config(), minimum_contribution=0
        )
