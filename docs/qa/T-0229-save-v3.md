# T-0229 Save v3

The additive v2→v3 migration preserves wallet/items/journal, processed purchases, identity,
settings, language progress, board snapshots and extensions. Legacy bonus/coach values seed
new owner fields; conflicting already-present values are rejected, not silently overwritten.
Per-language stars/pieces remain Progress-owned, with postcards/unlocked lists added. Save-owned
meta holds coach marks and onboarding step. Entitlement remains remove_forced_ads; dedup keys
remain processed_transactions, never trimmed. The consent dictionary remains opaque to Save.

Legacy progress bonus/coach/unlock fields remain compatibility state; P2 owners must switch in
T-0232/T-0241/T-0280. No new runtime rewards or duplicated transaction execution. Historical opaque
shop-cap maps are preserved under shop_coins_ads.legacy; unparseable historical interstitial values
stay untouched in last_interstitial with new timestamp null. New canonical timestamp/slot counters
are nonnegative safe integers. Unknown inventory keys survive as nonnegative counts, not discarded.

Seven new tests cover goldens, immutable deep copies, earned wallet/item preservation, multiple
languages, purchase preservation, opaque legacy values, conflicting fields, malformed old documents,
JSON numeric canonicalization and migration flush interruption/retry/backup/reload. Historical
v1/v2 goldens are unchanged; v1→v2 exact test stays explicit while current-version validators use
migrated fixtures. Temp recovery asserts current VERSION; custom future-chain test tracks VERSION+1.
No existing storage/assertion coverage removed. Debug reset still preserves meta/settings/purchases.

Pinned4.7.2 GUT426/426, full make check, scope/task lint, fresh exact-head independent review and
13CI required for merge. Schema downgrade is unsafe: rollback must preserve v3 read support;
existing atomic-write backup keeps old original during migration flush. No SDK/secrets/device work.
