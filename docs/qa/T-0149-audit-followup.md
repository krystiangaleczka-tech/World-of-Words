# Technical follow-up to the Astra architecture audit

This report records later work, not a new Astra opinion. The [original T-0142
report](T-0142-architecture-preflight.md) remains unchanged: Astra audited source
`68d7ccd55d01160c4512347b550136a2f16c93ec` and gave PASS, with no confirmed critical
or high-severity P1 blocker. Chris requested five subsequent tasks; this technical
wave uses P1 reserve IDs and does not close the human FUN GATE or begin P2.

## Merge and verification receipts

The four runtime tasks were squash-merged one after another after all 12 CI jobs
passed. Each has full local check evidence and a fresh independent review of the
exact implementation, without the author conversation. Merged executable source
was also checked against the reviewed version. T-0149 corrects the Platform header
and publishes this report; its checks are in its own PR.

| Task | Pull request | Merged commit | CI run | Godot tests / assertions |
|---|---|---|---|---|
| T-0145 | [PR #84](https://github.com/krystiangaleczka-tech/World-of-Words/pull/84) | `cae9d3539faff1d0ca32d818c918326c5c835f52` | [12/12 CI](https://github.com/krystiangaleczka-tech/World-of-Words/actions/runs/38081896177) | 224 / 8611 |
| T-0146 | [PR #85](https://github.com/krystiangaleczka-tech/World-of-Words/pull/85) | `3d0afb10bbb1e1cdf65e10464e2d77a9c28f5c03` | [12/12 CI](https://github.com/krystiangaleczka-tech/World-of-Words/actions/runs/38082294165) | 230 / 8674 |
| T-0147 | [PR #86](https://github.com/krystiangaleczka-tech/World-of-Words/pull/86) | `7548598d9250f999f610e12eea59874a16778231` | [12/12 CI](https://github.com/krystiangaleczka-tech/World-of-Words/actions/runs/38082703923) | 236 / 8744 |
| T-0148 | [PR #87](https://github.com/krystiangaleczka-tech/World-of-Words/pull/87) | `e1adb0fdd1ff63c1703ee2d04bdb5a948823f874` | [12/12 CI](https://github.com/krystiangaleczka-tech/World-of-Words/actions/runs/38083106520) | 240 / 8868 |

Each local full `make check` also passed 199 pipeline tests, 142 tooling tests,
registry checks and validation of all 65 PL campaign levels. Godot used the exact
4.7.2 stable binary. Independent reviewer receipts and precise implementation
commits are recorded in the task outcomes and PR descriptions. No existing test
was deleted or weakened; each runtime task adds focused regression coverage.

## Finding dispositions and limits

- **A2 / T-0145:** before replacing a sole validated recovered `.tmp`, Save promotes
  it to primary. Ordinary flush and debug reset then use the existing rotation
  protocol. Failed promotion remains retryable. Fault tests cover actual output
  truncation/open failure, fresh Save reload, v1 migration, retry and failed reset.
  These are logical interruption tests; they do not prove process-kill, filesystem
  fsync or hardware power-loss durability. Save v2 and its migration chain remain.
- **Q4 settings / T-0146:** validated pending keys survive failed writes and notify
  after a successful flush from any owner, request/pause flush or debug reset.
  Repeated failed edits coalesce. Clearing the publication snapshot before
  callbacks preserves a callback's new failed edit for later retry. Failed dirty
  reads keep the previous P1 policy. A key signal identifies a committed change;
  it is not a snapshot/read transaction across arbitrary synchronous callbacks,
  nor a persistent signal replay journal after process death.
- **A1 / T-0147:** Progress explicitly opts into historical-credit restoration.
  The strict default BoardState API still rejects unknown bonuses. Retired
  records must be unique strings formable from distinct available original tiles,
  within tile-length bounds and outside required level words; existing cell,
  ID and found-word consistency checks remain. Current content alone determines
  new eligibility. A retired credited word is INVALID; a reintroduced credit is
  ALREADY_FOUND. Integration tests preserve partial board progress through actual
  Save serialization and fresh instances. This covers bonus-only changes with
  stable ID/letters/required geometry. It cannot authenticate old membership or
  edited local saves; historical counts are not economic grant authority.
- **Controller boundary / T-0148:** an active action rejects synchronous nested
  submit/hint/configure calls. The guard starts before BoardState mutation and
  lasts through persistence, result/completion and effect callbacks, including
  INVALID/ALREADY_FOUND. Idle configure returns true; rejected configure returns
  false without replacement or deferred work. Failed mutations retain existing
  explicit P1 retry behavior. This is a synchronous action guard, not a lock on
  direct external BoardState access or a durable domain transaction.
- **A3 / T-0149:** the Platform header now matches selection: editor/headless/
  desktop/`--fakes` use Fakes; normal Android uses engine haptics; other SDK
  adapters require registered typed factories and installed plugins. Only the
  inaccurate comment changes. Native SDK/device correctness is not inferred.

## Required P2 contracts still open

The audit's accepted P1 boundaries are not converted into production guarantees:

1. **Q1:** T-0241/T-0242/T-0276 must configure the existing Progress autoload as
   the authoritative owner and define screen binding, navigation and language
   lifetimes. Persist operation identity/status for process restart; a longer-lived
   Node alone is insufficient. Test failed commit, screen destruction, another
   owner flush, restart, duplicates and stale boards.
2. **Q4:** T-0229/T-0232/T-0241 must define one validated candidate document and
   durable commit for related progress, economy and processed-operation records.
   Publish success only afterward. T-0261/T-0271 must correlate and deduplicate
   native callbacks and finish store transactions only after durable recording.
   T-0278 pairs debit and reveal atomically; T-0280/T-0281 must avoid repeated
   bonus/completion rewards. Events remains for effects, not coordination.
3. **Q2/A1:** T-0238/T-0302 must define versioned content compatibility and released
   slot immutability; extend historical-credit coverage as production formats
   evolve. Bundled CI-validated P1 content retains its documented trust boundary.
   Hashes prove byte identity, not dictionary authority or authenticated ancestry.
4. **Q3:** T-0139 and P2 T-0282/T-0322 still require actual device measurements.
   Pointer-only movement reuses storage; chain changes/submission/preview may
   allocate. The engine timing overlay is not finger-to-photon measurement.
   Test the submission and synchronous-persistence frame on the reference device.

## Human work remains open

Chris has not configured the T-0136 upload key/secrets and explicitly asked to
continue work that needs none. He also reported that the Galaxy A15 test had not
been performed. No phone observations are fabricated by these changes.

T-0139 wheel feel, T-0140 all-level content review, T-0141 five outside players for
at least 20 minutes without instructions, and Chris's T-0143 go/fix/stop decision
remain separate requirements in the roadmap. The existing test package and forms
remain the route for those results. Use the debug APK from the T-0148 CI run
linked above to test the corrected runtime; earlier packages retain their recorded
source baseline. Green headless tests and APK/resource exports
do not complete those tasks. No production secret, SDK, economy or visual-phase
approval was inferred from completion of this technical wave.
