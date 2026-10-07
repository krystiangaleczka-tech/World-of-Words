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
