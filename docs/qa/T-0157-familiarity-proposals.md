# Current required-answer familiarity proposals

The catalog at pipeline/reviews/pl/familiarity.csv is a curator queue for the
version-2, 65-slot campaign: exactly 103 unique required forms. All 103 entries
are Codex proposals, not individual Chris decisions, corpus-frequency measures
or observed player success rates. The approved S26 playtest remains separate.

## Assumptions and review priorities

Bands follow T-0155: ordinary basic vocabulary is proposed as 1, familiar but
more specific vocabulary or familiar diminutives as 2. Four narrower/ambiguous
forms (ECH, KADR, LEP, WARTA) receive proposed band 3 and require attention.
There are 69 band-1, 30 band-2 and four band-3 proposals; no basis for band 4/5
was identified in this small queue. That does not establish measured coverage
of the whole Polish lexicon or prove that the proposals are correct.

Judgments concern exact forms and ordinary senses. KOCYK, KULKA and ŻABKA are
explicit diminutives; WARTA has prominent proper-name ambiguity, while ECH is
an interjection. Native membership alone does not resolve player familiarity.
Long everyday words PARASOL, HERBATA, GRUSZKA and KANAPKA are proposed as 1:
wheel size, slot position and grid geometry do not determine these ratings.

## Curator workflow

1. Read each exact word and rationale; consider recognition, meaning, form,
   register and the intended audience. Use actual evidence where available.
2. A curator may keep or revise the band; unresolved judgments stay proposed
   (possibly with an unknown band). Do not relabel a batch from device approval.
3. Record an actual decision as reviewed only after reviewing that word, with
   the curator attribution and a specific rationale. A parser cannot verify
   identity or the quality of that judgment.
4. Validate the CSV with load_catalog using native WordIndex tiers. T-0158 adds
   a reproducible required-word report; T-0159 adds an explicit early-word check.
   Those tools never promote proposals to reviewed automatically.

CSV rows are source-backed non-banned forms, strictly Unicode-sorted and unique.
The campaign JSON, pipeline provenance, runtime difficulty 0.0 and all 1697
optional bonus entries remain untouched. This queue is not a P2/FUN GATE result
or a reason to exclude difficult valid bonus words.

## Validation

Read-only p1.check replay passed; load_catalog with the validated native compact
receipt passed. Exact required-word coverage is 103/103, all proposed/codex;
long familiar examples are independent of tile count. Full engineering checks
and a fresh independent row-by-row review are required before merge.
