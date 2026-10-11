# Polish word difficulty — Chris's playtest feedback

Recorded: 2026-10-11. Source: Chris's Android prototype playtest and follow-up.
This is product-owner feedback for a future content task, not an implemented
pipeline rule or a replacement for the accepted source-of-truth documents.

## Desired opening experience

The first levels should be easy because the words are familiar and immediately
recognizable, not merely because the wheel has few letters. Chris explicitly
accepts opening levels with words such as **WODA** and **DWA**. Familiar short
words are welcome; shortness alone does not establish lexical difficulty.

Less obvious inflected forms should not be required answers in trivial opening
levels. Chris gave these contrasts as examples:

| Familiar form | Less obvious form to introduce later |
|---|---|
| RYBA | RYB |
| KURA | KUR |
| KOSA | KOS |

These examples describe the player's perception, not an instruction to ban the
forms or automatically classify every matching spelling as an inflection.
Morphological evidence must distinguish independent lemmas and ambiguous forms.
For example, KOS can also be a familiar bird name. Such cases need editorial
review rather than a blanket suffix rule.

## Additional example: JAR in prototype slot 65

Chris questioned **JAR**, a required answer alongside RAJ in slot 65, and rated
it as very difficult: a candidate for the hardest, late-game levels rather than
the opening campaign. This is his familiarity assessment; no exact future slot
or automatic difficulty threshold has been chosen.

The word is valid: [WSJP PAN's entry for JAR](https://wsjp.pl/haslo/podglad/10561/jar)
defines a steep-sided ravine and marks the usage as literary (`książk.`).
Record it for editorial difficulty review rather than banning it as nonexistent.
It is an important counterexample to treating a short base-form noun as easy.
Source validity must remain independent from perceived difficulty and placement.

## Direction for a larger campaign

Before expanding toward several thousand levels, distribute the vocabulary
deliberately across multiple bands, such as very easy, easy, medium, hard and
very hard. These labels are illustrative; thresholds and the number of bands
are still to be specified and validated in a separate task.

Keep lexical difficulty separate from puzzle complexity. Classification should
consider familiarity, actual form frequency, lemma versus inflected form,
ambiguity and uncommon vocabulary. Wheel size, word count and crossword layout
are additional puzzle factors; they cannot substitute for word classification.

Opening slots should draw from the most obvious vocabulary. Less obvious forms
should appear substantially later. A larger campaign should use harder words
intentionally and progressively, rather than filling the easiest slots with
short obscure forms. The treatment of optional bonus words remains to be
specified; the complete valid bonus list must not be silently pruned.

## Current implementation and next content work

The current tiers (`level_ok`, `bonus_ok`, `banned`) express eligibility, not a
graded scale of player difficulty. `CONTENT.md#curve` currently defines P1
automatic ordering by letter count only, with difficulty serialized as `0.0`;
the richer scoring and curve belong to later pipeline work. This explains why
the current prototype ordering is not evidence of a suitable long-term curve.

A future task should define the lexical scale, an early-slot eligibility policy,
editorial handling of ambiguous forms, a reviewed sample with these examples,
and validation that easy slots cannot receive words from harder bands. Any
adopted change should update the source-of-truth specification through the
normal decision/task workflow before changing the generator or released slots.

For now, Chris requested **only this Markdown record**. Do not generate thousands
of levels or regenerate the current packs as part of this feedback capture.
