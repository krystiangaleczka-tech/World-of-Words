# T-0126 — prepared validation alternative

Implemented by Codex on 2026-10-09 from main c3a2638 (T-0125 merged).
The clean baseline passed pinned Godot 4.7.2 `make check` before implementation.

## Evidence

Four authored offline behavior tests cover schema assertions/references and
fail-closed unsupported vocabulary, integral JSON numbers, conditional campaign/
daily and landmark rules, tile multiplicity, tier membership, complete bonus
sets, spelling, placement geometry, identity and handmade intent.

A fixture containing one automatic wheel (KOT selected, TOK bonus) is validated
through the real artifact runner and CLI. Repeating the stage yields identical
bytes. Invalid bonuses and stale provenance preserve the prior artifact. A
handmade YAML fixture verifies that authored slots cannot disappear and the
validated record retains its intended words and bonuses.

These are fixture checks, not a native full-corpus run. No source corpus or
shipped game content changed. Export remains unimplemented. Final pinned Godot 4.7.2 `make check` passed: 199 GUT, 165 pipeline and
81 tools tests, with formatting/lint and registries green. Task lint passes.
Committed scope passed. An independent fresh reviewer approved exact commit
`f61171ea1fd42ec6c18efc11d26f8180ca4ea89e` with no remaining material blockers.
The discovered large-integer overflow was fixed and a positive regression added;
full checks were rerun successfully after that fix.

## Pending contract decision

The existing remote draft task requests a full Draft 2020-12 jsonschema backend
and waits for S7 dependency approval. This independently reviewed prepared
alternative uses a finite-vocabulary backend and therefore is not completion
of that original contract. It remains draft pending explicit adoption (S4), or
replacement of the schema adapter once the original dependency is approved.
