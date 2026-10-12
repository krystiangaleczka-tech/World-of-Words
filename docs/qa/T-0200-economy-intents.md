# T-0200 — P2 intent proposal

Source baseline: 0ab3576eeee8a71cded4eab9cbcc624e92184f9d. Owner explicitly authorized planning through T-0203 under decision0010. This task updates documents only; P1 runtime, keys/default files, schemas and generated content are unchanged.

## Intent and default disposition

| Intent/source/sink | Existing key/default | P2 treatment |
|---|---|---|
| No-ad/no-pay player Hint about every four levels | reward.level_complete=25; price.hint=100 under economy | Calibration target, not a simulation result |
| Rewarded Hint / free Shop coins about one Hint | economy.reward.rewarded_hint=1; rewarded_coins=100 | Explicit opt-in placements, durable callback grant only |
| Optional x2 campaign reward | economy.reward.double_multiplier=2 | Base level reward only; separate from one-Hint ad target |
| Bonus chest about two sessions / one Hint | bonus.chest.words_required=10; economy.reward.bonus_chest=100 | Validate against actual sessions; persistent surplus, no duplicate grant |
| Reveal about 2.5 Hints | economy.price.reveal=250 | Atomic debit/reveal ownership required |
| Hint onboarding grant | economy.grant.onboarding_hints=3 | One-time at unlocks.hint_slot=7; durable identity |
| Stars | meta.stars.per_level=1 | Owner selected fixed one regardless of hints; final E11 disposition T-0203 |
| Daily | economy.reward.daily=100 | P3 only, not a P2 source |

All listed short reward/price names are existing economy keys, never newly invented registry fields. Full key names/ranges/default provenance remain in GAME_DESIGN config registry; no runtime registry edit is made. Intent hypotheses do not imply calibrated affordability, session length or retention.

## Catalog and policy boundaries
P2 products are exactly nc.remove_forced_ads.v1 (restorable non-consumable) and c.coins_s.v1 (consumable). c.coins_m.v1, c.coins_l.v1 and c.starter_pack.v1 remain P3. iap.coins_s.amount=1000 is an existing Q6 starting value, not a newly approved store price or product creation. Store consoles/native verification remain future tasks.

Canonical consent/unlocks remain: UMP after1, ATT after6, Shuffle2, Bonus5, Hint7, Journey10, Reveal/double12, Daily15 in P3, first eligible interstitial16. Existing spacing/grace/purchase conditions and prompt budget remain; no ad/commerce at launch and no offer after a purchase inside its grace window.

## Actual owner inputs, separate from final disposition
On 2026-10-12 Chris explicitly selected fixed one star (Q2), external transmission only after appropriate consent with crash SDK disabled pending verification (Q7), debug-only EN UI with PL content (Q15), and Astra for T-0202. Inputs are not inferred from a preselected option. T-0201 details UI/content separation; T-0202 independently reviews the whole proposal; T-0203 applies final E11 disposition and review findings.

Q7 is a development policy, not a verified legal basis. Purpose-specific consent must be mapped by provider/native tasks; UMP/ATT is not blanket permission for analytics/crash data. Existing analytics send/drop queue rules remain. The original Astra audit is unchanged; P2 ownership/atomicity/native evidence requirements are retained in the GAME_DESIGN proposal.
