# T-0203 — Owner disposition of P2 planning

Date: 2026-10-12 UTC. Documentation only under [decision 0010](../decisions/0010-p2-planning-order.md).

## Decision provenance

Chris requested work through T-0203 ("Rób do 203", "Rob moja decyzja") and explicitly submitted these choices; they are not inferred from preselected answers:

| Question | Actual owner answer | Accepted development disposition |
|---|---|---|
| Q2 | "Zawsze 1 gwiazdka, niezależnie od podpowiedzi" | Fixed one star per completed campaign level, no no-hint bonus or Hint/Reveal penalty. |
| Q7 | "Zdalna wysyłka wyłączona do odpowiedniej zgody; crash SDK domyślnie wyłączony do weryfikacji" | Remote analytics/crash telemetry requires appropriate purpose permission. Local analytics queuing may precede the decision; crash SDK also remains disabled until separate legal/provider verification. |
| Q15 | "Tylko opcja debug dla testerów; polska treść gry pozostaje PL" | Debug-only EN UI for closed testers; content/campaign stays PL, no absent EN manifest or progress/grant reset. |

Chris selected Astra independently for T-0202. The [original second opinion](T-0202-p2-second-opinion.md) is gpt-6-astra's actual PASS on source `1825d081532565bbec8700608b1f63b101860941`, for a documentation checkpoint only. After receiving the PASS and the request to accept the broader plan, Chris instructed: **“Nie pytaj o pozwolenie ja decyduje Rób kolejne 5 taskow”**. This is the owner’s direction to accept the reviewed plan with the bounded clarifications and continue. No repeated approval is required.

## Review dispositions

| Finding | Disposition / required follow-up |
|---|---|
| D1 | GAME_DESIGN distinguishes ATT denial from purpose denial: non-tracking ads require all other applicable permissions/provider conditions. Unknown/denied required permission disables affected path. T-0250/T-0261/native tasks must inventory purposes/pre-decision requests and test granted/denied/unknown/not-required/revoked, startup auto-collection, queue send/drop and retry; UMP/ATT is no universal telemetry grant. |
| D2 | Mandatory T-0229/T-0232/T-0241/T-0242 transaction specifications before paid/grant integration: one validated durable candidate, competing-writer serialization, committed/pending visibility, restart and stale-board/language rejection, lost notification recovery. Reload shows the old state or exactly one complete operation. Durable processed IDs survive bounded journal trimming. T-0261/T-0271/T-0278/T-0280/T-0281 must test duplicate/late/wrong callbacks, screen destruction/other-owner flush, failed/ambiguous commit, completion/bonus/onboarding grant dedup and IAP grant-before-finish/consume/acknowledge. Rewarded provider recovery limitations require explicit native evidence/failure policy, never invented earned proof. |
| D3 | Four completions per Hint describes base coin income only (25×4=100), not total early supply or measured consumption. T-0237 simulation distinguishes onboarding inventory, bonus discovery, saver/heavy tool users, ads and IAP; chest session cadence remains a hypothesis. |
| D4 | Slot14 means progress toward completing a location; manifest determines endpoint. TutorialHand hides on first touch; actual first accepted LEVEL/BONUS permanently completes teaching. T-0290/T-0291 must define invalid/canceled/reopen/persistence-failure behavior and once-per-visible-feature coaching. |
| D5 | Mandatory joint T-0260/T-0290 prompt classification/lifecycle specification before integration. Consent/ATT/coaches are the only existing exemptions; inline automatic offers/interstitials gain none implicitly. Test zero/used cap, interrupted prompts, restart/background, purchase grace/entitlement and explicit user actions. |

D1/D3/D4 are documentation clarifications. D2/D5 are retained implementation requirements, not completed P1 fixes. Future task specifications must carry these acceptance cases before execution; this record authorizes no out-of-scope edits.

## Defaults and starting values

No config table, key name, range or runtime registry changes. Canonical defaults: Shuffle2, Bonus5, Hint7, Journey10, Reveal/double12; UMP after1, ATT after6, first eligible interstitial16. Daily15 remains P3. Runtime must read keys rather than hardcode this timeline.

Reviewed baseline starting values: one star; base25 coins; Hint100, Reveal250; onboarding3 Hint items; chest10 credited bonus words/100 coins; rewarded1 Hint or100 Shop coins, Shop cap3/local day; x2 multiplier2 applies only to base completion reward. Ad spacing4 levels/180seconds, session grace120seconds and purchase grace10levels; prompt cap1; postcard4pieces/12stars; journal200entries, analytics queue500events. Full names/types/ranges and remaining defaults remain in GAME_DESIGN's unchanged registry table. These are uncalibrated values, not proof of FUN, affordability or retention. The selected one-star rule forbids a no-hint modifier despite the generic registry range.

Existing runtime files include hint.json and unlocks.json; economy/ads/consent and other P2 values above are documented future registry values, not all implemented files. P2 catalog remains nc.remove_forced_ads.v1 and c.coins_s.v1; iap.coins_s.amount=1000 and store prices remain Q6 starting-value/approval work. Larger packs/starter pack, daily/streak remain P3. No products, native SDKs or prices are created/approved here.

## Evidence bounds and remaining gates

This disposition supersedes T-0200/T-0201 proposal wording and historic E11/decision0010 preparation labels. Original T-0142 audit remains unchanged. Runtime transaction/native/provider/legal verification, economy simulation, visual/content implementation and human FUN/device/word/outsider evidence are still separate gates; no new phone/playtest evidence is claimed. Completion through T-0203 does not release or freeze the later runtime wave.
