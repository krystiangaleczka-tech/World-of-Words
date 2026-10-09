# T-0128 content validation

The new read-only command and dedicated CI job validate campaign schema/hash/range/
word/geometry/P1 rules using a compact generated tier extract. Source downloads and
ignored native tiers are unnecessary in CI. Evidence preparation is explicit and
atomic; normal validation has no write or network path. Trust boundary is recorded
in CONTENT.md; T-0131 supplies real campaign/evidence.

Targeted tests: 23 pass. They exercise prepared evidence, no native artifacts in the
CI validation path, read-only repeat, initial absence, missing counterpart, stale
source/config/override/handmade/manifest evidence, corruption, full-level semantic
checks, spacing, unsafe files and preservation of old evidence on failure.

Full make check: 199 GUT, 193 pipeline, 81 tools pass; format/lint/registries pass.
Content target explicitly skips until T-0131 publishes its first campaign/evidence.
Log: /tmp/t0128-check.log. Independent review is a required merge gate.

Fresh review found a missing landmark relationship check. P1 now requires
landmark=true exactly for handmade eight-tile levels. A regression rejects a
three-tile handmade slot 16 carrying the flag.

Fresh independent review APPROVE for c99c34486157db13e7096551f05421cd9ae70714.
Final full local check passes; all ten CI jobs are required before merge.
