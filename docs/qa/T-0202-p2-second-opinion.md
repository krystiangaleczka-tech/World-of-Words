# T-0202 — Independent Astra opinion on P2 economy and onboarding

- Reviewer: **gpt-6-astra (Astra)**, independent reviewer, not the author of T-0200/T-0201 and not Claude Opus.
- Date: **2026-10-12 UTC**.
- Audited merged source: **1825d081532565bbec8700608b1f63b101860941** (T-0201 merge), repository `/workspace/wow`.
- Authorization supplied for this review: Chris selected Astra for this checkpoint with **“Astra, tak jak przy wcześniejszym audycie”**. Decision 0010 permits an explicitly owner-selected substitute and the documentation/review sequence through T-0203 before the remaining human gates.
- Deliverable: this standalone opinion only. I changed no tracked repository file, task status, original audit, commit or GitHub state, and delegated no work.

## Verdict

**PASS for the T-0202 DOCUMENTATION second-opinion checkpoint, with the bounded dispositions below carried into T-0203 and the named implementation contracts. No critical or high-severity blocker to completing this documentation wave was established.**

The proposed economy is understandable, optional monetization remains separate from campaign solvability, and the fifteen-slot sequence follows the canonical feature timeline. Most importantly, the proposal explicitly requires durable ownership and atomic publication before attaching money to the P1 implementation. It does not falsely claim those future guarantees already exist.

I recommend accepting the owner's Q2, Q7 and Q15 choices and the economy/teaching direction. T-0203 should record the actual owner disposition of the broader intents and onboarding, and incorporate the short clarifications in the disposition table. This review is not itself an owner decision, approval of final content or visuals, legal advice, native SDK certification, economy calibration, permission to bypass later runtime prerequisites, or a FUN GATE result.

**There is no requirement from this opinion to repair P1 runtime before T-0202 can close.** The implementation requirements below become release/implementation blockers if ignored when the affected P2 capability is built; their present absence is not a fabricated P1 defect. The original T-0142 opinion and its exact audited source remain unchanged.

## Evidence and method

I read AGENTS.md fully, the supplied `/workspace/artifacts/T-0202-review-pack.md`, T-0202/T-0203 task specifications, decision 0010, E11, T-0200/T-0201 QA proposals, and relevant PRODUCT, DESIGN, GAME_DESIGN, ARCHITECTURE, CONTENT, decision 0009 and ROADMAP contracts. I also read the original T-0142 report and inspected current Progress/Save/Level and ads-adapter seams to check the proposal's ownership assumptions against the actual baseline.

Read-only Git checks confirmed HEAD exactly as named above and a clean working tree. Comparing the T-0200 source baseline `0ab3576eeee8a71cded4eab9cbcc624e92184f9d` with the audited HEAD showed five documentation/task files changed and **no changes under `game/` or `pipeline/`**. Source citations in this opinion refer to the audited SHA, not an unspecified future main.

I inspected the actual config files: this P1 checkout has `hint.json` and `unlocks.json`; economy/ads/consent/etc. defaults primarily remain **documented future registry values** in `GAME_DESIGN.md#config-key-registry`. An initial read-only attempt to read an assumed `economy.json` failed because that future file does not exist; subsequent inventory established the actual state. This is not a test failure or a missing-P2 implementation defect. T-0203's defaults list must not suggest every documented default already has a runtime registry entry.

I did not run a new full suite, economy simulation, Godot test selection, native SDK, device test, legal lookup or human vocabulary/playtest session. Full local checks and 12-job CI for T-0200/T-0201 were supplied as author verification, not rerun or independently certified here. Publication checks for the eventual T-0202/T-0203 documents remain their own acceptance work.

## Findings and dispositions

| ID | Severity / checkpoint effect | Finding and minimal disposition |
|---|---|---|
| D1 | **Medium policy ambiguity; no documentation-wave blocker** | Distinguish ATT denial from denial/unavailability of a required purpose permission. T-0203 should state that ATT denial alone can retain the non-tracking ad path **only if the separate ad-purpose/provider conditions permit it**; “non-personalized” is not a universal consent bypass. Carry the actual permission matrix into T-0250/T-0261 and native consent/ad tasks. |
| D2 | **Medium future-contract requirement; no present P1 defect** | Durable ownership is correctly required, but the old architecture sketches and narrow ROADMAP summaries are not executable transaction specifications. Carry the complete candidate/commit/recovery requirements into the future task specifications before their execution; do not reduce them to `grant()` followed by an ordinary shared `Save.flush()`. |
| D3 | **Low intent precision** | “One Hint about every four levels” describes the base completion-income rate, not the total early-game supply or a demonstrated consumption rate. T-0203 should label it accordingly and retain the separate onboarding, bonus, ad and IAP sources in simulation scenarios. |
| D4 | **Low teaching precision** | The new table's slot 14 phrase “completing a location” could imply an early location finish, although locations normally contain 20–50 levels. Change it to “progress toward completing a location”; completion remains manifest-driven. Preserve first-touch hiding of TutorialHand separately from durable first-word completion. |
| D5 | **Medium future-contract requirement; no new exemption approved** | Prompt budget classification and lifecycle remain deliberately unfinished. T-0260/T-0290 must jointly decide/test which presentations consume the budget, including automatic stuck offers/notices and interstitials, without letting inline styling, ad placement, or purchase success create an implicit exemption. |

These findings do not require a new engine, provider, currency, save schema invented in T-0203, or a changed unlock/default. D1/D3/D4 can be made concrete in the existing T-0203 GAME_DESIGN/decision-record scope. D2/D5 should be recorded as mandatory named follow-ups, with future task specifications carrying their acceptance cases. If a later task would contradict a higher-order contract, the planner must reconcile its authorized scope before implementation; this review does not grant executors permission to edit outside their task.

### D1 — Purpose consent and initialization are separate decisions

`GAME_DESIGN.md:244–256` correctly keeps remote collection gated, permits bounded local analytics queuing, leaves crash SDK initialization disabled pending verification, and says UMP/ATT is not blanket analytics/crash permission. This materially improves the safety of the planning baseline. PRODUCT already leaves room for a Q7 override of its older first-launch crash assumption (`PRODUCT.md:341`); recording the selected conservative policy is therefore supported rather than a covert provider replacement.

The sentence “Denial retains the documented non-personalized-ad path” (`GAME_DESIGN.md:250`) follows both UMP and ATT discussion. The canonical specific denial rule refers to **ATT** (`PRODUCT.md:343`; `DESIGN.md:490`). Preserve that distinction. An ATT refusal is not, by itself, a refusal of every separate advertising purpose; conversely, refusing a required advertising purpose is not automatically remedied by removing personalization. Provider/region eligibility must determine whether any ad request may occur. No permission can be inferred merely because a prompt was resolved or not required.

Minimum final wording: **“ATT denial alone permits only a non-tracking ad path whose other required purpose permissions and provider conditions are satisfied. Unresolved or denied required permission keeps the affected SDK/request/telemetry path disabled.”** This is a development constraint, not a claim about verified regional legality.

T-0250/T-0261 and the native tasks must distinguish unknown, granted, denied, not-required and changed/revoked outcomes for each actual collection purpose. Include startup auto-collection, consent refresh, queued-event send/drop, later withdrawal, offline retry and crash SDK auto-init. A resolved UMP enum or ATT authorization cannot be reused as one universal `analytics_allowed` flag. No remote crash collection or crash SDK initialization follows merely from a user consent choice while the separate verification gate is still open.

The selected phrase “external transmission” also needs a purpose inventory before implementation: UMP consent-information requests, remote-config fetches, ads, purchase verification traffic, analytics and crash reports have different functions. The proposal does not prove that all network traffic is silent before consent, nor authorize telemetry to hide inside another provider call. Record the conservative Q7 telemetry policy now; require the provider tasks to explain and verify each actual pre-decision request rather than inventing a global all-network consent API here.

### D2 — The right transaction direction, with necessary proof still ahead

The proposed authoritative Progress autoload, one validated candidate, durable operation records and success-after-commit rule (`GAME_DESIGN.md:226–240`, `#hints`) directly address original Astra Q1/Q4. Current code still creates Progress inside the Level scene (`game/features/level/level.gd:81–84`), holds pending completion in an instance dictionary (`game/services/progress.gd:13,98–110`) and mutates shared Save memory before storage commits (`game/services/save.gd:103–115,140–155`). That is the accepted current free-hint P1 model. It is not evidence of P2 atomicity and not a new money-loss defect in a game that has no real economy yet.

The acceptance invariant should be: **after reload, the operation is absent with its previous economic/progress state, or present exactly once with all related changes; retry, another owner, screen replacement and duplicate callback cannot produce a partial or second outcome.** Merely moving pending memory into an autoload solves screen lifetime, not process lifetime or ambiguous commit outcomes.

Before paid/grant integration, T-0229/T-0232/T-0241/T-0242 must establish candidate validation, serialization of competing operations, committed versus pending read visibility, restart recovery, stale board/language rejection, and post-commit notification handling. Preserve section ownership from `ARCHITECTURE.md#autoloads` and `#save`: authoritative Progress is not permission to bypass Economy's balance rules or Save's ownership. An economy journal bounded to 200 entries is not sufficient durable deduplication authority; required processed transaction/operation identities must outlive ordinary journal trimming.

T-0261/T-0271/T-0278/T-0280/T-0281 then need focused fault cases, not only successful-path tests:

- Paid Hint/Reveal: validate the target and funds together; pair debit/item consumption with reveal, crossing-word completion and any resulting completion reward. Failed commit publishes neither a successful charge nor reveal; double taps and stale screen callbacks cannot charge twice.
- Campaign/onboarding/bonus: bind a stable operation identity to the correct campaign/content scope; grant completion and one-time onboarding items once; preserve bonus surplus and previously credited history across removal/re-addition. A historical P1 found-bonus string is not authority to mint coins retroactively.
- Competing writers: fail a commit, destroy/recreate the screen, flush another owner, and reload from disk. Also test committed state with the success notification lost. Keeping the same instance alive in a test does not prove this boundary.
- Rewarded: persist/correlate the offer, placement, reward terms and credited outcome; accept only the corresponding earned callback. Current `game/platform/ads/ads_adapter.gd` has a no-argument `reward_earned` signal, so correlation must be designed and proven through the owning service/native contract. Duplicate, late, wrong-placement, close-before-earned and earned-before-close callbacks need explicit handling. Do not erase a genuine earned reward merely because a screen closed or a later close/error notification arrived.
- IAP: use verified StoreKit `Transaction.id` or Play `purchaseToken`, never `orderId`; durable grant/entitlement plus processed identity precedes finish/consume/acknowledge. Handle pending/deferred, duplicate/unfinished startup recovery, restore of non-consumables, and process death between each stage. A native plugin that automatically finishes too early cannot satisfy this by adding a GDScript flag afterward.

A lost rewarded callback during process death is a particularly important provider boundary: local intent persistence cannot manufacture proof that the ad was earned. T-0261/native QA must state the provider's recovery capability and the user-visible failure policy; do not promise universal exactly-once reward delivery from fake callback tests alone. Store unfinished transactions have a different recovery mechanism and must not be conflated with rewarded ads.

### D3 — Economic plausibility and the limits of arithmetic

The documented numbers are internally intelligible (`GAME_DESIGN.md:179–210,411–455`):

| Relationship | Arithmetic at documented starting values | Interpretation |
|---|---|---|
| Base completion income versus Hint | 25 × 4 = 100 | One purchased Hint per four completions from this source alone. |
| Rewarded Hint / free Shop coins | 1 item / 100 coins | Each is approximately one Hint; coins retain spending choice. |
| x2 completion | Base 25 becomes total 50 | Incremental ad reward is 25, not another 50 and not one whole Hint. |
| Chest | 10 credited bonus words → 100 coins | One Hint value; two-session cadence is unmeasured. |
| Reveal | 250 / 100 = 2.5 | Cost ratio, not proof that one revealed word has 2.5 times the player value. |
| Small coin pack | 1000 / 100 = 10 | Ten Hint purchases at baseline; amount/store price remains Q6 work. |

Early supply is intentionally more generous than the first ratio suggests: completing slots 1–6 supplies 150 coins before Hint becomes available at current slot 7, and the onboarding grant adds three Hint items. Bonus rewards can add more. This does not refute the base-rate target, but it means “all no-ad/no-pay users consume one Hint every four levels” would be the wrong success criterion. Likewise, a chest every two sessions depends on session definition, level count and voluntary bonus discovery; a player who never finds bonuses need not receive a timed consolation chest.

T-0203 should accept these as starting hypotheses. Future `econ_sim`/T-0237 work must separate no-spend saver, moderate/heavy hint use, bonus discovery, opt-in ads and purchases; report inventory as well as wallet, initial grant versus steady state, and P2 sources only. A mathematically solvable level does not establish that a stuck player experiences a fair non-paying path. That needs the retained vocabulary/outsider/feel evidence, not an economy spreadsheet.

The P2 catalog is correctly limited to `nc.remove_forced_ads.v1` and `c.coins_s.v1`; larger packs, starter pack, daily and streak remain P3 (`PRODUCT.md#iap-catalog`, `GAME_DESIGN.md:217–219`, T-0200 QA). Remove Forced Ads must include full-screen own-offer interstitials, remain restorable, and leave player-requested rewarded actions optional. No store ID creation, amount/price approval or native restore proof is supplied here.

## Fifteen-slot teaching assessment

The proposal covers every slot and correctly treats its table as future T-0305 authoring rather than a description of the current 65-slot prototype (`GAME_DESIGN.md:315–357`; T-0201 QA).

| Slots | Assessment |
|---|---|
| 1 | Three letters and one/two familiar answers is a reasonable first gesture. Only board/preview/wheel teaching; first acceptance must come from actual player solving. UMP remains after completion, where required. |
| 2 | Shuffle with multiple answers teaches that wheel order is incidental. “Several” is a content feasibility target: under the three-letter minimum, source rules and repetition constraints, do not pad this board with obscure anagrams just to meet the row. |
| 3–4 | Four letters, repeat-word feedback and backtracking consolidate the loop without a new forced action. ALREADY_FOUND need not be manufactured by requiring a duplicate submission. |
| 5–6 | An obvious optional bonus is a useful introduction. A player can finish without discovering it; the meter coach must remain pending until a later eligible visible target, not force replay or invent an event. ATT remains after slot 6, not before gameplay. |
| 7–9 | Three free Hint items plus optional tools allow learning without compelled spend/ad viewing. Coins and Shop introduce several ideas at once; retaining only one Hint coach and quiet follow-up levels is appropriate. |
| 10–11 | Home/Journey becomes available when slot 10 becomes current; Continue after completion introduces Home once. Returning at current slot 10 can already route to Home under existing DESIGN rules. Persisted introduction state must prevent repeated forced routing. |
| 12 | Reveal, optional x2 and likely first postcard piece coincide. Separate optional actions and no extra x2 coach keep the load bounded, but actual comprehension requires playtest evidence. “Near 12” assumes accumulated stars in the first manifest location; it is not guaranteed by a timer. |
| 13–15 | Consolidation with up to five letters, no landmarks and no P2 Daily/streak is coherent. Slot 14 should describe progress toward location completion, not require a location endpoint at 14. |

Letter count alone does not control difficulty. T-0305 must use the licensed/curated source, familiar answers, complete bonus lists, valid connected geometry, spacing/deduplication and human review (`CONTENT.md#hand-made-levels`, `#hard-validation`, `#qa-sampling`). No example word should bypass these rules because it fits a teaching script. Released-slot immutability and the explicitly different closed-test slot policy remain intact (`CONTENT.md:254–270`).

The proposed PL/EN captions are short, action-specific and avoid plural-sensitive numeric sentences. They use existing highlighted targets and inline CAPTION treatment, not new components. Approval here is of copy direction, not visual legibility, layout, translation completeness or a finished tutorial animation.

### First-word and coach lifetime

Accepted LEVEL or BONUS is an appropriate durable first-word milestone; UNDER3, INVALID, cancellation and duplicate-only actions are not. Hints or debug completion must not be substituted for actual player discovery. The proposal explicitly requires later save/onboarding contracts, which is the right boundary.

Preserve the more precise existing animation rule in `DESIGN.md:316–317`: TutorialHand hides on the first touch so it does not compete with the active gesture, while first accepted word determines permanent completion. “Until the first word” must not be interpreted as leaving the moving hand on top of a player's drag. T-0290/T-0291 should specify what returns after an invalid/canceled attempt, reopening, and persistence failure without resetting a legitimately completed tutorial.

Once-per-feature coaching is not simply “set seen on unlock.” Unlock, visible target, presentation, dismissal/timeout and durable seen state differ. Queue a coach behind consent/completion, avoid off-screen targets, pass through the dismissing tap to its intended action, cancel stale bindings on navigation, and define recovery after interruption. These are required T-0229/T-0290 acceptance cases; the current documentation does not claim the state machine is implemented.

### D5 — Prompt budget and commerce eligibility

The proposal correctly preserves the only explicit exemptions: consent/ATT and coach marks (`PRODUCT.md:304–306`; `GAME_DESIGN.md:347–355`). One permitted non-gameplay prompt is a cap, not a quota to fill. It must not block requested navigation or manufacture a modal before gameplay.

Before runtime integration, T-0260/T-0290 must supply a shared classification table and session-reset policy. In particular, a once-per-level “Need a hint?” offer is still an automatic offer; calling it inline does not automatically exempt it. Conversely, a player explicitly opening Shop or requesting an available rewarded action must not be silently blocked by a passive-prompt counter. Classify these cases explicitly, and reconcile interstitials with both their spacing/grace rules and the stated non-gameplay budget. Failure/no-fill must not consume economic rewards or produce repeated prompts.

Retain purchase grace and owned Remove Forced Ads restrictions, including own-offer prompts. Define when an eligible prompt consumes the budget and what happens on background/restart; test cap zero, already-used cap, pending consent, an interrupted prompt and an explicit user action. Do not let each screen implement a private interpretation.

## Owner choices and alternatives

| Question | Actual owner input supplied for this review | Independent recommendation |
|---|---|---|
| Q2 | Always one star, independent of hints. | **Accept.** A no-hint bonus would make help reduce progress and complicate postcard pacing. Keep the fixed baseline and no Hint/Reveal penalty. The generic registry range is not approval to turn on a no-hint modifier. |
| Q7 | External transmission only after appropriate consent; crash SDK disabled pending legal/provider verification. | **Accept with D1 clarification.** This is preferable to assuming first-launch legitimate-interest crash collection is already verified. Neither provider selection nor this owner choice supplies legal or SDK evidence. |
| Q15 | EN UI only as a debug option for closed testers, while level content stays PL. | **Accept.** Waiting for EN content would also be safe but would defer UI testing; release-wide EN UI with only PL content is not the selected option. Debug UI locale must not select an absent EN manifest or change campaign identity. |

Q15 is compatible with the existing explicit debug exception (`PRODUCT.md:349,356`; `DESIGN.md:483`). The release setting still couples UI/content as specified; debug UI override needs its own contract semantics without inventing a new autoload or public API in this planning task. T-0229/T-0241/T-0287 should test toggle/restart/navigation with absent EN content, PL progress intact, and no extra onboarding grant or coach reset from a UI-locale change.

The repository still contains proposal-era metadata such as E11's “open choices” and decision 0010's proposed reviewer language. Historical proposal text need not be rewritten as if it had always known the answer. T-0202/T-0203 should plainly state the actual selection and final decision provenance so later readers do not mistake these older labels for missing owner input.

## Minimal T-0203 closure record

1. Record the actual Q2/Q7/Q15 choices above and Chris's disposition of the **broader economy intents and fifteen-slot plan after this opinion**. Existing explicit choices need not be asked again unless changed; neither a model recommendation nor a preselected option supplies a missing broader decision.
2. In GAME_DESIGN, apply D1's ATT/purpose distinction, D3's base-income interpretation and D4's slot-14/first-touch precision. Record D2 and D5 against their named future contracts with the acceptance boundaries above. No runtime registry, generated content or schema change is required by this opinion.
3. List canonical unlock defaults separately from economy starting values and future runtime registry implementation. Keep one fixed star, 25 base coins, 100 Hint price, 250 Reveal price, three onboarding Hint items, 10-word/100-coin chest, and existing ad/catalog defaults as the reviewed baseline rather than newly measured or newly store-approved values. Preserve Q6 and the documented P2/P3 split.
4. Carry open human FUN/device/word/outsider gates, native/legal verification and future visuals/content/simulation explicitly. Completion through T-0203 is the owner-authorized documentation exception only; it does not itself release or freeze a later runtime wave.

**Final disposition: PASS for this independent documentation review.** Attach the actual report with its model/source provenance, preserve the original T-0142 audit, complete the bounded T-0203 owner disposition and publication checks, and retain the implementation/native/human gates as separate evidence requirements.
