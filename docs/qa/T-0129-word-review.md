# T-0129 Polish word review

## Review scope and ownership
Chris requested execution of the next five tasks. Codex prepared this initial
300-candidate review and the exception decisions; CSV authorship is codex. This
is not a claim that Chris manually reviewed or played every entry. Human gameplay
QA remains T-0140 and later content changes may refine these judgments.

The ranked CSV follows actual P1 automatic proposal order (wheel size, candidate ID,
then each candidate's sorted selected words), rather than a list flooded by corpus
pronoun inflections. Every reviewed word exists in the pinned native dictionary.
The provenance JSON records the exact native tier/grid hashes and CSV hashes.

## Decisions
- 197 common ordinary words/frequent forms retain level_ok without override.
- 97 specialist, archaic, regional or unfamiliar standalone forms become bonus_ok.
  Their accepted valid forms remain available as bonus words, never required answers.
- BUC is banned: its ordinary analysis has pogard./pot. labels and denotes an insult.
- BEN, BIN, IBN and DON are banned as foreign-name fragments; morphology provides no
  ordinary standalone noun/verb analysis for these names' connecting elements.
- CII is banned: its only morphological analysis is the Roman numeral 102 (romandig).

Short unfamiliar proposals such as CNA, HOC, DEJ and CHU are removed from crossword
answers. Common interjections AHA, ACH, OCH and HAU remain available. Context-neutral
body terms KAŁ/ZAD become bonus-only rather than being treated as vulgar.
BABA, HAZARD, KASYNO and POKER remain unchanged, following Chris's stated preference.
No level_ok promotion, source-pin/rule/schema change or invented word is introduced.

## Native verification
The actual tiers stage was rebuilt against the unchanged full annotation artifact
and current override bytes. Exhaustive audit verifies all 300 decisions and 103
matched overrides; no unmatched decisions remain. Across 450,122 source records:
33,859 level_ok, 409,819 bonus_ok, 6,444 banned. Final tier artifact SHA256:
`727ee36eb596461c08da6c8bee4926d54f937942e13715208ad9a47cd6a226c9`.
The native audit JSON records these counts and confirms that BABA/HAZARD/KASYNO/
POKER all retain level_ok. Old candidate/grid/validate artifacts
are intentionally stale until T-0131 rebuilds them with authored input.

## Validation
Full make check passes: 199 GUT, 193 pipeline, 81 tools; task/scope lint,
independent content review and all CI are merge gates. No row-mirroring unit test is added for this data-only change; existing tier
parser/assignment/source-provenance tests and a real exhaustive decision audit cover
behavior. The eventual campaign still requires source-backed validation and play QA.

Fresh review corrections: common MAP/MAS/KAS/SAL/HAL/RAM/BAZ/ULA/RAT and SPA
retain level_ok. Rare inflections with ambiguous aggregate corpus frequency now
have specific lemma/context rationale. CII and DON join the exclusion list after
checking their actual morphology; the initial interjection label for CII was wrong.

Fresh independent review APPROVE: 887377d3cef0c5c90f67f86763d094b3a675d37b;
reviewer independently verified native hash, all decisions and audit counts.
