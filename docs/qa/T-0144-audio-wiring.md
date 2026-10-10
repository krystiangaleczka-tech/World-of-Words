# T-0144 — P1 event audio

Boot owns a nonglobal Audio listener alongside the existing haptics subscriber.
It maps tile_touched/word_found/bonus_found/already_found/invalid_word/level_completed
to the six preloaded registry cues. It disconnects replaced buses and exit,
reattaches once on reentry and respects Audio's live mute/volume. Hint has no
new sound. No gameplay, persistence, new Events or analytics contract changes.

Real Level input/controller tests exercise tile, valid, bonus, repeat, invalid
and complete effects. Short attempts and completed-board resubmissions remain
quiet. In-memory persistence failure prevents success/completion sounds; an
explicit retry publishes each effect once. Completion and valid-word cues follow
the existing controller publication order; the bounded voice pool supports both.
Real boot input proves its listener is attached. Every existing Level CSV entry
resolves in PL/EN, and the actual Level HUD updates when the locale changes.
No new player-facing text, component or final sound direction is introduced.

Audible/device comfort is unperformed human QA; headless accepted-cue assertions
are not a speaker assessment. T-0051/T-0136 human gates remain open.

Full make check passed: 218 GUT / 8,524 assertions,199 pipeline,87 tools tests;
registry/content checks green. Task/scope lint pass.
Fresh independent review approved 812e8784631fd8cebf4f9483a60342dc5f32edb2; no blockers.
