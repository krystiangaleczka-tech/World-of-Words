# Durable bonus progress — T-0338

T-0280 may explicitly call Progress.configure_bonus_progress only for a ready real
P2 owner. Default P1 and pre-activation P2 checkpoint behavior remain unchanged.
After opt-in, Progress.save_level registers a campaign_checkpoint request for the
actual current bound incomplete board. Save validates both Progress and Economy
approvals and persists board, counter and proof together. There is no bonus_found
side-effect grant and no separate flush as proof.

The closed request adds checkpoint:{before,after}; operation identity is
campaign_checkpoint:<language>:<slot>:<SHA256 before>:<SHA256 after>.
Both snapshots use current LevelData and preserve previous words/cells/retired
bonus credits. New retired bonus words, backwards or foreign boards and extra
commands fail. The same owner board, content, config, lineage, baseline and exact
snapshot are revalidated before the final write. No-op checkpoints do not write.
An unresolved checkpoint retains its request and original approved candidate.

Economy counts only newly found current bonus words after the meter unlock, using
the committed before snapshot. Crossing the target does not redeem mid-level.
Existing pre-activation saved bonus words are not backfilled: their credit history
is unknown. Older historical words remain preserved and cannot create new credit.

At ordinary or paid final completion the canonical Economy command list includes
all full bonus groups. Counter remainder, coin grant, ordinary rewards, progress
and paid debit when present form one candidate. Debit precedes rewards, so chest
coins cannot finance an unaffordable tool. Zero configured chest reward still
consumes full groups. Safe-integer counter, multiplication and wallet overflow
reject the whole candidate. The v4 JSON bound uses an explicit conversion of the
existing integer MAX_SAFE_COUNT; its former decimal float literal under-accepted
the top safe integer in the pinned engine. No documented range or v3 reader change.

The live Economy.bonus_chest_redeemed(chests, coins) signal is presentation only.
It is derived from the original registered Economy approval matched to an issued
Save receipt and emitted once under Save's write barrier, including zero coins.
It never authorizes a reward. Historical receipt recovery after restart does not
invent live settlement metadata or replay this presentation signal. Wallet grants
remain durable in the receipt and ordinary canonical journal notifications.

Issued target/reward policy freezes once the first write starts, following T-0337.
Pre-write configuration changes reject; subsequent distinct operations requote.
The save format stays v4 with eleven-field receipts and an additional accepted
operation namespace. Never delete proofs. Disabling the feature keeps its reader;
older builds without the namespace are unsupported downgrades once it is persisted.
Boot/Nav activation, UI and physical power-loss certification remain separate.

Evidence: test_bonus_transactions exercises real owners and disk storage, all five
interruption points before constructing fresh restart owners, replay/no-op, locked
and historical bonuses, partial/final and paid retry, zero/multiple payout, issued
policy stability, safe-int overflow and final-boundary board mutation. Full check,
independent review and exact-head CI receipts are recorded in the PR.
