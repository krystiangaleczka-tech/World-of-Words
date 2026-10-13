# T-0235 Synthetic economy simulation

Three reproducible 300-level policies expose source totals and per-slot wallet/inventory.
Sessions, bonus discovery, tool requests and fully available permitted ads are explicit assumptions.
Base rewards apply to every completion (FR-ECON-05); only tool availability/UI is unlock-gated.
Onboarding, bonus, rewarded and optional small IAP sources remain separately reported.
No daily rewards or live config changes. CLI documents base-only and optional IAP scenarios.

Validation: 20 tests cover exact small arithmetic, gates, item priority, bonus carry-over,
nondefault prices/income, disabled ads, one-per-day Shop policy, x2 isolation, IAP,
malformed inputs and safe-count overflow, byte-repeatable JSON and Markdown.
Full make check passed; task and scope checks precede commit. Generated reports are hypothetical,
not device/player evidence. One production Python file; test coverage exceeds approximate line budget.

Usage: uv run python tools/econ_sim.py --json report.json --markdown report.md
Base-only: add --no-onboarding --bonus-per-level 0 (saver policy has only base income).
