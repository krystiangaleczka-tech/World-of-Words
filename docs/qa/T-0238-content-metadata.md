# T-0238 Manifest metadata contract

Additive all-or-none metadata preserves schema_version 1 and shipped P1 files. Typed independent
Content lookups use virtual campaign records for legacy manifests, validated real regions/locations
for future P2 exports. Sparse landmark flags are unused by gameplay. No packs/words/Save edits.

Validation: 455 GUT tests pass (four new metadata tests); 148 schema/new metadata tests pass,
including eighteen new Python cases. Full make check failed at pipeline provenance checks because
receipt schema hash pins the old manifest schema. S2: receipt is outside task scope; owner approval
requested for mechanical hash refresh plus complete 65-level replay/byte-identity verification.

The contract defines pieces capacity and sparse {slot,landmark} records not detailed in CONTENT's
illustrative example. Regional shipping remains T-0302. One helper/service/schema/validator changes;
tests and schema metadata exceed the approximate line budget. Independent review required.

## Resolved escalation and final validation

Chris approved the receipt scope expansion ("10, ok"). Revision 2 refreshes only
schema_sha256.manifest; all other receipt data is identical to the original. Complete offline
campaign replay validates 65 levels. Every shipped game/content file remains byte-identical.

Full make check now passes: 455 GUT, 329 pipeline and 488 tools tests. Scope/task checks pass.
No existing tests were weakened or edited. Independent review and final-head CI remain required.
