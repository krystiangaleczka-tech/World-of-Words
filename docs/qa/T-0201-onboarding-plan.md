# T-0201 — Fifteen-slot teaching proposal

Source baseline: 60ee60fb15935642f7739667450d7ac50a446a23 (T-0200). This is a specification, not newly authored first15 levels or a measured onboarding result. PRODUCT first-ten-minutes defaults and DESIGN existing component/copy rules are canonical. Owner Q15 input and the broader proposal receive the independent T-0202 opinion before final T-0203 disposition.

## Proposed coach copy

| Key | Target | PL proposal | EN proposal |
|---|---|---|---|
| level.tutorial.connect | TutorialHand / inline CAPTION, slot1 | Połącz litery, aby ułożyć słowo. | Connect letters to make a word. |
| onboarding.coach.shuffle | IconButton(shuffle), slot2 | Przetasuj litery. | Shuffle the letters. |
| onboarding.coach.bonus | BonusMeter, first eligible bonus from slot5 | Dodatkowe słowa wypełniają licznik bonusu. | Extra words fill the bonus meter. |
| onboarding.coach.hint | HintButton(hint), slot7 | Podpowiedź odkrywa literę. | A hint reveals a letter. |
| onboarding.coach.journey | Journey NavTab, first Home after slot10 | Zobacz swoją podróż i pocztówki. | See your journey and postcards. |
| onboarding.coach.reveal | HintButton(reveal), slot12 | Odkryj całe słowo. | Reveal a whole word. |

These are future translation-key proposals, not raw runtime strings or new locale files. No numeric/plural-dependent sentences. Use existing highlighted target + inline CAPTION; any tap dismisses, or Motion.TOAST_HOLD x2 ends it. Coins pill and x2 reward button receive no extra coach. User must choose an ad explicitly; ad-badge visibility is not a grant or SDK readiness proof.

## Content and event boundaries
The full slot1..15 table is in GAME_DESIGN onboarding. Slot1 has three letters/one-two common answers; slot2 three letters/multiple answers; slots3..4 four letters; slot5 an obvious optional bonus; slots6..15 grow gradually to at most five letters with no landmarks. T-0305 authors the actual YAML against reviewed source evidence and validates it; current content pack bytes are unchanged. A bonus or paid tool is never necessary to finish.

Tutorial hand ends on a first accepted LEVEL/BONUS word. UNDER3, invalid, cancellation and a duplicate alone do not invent first-word completion. Preserve actual player-solving distinction from debug completion. Each eligible feature is coached once with persisted state; only the existing onboarding_step event name is referenced, with its typed registry implemented by its planned task. No new event or invented parameters are registered here.

At current slot10 Home/Journey become available; after completing10 Continue introduces Home once. Return follows saved campaign state and later navigation contracts. Postcard-star progress may reveal the first piece near12 with current defaults; this is feedback, not a new prompted tutorial or proven device timing. Reveal and x2 remain separate optional actions.

## Privacy, prompts and language
UMP is after1 when required, before ads SDK init; iOS ATT after6 uses UMP IDFA explainer, no custom pre-prompt, no ad request before ATT resolves. These and inline coach marks are the explicit prompt-budget exemptions. Other non-gameplay offers/rating/notices respect onboarding.max_prompts_per_session=1; do not add exemptions or stop requested navigation. Queue coaching behind consent/completion rather than overlap it. Future ad-policy/onboarding contracts define/test classification and session reset.

Owner selected Q15: debug-only EN UI for testers with PL level content. Language selector must separate UI locale from content/Save campaign language; toggling UI may not pick a missing EN manifest or reset/advance another campaign. No current Nav/Locale/Save API is changed; required contracts precede actual wiring. Daily/streak remain P3 even though unlocks.daily_slot=15 exists in the canonical table.

## Required validation before runtime acceptance
- Human word familiarity and first-word discovery; no simulated outsider results.
- Once-per-feature, hide-before-unlock, explicit dismissal, timeout, queued consent/coaching, and all prompt-budget conditions.
- Failure/retry, restart around first-word/unlock/onboarding grant, stale screen binding and no duplicate economic grant.
- Real low-end gesture/feedback and submission/persistence frame; headless tests do not certify feel.
- UI/content-language independence and absent EN content; review all required locale keys before release.

These are future implementation/device checks, not results supplied by T-0201. This proposal creates no components/scenes, changes no token values and supplies no visual approval for T-0204/T-0205.
