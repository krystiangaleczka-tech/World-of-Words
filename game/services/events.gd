extends ServiceStub
## @api Side-effect notifications only; never controls gameplay or persistence.

## @api No usable primary/temp/backup existed; Save started a clean in-memory document.
signal save_corrupted
## @api Haptic/audio side-effect notifications; these signals never control gameplay or analytics.
signal tile_touched(index: int)
signal word_found(word: String)
signal bonus_found(word: String)
signal already_found(word: String)
signal invalid_word(word: String)
signal level_completed(slot: int)
signal hint_used

## @api Analytics transmission decision for the current launch. The first emission resolves the
## unknown state; later emissions update consent and false also represents revocation.
signal consent_changed(analytics_allowed: bool)

## @api Publish copied transaction and wallet values only after durable Economy success.
## Side effects only; listeners must not control the transaction.
signal economy_changed(
	operation: StringName, reason: StringName, amounts: Dictionary, snapshot: Dictionary
)

## @api Durable per-language meta effects. Listeners never control completion or rewards.
signal stars_earned(language: String, slot: int, stars: int)
signal postcard_piece_revealed(language: String, location_id: String, pieces: int)
signal location_complete(language: String, location_id: String)
signal feature_unlocked(language: String, feature: StringName, slot: int)

## @api A durable onboarding step (OnboardingState step ids); analytics maps it to onboarding_step.
signal onboarding_step_reached(step: int)
