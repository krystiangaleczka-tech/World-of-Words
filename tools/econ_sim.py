"""Deterministic hypothetical economy policies; no runtime or measured-player evidence."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAX_COUNT = 2**53 - 1
KEYS = {
    "economy.reward.level_complete": 0,
    "economy.reward.double_multiplier": 1,
    "economy.reward.bonus_chest": 0,
    "economy.reward.rewarded_hint": 1,
    "economy.reward.rewarded_coins": 0,
    "economy.grant.onboarding_hints": 0,
    "economy.price.hint": 1,
    "economy.price.reveal": 1,
    "bonus.chest.words_required": 1,
    "unlocks.hint_slot": 1,
    "unlocks.reveal_slot": 1,
    "unlocks.bonus_meter_slot": 1,
    "unlocks.double_reward_slot": 1,
    "ads.rewarded.shop_coins.daily_cap": 0,
    "iap.coins_s.amount": 1,
}
FLAGS = ("ads.rewarded.hint.enabled", "ads.rewarded.double.enabled")
LIMITATIONS = (
    "Synthetic policies and uncalibrated defaults, not playtest or retention evidence. "
    "One session per synthetic day; all requested ads assumed available and permitted. "
    "Bonus discoveries are an assumption; IAP amount is provisional. No P3 daily income. "
    "Insufficient tools never block completion."
)


@dataclass(frozen=True)
class Options:
    levels: int = 300
    session_levels: int = 10
    bonus_per_level: int = 1
    onboarding: bool = True
    iap_slot: int = 0


def validate(values: dict[str, int | bool], options: Options) -> None:
    for key, minimum in KEYS.items():
        value = values.get(key)
        if type(value) is not int or not minimum <= value <= MAX_COUNT:
            raise ValueError(f"Invalid or missing integer default: {key}")
    for key in FLAGS:
        if type(values.get(key)) is not bool:
            raise ValueError(f"Invalid or missing boolean default: {key}")
    for name in ("levels", "session_levels", "bonus_per_level", "iap_slot"):
        value = getattr(options, name)
        minimum = 1 if name in ("levels", "session_levels") else 0
        if type(value) is not int or not minimum <= value <= 10000:
            raise ValueError(f"Invalid scenario option: {name}")
    if type(options.onboarding) is not bool:
        raise ValueError("Invalid scenario option: onboarding")
    if options.iap_slot and not values["unlocks.hint_slot"] <= options.iap_slot <= options.levels:
        raise ValueError("IAP slot must be within simulation and after Hint unlock")


def load_defaults(directory: Path) -> dict[str, int | bool]:
    values: dict[str, int | bool] = {}
    for key in (*KEYS, *FLAGS):
        document = json.loads((directory / (key.split(".")[0] + ".json")).read_text())
        entry = document.get(key) if isinstance(document, dict) else None
        if not isinstance(entry, dict):
            raise ValueError(f"Missing definition: {key}")
        value, bounds = entry.get("default"), entry.get("range")
        if key in FLAGS:
            valid = entry.get("type") == "bool" and type(value) is bool and bounds is None
        else:
            valid = (
                entry.get("type") == "int"
                and type(value) is int
                and isinstance(bounds, list)
                and len(bounds) == 2
                and all(type(bound) is int for bound in bounds)
                and bounds[0] <= value <= bounds[1]
            )
        if not valid:
            raise ValueError(f"Invalid definition/default/range: {key}")
        values[key] = value
    validate(values, Options())
    return values


def simulate(values: dict[str, int | bool], options: Options | None = None) -> dict:
    options = options or Options()
    validate(values, options)
    policies = {}
    for policy in ("saver", "hinter", "ad_watcher"):
        coins = hints = bonus = chests = spent = used_hints = used_reveals = denied = 0
        sources = dict(base=0, bonus=0, double=0, shop_ad=0, iap=0, onboarding_hints=0, ad_hints=0)
        rows = []
        shop_day = -1
        for slot in range(1, options.levels + 1):
            day = (slot - 1) // options.session_levels + 1
            eligible = slot >= values["unlocks.hint_slot"]
            if options.onboarding and slot == values["unlocks.hint_slot"]:
                hints += values["economy.grant.onboarding_hints"]
                sources["onboarding_hints"] += values["economy.grant.onboarding_hints"]
            if slot == options.iap_slot:
                coins += values["iap.coins_s.amount"]
                sources["iap"] += values["iap.coins_s.amount"]
            if policy == "ad_watcher" and eligible:
                if values["ads.rewarded.hint.enabled"]:
                    hints += values["economy.reward.rewarded_hint"]
                    sources["ad_hints"] += values["economy.reward.rewarded_hint"]
                if day != shop_day and values["ads.rewarded.shop_coins.daily_cap"] > 0:
                    coins += values["economy.reward.rewarded_coins"]
                    sources["shop_ad"] += values["economy.reward.rewarded_coins"]
                    shop_day = day
            if policy != "saver" and eligible:
                if hints:
                    hints -= 1
                    used_hints += 1
                elif coins >= values["economy.price.hint"]:
                    coins -= values["economy.price.hint"]
                    spent += values["economy.price.hint"]
                    used_hints += 1
                else:
                    denied += 1
                if slot >= values["unlocks.reveal_slot"] and slot % 10 == 0:
                    if coins >= values["economy.price.reveal"]:
                        coins -= values["economy.price.reveal"]
                        spent += values["economy.price.reveal"]
                        used_reveals += 1
                    else:
                        denied += 1
            coins += values["economy.reward.level_complete"]
            sources["base"] += values["economy.reward.level_complete"]
            if (
                policy == "ad_watcher"
                and values["ads.rewarded.double.enabled"]
                and slot >= values["unlocks.double_reward_slot"]
            ):
                extra = values["economy.reward.level_complete"] * (
                    values["economy.reward.double_multiplier"] - 1
                )
                coins += extra
                sources["double"] += extra
            if slot >= values["unlocks.bonus_meter_slot"]:
                count, bonus = divmod(
                    bonus + options.bonus_per_level, values["bonus.chest.words_required"]
                )
                reward = count * values["economy.reward.bonus_chest"]
                coins += reward
                chests += count
                sources["bonus"] += reward
            if any(value > MAX_COUNT for value in (coins, hints, chests, spent, *sources.values())):
                raise ValueError("Simulation exceeds safe integer counts")
            rows.append(
                dict(
                    slot=slot,
                    session=day,
                    coins=coins,
                    hint=hints,
                    reveal=0,
                    bonus_counter=bonus,
                    chests=chests,
                    spent_coins=spent,
                    hints_used=used_hints,
                    reveals_used=used_reveals,
                    denied_tools=denied,
                )
            )
        policies[policy] = dict(sources=sources, final=rows[-1].copy(), rows=rows)
    base = values["economy.reward.level_complete"]
    return dict(
        schema_version=1,
        assumptions=asdict(options),
        config=values.copy(),
        limitations=LIMITATIONS,
        policies=policies,
        intent_ratios={
            "base_completions_per_hint": (values["economy.price.hint"] + base - 1) // base
            if base
            else None,
            "bonus_chest_hint_equivalent": values["economy.reward.bonus_chest"]
            / values["economy.price.hint"],
            "reveal_hint_price_ratio": values["economy.price.reveal"]
            / values["economy.price.hint"],
        },
    )


def render(report: dict) -> str:
    lines = [
        "# Hypothetical P2 economy simulation",
        "",
        report["limitations"],
        "",
        "Assumptions: `" + json.dumps(report["assumptions"], sort_keys=True) + "`",
        "",
        "Intent ratios: `" + json.dumps(report["intent_ratios"], sort_keys=True) + "`",
        "",
        "| Policy | Slot | Coins | Hint items | Chests | Denied tools |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for name, policy in report["policies"].items():
        for row in policy["rows"]:
            if row["slot"] % report["assumptions"]["session_levels"] == 0 or row == policy["final"]:
                lines.append(
                    f"| {name} | {row['slot']} | {row['coins']} | {row['hint']} | "
                    f"{row['chests']} | {row['denied_tools']} |"
                )
        lines.extend(
            ["", f"{name} sources: `" + json.dumps(policy["sources"], sort_keys=True) + "`", ""]
        )
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config-dir", type=Path, default=ROOT / "game/data/config")
    for name, default in (
        ("levels", 300),
        ("session-levels", 10),
        ("bonus-per-level", 1),
        ("iap-slot", 0),
    ):
        parser.add_argument("--" + name, type=int, default=default)
    parser.add_argument("--no-onboarding", action="store_true")
    parser.add_argument("--json", type=Path)
    parser.add_argument("--markdown", type=Path)
    args = parser.parse_args(argv)
    try:
        report = simulate(
            load_defaults(args.config_dir),
            Options(
                args.levels,
                args.session_levels,
                args.bonus_per_level,
                not args.no_onboarding,
                args.iap_slot,
            ),
        )
        if args.json:
            args.json.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        if args.markdown:
            args.markdown.write_text(render(report))
        else:
            print(render(report), end="")
    except (ValueError, OSError) as error:
        parser.exit(2, f"econ_sim: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
