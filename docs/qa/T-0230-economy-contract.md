# T-0230 pure economy values

WalletSnapshot is an immutable pure value: safe integer coins and Hint/Reveal inventory,
strict deserialization, independent snapshots, atomic grant/spend and full-request affordability.
JSON integral floats are accepted only on deserialization; transaction amounts are int only.
Empty/no-op, negative, unknown, fractional, bool, insufficient or overflow requests fail without
partial changes. MAX_SAFE_COUNT is the JSON exact-integer bound, not a balance tuning value.

RewardTable reads nine canonical injected config keys; test values deliberately differ from
starting hypotheses. Prices, source rewards and the level-only double multiplier come entirely
from injection. Multiplication is checked before arithmetic; unknown/unconfigured requests
return no reward. Config registry expansion is T-0234. Daily is a future P3 table entry only.

This task defines executable value/arithmetic contracts; T-0231 adds mutable reasoned ledger and
bonus chest carry-over. Services alone later own persistence/journals/events. No running game uses
these values yet, so no balance/save/UI changes. Pure core has no Node/Time/I/O/service imports.

Five tests cover deep isolation, integral JSON roundtrip, exact atomic mixed grant/spend,
invalid values and safe overflow, injected prices/all source rewards, level-only multiplier,
malformed config and immutable reward output. Pinned4.7.2 GUT431/431 and full make check, fresh
exact-head reviewer/checklist, task/scope lint and13CI required before sequential squash merge.
