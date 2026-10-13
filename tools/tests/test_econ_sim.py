"""Small exact synthetic scenarios plus CLI and shipped defaults, no player evidence."""

import copy
import json
import subprocess
import sys

import pytest

from tools.econ_sim import ROOT, Options, load_defaults, render, simulate


def defaults():
    return load_defaults(ROOT / "game/data/config")


def test_three_deterministic_300_level_policies_and_accounting():
    values = defaults()
    before = copy.deepcopy(values)
    report = simulate(values)
    assert simulate(values) == report
    assert values == before
    assert set(report["policies"]) == {"saver", "hinter", "ad_watcher"}
    saver = report["policies"]["saver"]
    assert saver["final"]["coins"] == 10400
    assert saver["final"]["chests"] == 29
    assert saver["final"]["bonus_counter"] == 6
    assert report["intent_ratios"]["base_completions_per_hint"] == 4
    for policy in report["policies"].values():
        assert len(policy["rows"]) == 300
        source = policy["sources"]
        assert (
            policy["final"]["coins"]
            == sum(source[key] for key in ("base", "bonus", "double", "shop_ad", "iap"))
            - policy["final"]["spent_coins"]
        )
        assert policy["final"]["hint"] >= 0
        assert all(row["coins"] >= 0 for row in policy["rows"])
    assert "Synthetic" in render(report)
    assert "| saver | 300 |" in render(report)


def test_small_exact_gates_items_before_coins_and_ads():
    report = simulate(defaults(), Options(levels=12, bonus_per_level=0))
    policies = report["policies"]
    assert policies["saver"]["final"]["coins"] == 300
    hinter = policies["hinter"]
    assert hinter["rows"][5]["hints_used"] == 0
    assert hinter["rows"][6]["hint"] == 2
    assert hinter["rows"][6]["spent_coins"] == 0
    assert hinter["final"]["coins"] == 100
    assert hinter["final"]["hints_used"] == 5
    assert hinter["final"]["denied_tools"] == 1
    watcher = policies["ad_watcher"]
    assert watcher["sources"]["shop_ad"] == 200
    assert watcher["sources"]["double"] == 25
    assert watcher["final"]["coins"] == 525
    assert watcher["final"]["hint"] == 3


def test_base_only_zero_reward_and_injected_prices():
    values = defaults()
    report = simulate(values, Options(levels=20, bonus_per_level=0, onboarding=False))
    assert report["policies"]["saver"]["sources"] == dict(
        base=500, bonus=0, double=0, shop_ad=0, iap=0, onboarding_hints=0, ad_hints=0
    )
    assert report["policies"]["hinter"]["final"]["denied_tools"] > 0
    values["economy.reward.level_complete"] = 0
    values["economy.price.hint"] = 3
    report = simulate(values, Options(levels=20, bonus_per_level=0, onboarding=False))
    assert report["intent_ratios"]["base_completions_per_hint"] is None
    assert report["policies"]["hinter"]["final"]["coins"] == 0
    assert report["policies"]["hinter"]["final"]["denied_tools"] == 15


def test_multichest_carry_optional_iap_and_double_only_base():
    report = simulate(defaults(), Options(levels=12, bonus_per_level=23, iap_slot=7))
    saver = report["policies"]["saver"]
    assert saver["final"]["chests"] == 18
    assert saver["final"]["bonus_counter"] == 4
    assert saver["sources"]["iap"] == 1000
    assert saver["sources"]["bonus"] == 1800
    assert saver["final"]["coins"] == 3100
    watcher = report["policies"]["ad_watcher"]
    assert watcher["sources"]["double"] == 25
    assert watcher["sources"]["iap"] == 1000
    assert watcher["sources"]["bonus"] == 1800


def test_disabled_ads_and_zero_shop_cap():
    values = defaults()
    values["ads.rewarded.hint.enabled"] = False
    values["ads.rewarded.double.enabled"] = False
    values["ads.rewarded.shop_coins.daily_cap"] = 0
    policies = simulate(values)["policies"]
    assert policies["ad_watcher"] == policies["hinter"]


@pytest.mark.parametrize(
    "options",
    [
        Options(levels=0),
        Options(levels=True),
        Options(session_levels=0),
        Options(bonus_per_level=-1),
        Options(iap_slot=6),
        Options(iap_slot=301),
        Options(onboarding=1),
    ],
)
def test_invalid_assumptions_rejected(options):
    with pytest.raises(ValueError):
        simulate(defaults(), options)


@pytest.mark.parametrize("value", [-1, True, 1.5, 2**53])
def test_invalid_and_missing_config_rejected(value):
    values = defaults()
    values["economy.price.hint"] = value
    with pytest.raises(ValueError):
        simulate(values)
    del values["economy.price.hint"]
    with pytest.raises(ValueError):
        simulate(values)


def test_malformed_definition_and_cli_error(tmp_path):
    (tmp_path / "economy.json").write_text(
        json.dumps(
            {"economy.reward.level_complete": {"default": 25, "type": "int", "range": [0, 10]}}
        )
    )
    with pytest.raises(ValueError, match="range"):
        load_defaults(tmp_path)
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools/econ_sim.py"), "--config-dir", str(tmp_path)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 2
    assert "econ_sim:" in result.stderr


def test_cli_outputs_match_library_and_are_byte_reproducible(tmp_path):
    output, markdown = tmp_path / "report.json", tmp_path / "report.md"
    command = [
        sys.executable,
        str(ROOT / "tools/econ_sim.py"),
        "--levels",
        "12",
        "--json",
        str(output),
        "--markdown",
        str(markdown),
    ]
    subprocess.run(command, check=True)
    before = output.read_bytes(), markdown.read_bytes()
    subprocess.run(command, check=True)
    assert before == (output.read_bytes(), markdown.read_bytes())
    expected = simulate(defaults(), Options(levels=12))
    assert json.loads(output.read_text()) == expected
    assert markdown.read_text() == render(expected)


def test_nondefault_income_prices_and_reveal_cost():
    values = defaults()
    values["economy.reward.level_complete"] = 10
    values["economy.price.hint"] = 2
    values["economy.price.reveal"] = 7
    final = simulate(values, Options(levels=20, bonus_per_level=0, onboarding=False))["policies"][
        "hinter"
    ]["final"]
    assert final["hints_used"] == 14
    assert final["reveals_used"] == 1
    assert final["spent_coins"] == 35
    assert final["coins"] == 165


def test_cumulative_integer_overflow_rejected():
    values = defaults()
    values["economy.reward.level_complete"] = 2**53 - 1
    with pytest.raises(ValueError, match="safe integer"):
        simulate(values, Options(levels=2))


def test_each_policy_has_a_complete_markdown_table():
    text = render(simulate(defaults(), Options(levels=12)))
    for name in ("saver", "hinter", "ad_watcher"):
        section = text.split("## " + name + "\n")[1].split("\n## ")[0]
        assert "| Policy | Slot | Coins | Hint items | Chests | Denied tools |\n" in section
        assert "|---|---:|---:|---:|---:|---:|\n" in section
        assert f"| {name} | 12 |" in section
