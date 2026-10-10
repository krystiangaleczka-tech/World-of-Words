# T-0142 — Independent Astra architecture audit

- Reviewer: **gpt-6-astra (Astra)**, independently delegated for this audit; not Claude Opus.
- Authorization: Chris explicitly requested “Zróbmy audyt z astra teraz”, selecting Astra as the substitute reviewer.
- Date: **2026-10-10 UTC**.
- Audited source: **68d7ccd55d01160c4512347b550136a2f16c93ec** (T-0138 merge).
- Scope: the implemented P0/P1 architecture and its suitability as the starting point for P2 contracts, across all eight ROADMAP dimensions.

## Verdict and closure disposition

**PASS for the T-0142 architecture checkpoint, with the concrete follow-up requirements below. No confirmed critical or high-severity defect in the implemented P0/P1 scope was established. There is no architecture finding that requires a P1 runtime fix before T-0142 can close.**

The implementation is coherent for an offline prototype with bundled, generated Polish content, free hints and no actual economy grants or native commerce. Its test seams, pure board model, explicit boot and persistence-before-success presentation are useful foundations. P2 must change the transaction/lifetime contracts before adding rewards, paid hints or IAP; those guarantees do not already exist.

This opinion satisfies the explicitly substituted architecture-review input. It does not itself change task status, merge a PR, approve P2 entry, or satisfy T-0143. Device feel/performance (T-0139), human vocabulary review (T-0140), outsider playtests (T-0141), and Chris’s FUN GATE (T-0143) remain separate and are not claimed complete. Native SDK execution, signing, OS backup restoration and physical power-loss behavior are also outside the evidence from this review.

## Provenance and method

I read AGENTS.md fully, `/tmp/T-0142-review-pack.md`, the task and preflight, architecture/content/game-design contracts, the relevant historical task specifications, implementation and tests. I examined the source independently before consulting the earlier independent Codex opinion for comparison. That opinion is supporting evidence, not Astra provenance.

The checkout initially reported HEAD `a5aaab1c2d91de365546e66c62ed750121d1a57d`; its difference from the audited source was only the two T-0142 preparation documents. A final `git diff --name-only` against the audited SHA for `game`, `pipeline`, AGENTS.md, ARCHITECTURE.md, CONTENT.md, GAME_DESIGN.md and ROADMAP.md was empty. The coordinating agent’s concurrent edits to T-0142 documentation do not change the audited runtime. Source references below refer to the named source SHA, not unspecified future main.

I changed no tracked source, tests, task files or GitHub state. This standalone report is the only deliverable I wrote. Existing focused tests use their normal disposable runtime output. I did not repeat full make check or the prior reviewer’s 55-test GUT selection.

## Findings and severity

| ID | Finding | Classification and disposition |
|---|---|---|
| A1 | Removing an already-found bonus from updated content invalidates the whole saved board snapshot. | **Medium compatibility gap when bonus updates are enabled.** Concrete source behavior, but consistent with the explicit P1 unknown-word rejection contract. Does not block T-0142; must be handled in P2 compatibility contracts and before the first affected content update. |
| A2 | A sole valid recovered `.tmp` is reopened for writing before another valid copy is established. | **Low, bounded recovery-hardening/test gap** in the current prototype. A second interruption can destroy that sole recovered copy; ordinary recovery with a valid primary or backup is not disproved. Include an explicit disposition and test in T-0229. Does not block T-0142. |
| A3 | Platform’s header says every build uses Fakes, while Android haptics uses a real engine adapter. | **Low documentation defect**, `game/platform/platform.gd:3` versus `:57–61`. Correct when that file next changes; selection behavior is intentional and tested. |
| Q1/Q4 | Screen-local pending completion and shared dirty Save state are insufficient for durable rewards/debits. | **Accepted P1 design with mandatory P2 contract work.** Would become a high-severity money/progress risk if paid/grant flows were attached unchanged. No such current P1 money flow exists. |
| Q2/Q3 | Runtime content validation, artifact provenance and performance measurements have narrower guarantees than an incautious summary could imply. | **Explicit accepted P1 boundaries**, with requirements below. Not newly discovered P1 regressions. |

### A1 — Saved progress versus permitted bonus-only updates

`game/core/board/board_state.gd:122–127` rejects a saved bonus word absent from the current level’s bonus list. `game/services/progress.gd:45–49` treats that null restoration as an invalid snapshot and returns a completely fresh board, also discarding previously revealed cells/found level words from the active board.

A precise trigger is a saved unfinished level with at least one revealed/found level word and one found bonus B; update the same level ID with identical letters, placements and grid, but remove B from `bonus`; then restore the saved snapshot. `BoardState.from_dict` returns null at line 124 and Progress returns a fresh board. This conclusion is established by the branch conditions in the source, **not a new executed Godot reproduction**. The focused snapshot tests pass but do not cover this cross-version scenario.

This is incompatible with the future update promise in `docs/CONTENT.md:263–270` and `docs/GAME_DESIGN.md:216–219` (FR-CONT-04/FR-BONUS-04). It is nevertheless not an implementation violation of `tasks/T-0100-board-state-contract.md:40`, which expressly requires rejecting unknown saved words, and no released-slot dictionary repair is claimed in P1.

**Required disposition:** specify historical credited bonuses separately from current content eligibility; preserve still-valid board progress and prior credited counts through bonus removal, re-addition and restart without granting twice. Do not simply accept arbitrary unvalidated save strings as newly eligible bonuses. Put the compatibility design in T-0229 (Save v3), T-0238 (Content contract) and T-0241 (Progress P2 contract); exercise it with T-0280’s persistent bonus meter and T-0302’s release/export contract. Implement it before the first affected update, even if that precedes the scheduled T-0454 repair loop. Release-slot locks alone will not catch this, because bonus changes are expressly allowed.

### A2 — Recovery from a sole valid temp file

`game/services/save.gd:31–41` accepts a valid temp after a missing/corrupt primary, exposes it and marks it dirty. `game/services/save/save_storage.gd:37` next opens the same `.tmp` with `FileAccess.WRITE`, truncating it before `store_string` at line 40. No alternate copy of the recovered temp has been made. If primary and backup are both unusable and another interruption occurs after open/truncate but before a complete replacement, all on-disk candidates can become unusable and the next load starts fresh.

The existing `test_each_atomic_write_boundary_recovers_last_committed_or_new_document` (`game/tests/integration/test_save_v1.gd:177`) starts with a valid primary; its first injected checkpoint is `temp_written`, reached **after** `store_string` (`save_storage.gd:40–43`). `test_truncated_temp_without_primary_recovers_backup` (`test_save_v1.gd:200`) has a valid backup. Neither covers truncating the only valid recovered temp. This is **source/control-flow analysis, not a newly executed process-kill or disk-full reproduction**.

For the normal interrupted commit with a valid preexisting primary/backup, the old committed document remains available. Reaching the loss scenario requires exhausted/corrupt other candidates plus a second interruption, or an interrupted first install with only its unpromoted temp. I do not interpret T-0036’s specified primary/temp/backup protocol and four checkpoints as a demonstrated guarantee against every repeated failure after all other copies have become invalid. This is a real boundary in resilience, not proof that the ordinary P1 atomic replacement contract fails.

**Required disposition:** T-0229 should cover the sole-temp startup state and a failure immediately after opening the next output file. Prefer establishing a second validated copy or promoting the recovered temp before reusing its path. Document the actual failure model and keep the broader device/filesystem evidence separate. The existing post-write checkpoints and desktop tests are not physical power-loss certification.

## Eight ROADMAP dimensions

### 1. Layering and ownership

The board/wheel core consists of RefCounted rule/data classes. Inspection/search found no core Node, FileAccess, Time, OS, autoload use or global RNG calls. Shuffle receives its RNG; wheel geometry takes data. `BoardState.evaluate/reveal_cell` (`game/core/board/board_state.gd:36–76`) owns rule mutations; LevelController orchestrates persistence; views render returned snapshots and results. BoardView does not evaluate words or grant rewards.

`game/features/level/level_controller.gd:72–119` invokes Progress, waits for its synchronous result and only then publishes state/result/completion/effects. No feature or UI component directly calls Platform in the inspected tree. Boot owns the audio/haptic listeners; their teardown disconnects owned connections. Events is used for effects, not selecting gameplay outcomes. The API intentionally exposes a live BoardState to trusted code, so “only controller writes” is an ownership convention, not a security boundary.

**Assessment:** sound P1 layering. Preserve direct owner calls for future transactions; never make economy correctness depend on Events subscribers.

### 2. Closed 12 autoloads and explicit boot

`game/project.godot:13–26` registers exactly, in order:

`Config Save Progress Economy Daily Content Monetization Analytics Audio Nav Events Platform`

`game/services/nav.gd:47–52` injects one Clock; Clock remains a plain class. Nav explicitly loads Save, Config and the content manifest before mounting a valid level (`nav.gd:64–87`). ServiceStub performs no domain work implicitly. Economy, Daily and Monetization remain stubs; future architecture paragraphs are not proof of their implementation. The screen-local Progress instance is not an extra autoload, but it is a temporary duplication of domain ownership; see Q1.

**Evidence:** `game/tests/integration/test_autoload_stubs.gd`, `test_nav.gd`, `test_boot_smoke.gd`; direct project/boot/source inspection. **Assessment:** closed list/order preserved; configure the existing Progress autoload as the P2 owner rather than adding another singleton.

### 3. Eight typed Platform adapters and Fakes

The eight RefCounted contracts are ads, IAP, analytics, crash, consent, haptics, review and notifications. IAP uses `StoreTransaction` with provider store key, product ID and state (`game/platform/iap/store_transaction.gd:3–16`); product dictionaries remain intentionally less strongly specified. Consent has typed enums. Notifications is explicitly a placeholder with no scheduling API.

`game/platform/platform.gd:43–65,109–126` keeps editor/headless/desktop/`--fakes` inert, checks registered plugin presence and expected adapter subtype, and permits isolated forced Fakes. Android haptics deliberately uses `HapticsAndroid`; iOS remains Fake. Factory selection does not initialize commerce SDKs. `test_platform_adapters.gd` exercises selection, invalid factories, recorded copies and scripted outcomes; haptics has dedicated tests.

**Assessment:** appropriate P1 seams. Native SDK callback duplication, delay, cancellation and lifecycle behavior still need P2 tests. Ads’ no-argument reward signal has no durable transaction identity: the owning Monetization flow must correlate offers and reject stale/duplicate callbacks. Fake success cannot establish native device correctness. Correct A3’s stale comment.

### 4. LevelData, pack and manifest contracts

`game/core/board/level_data.gd:20–25,98–186` reads the gameplay subset, validates basic types/grid placement/intersections and returns copies. `spell:85–95` rejects reused/out-of-range original tile IDs. Daily slot 0 is a runtime convention; versioning belongs to packs/manifests, not individual LevelData objects.

The three JSON schemas freeze the published structural contract, including PL alphabet/IDs and pack version. Python semantic validation adds formability, permitted tiers, complete bonuses, topology and campaign ID/slot correspondence (`pipeline/src/wordgame_pipeline/validate/core.py:11–36`). Runtime Content checks manifest/pack identity, contiguous ranges, counts and expected slots, loads lazily and preserves the previous manifest on load error (`game/services/content.gd:22–50,85–161`). Runtime release intentionally skips SHA verification (`content.gd:19,128–129`; `docs/CONTENT.md:251–252`). Neither runtime subset parser nor structural JSON schema alone proves all semantics.

**Assessment:** adequate for CI-validated bundled P1 content. P2 manifest v1.1 must explicitly define version compatibility across T-0238/T-0302; do not silently feed a new structural schema into an unchanged loader. A1 must be part of content/save compatibility, not treated as pack-hash protection.

### 5. Save v1→v2, recovery and persistence

`SaveMigrations.upgrade` rejects malformed/future versions and missing/nonadvancing steps (`game/services/save/save_migrations.gd:29–45`). `MigrateV1ToV2.migrate` deep-copies and adds highest_completed_slot from completed_slot per language, preserving other sections. Save validates/canonicalizes before exposing copies. Unknown extension keys survive. SaveSchema is structural; placeholders and some domain invariants intentionally await owner contracts.

Load order is primary, temp, backup. Commit writes/flushes temp, rotates a known valid primary, and promotes temp. Recovery avoids rotating a corrupt primary over a valid backup (`game/services/save.gd:31–41`; `save_storage.gd:34–58`). Errors leave dirty memory retryable. Settings signals and Progress completion are withheld on a failed flush. V1/v2 golden, interrupted-file and retry tests cover these contracts (`test_save_v1.gd`, `test_save_v2.gd`, `test_progress_persistence.gd`).

**Assessment:** no critical/high defect established in ordinary P1 save/recovery. A2 limits the stronger recovery claim. Shared dirty memory is not rollback or an atomic transaction across owners; Q4 is required before money flows. A future-version save currently falls through to recovery/clean-start by explicit contract; a production downgrade policy must preserve an external known-good backup and must not be sold as lossless downgrade support.

### 6. BoardState API

`BoardState.evaluate` distinguishes level, bonus, already-found and invalid words and ignores short attempts. Revealing crossings synchronizes found words; completion is emitted once in memory. `from_dict:98–129` rejects foreign IDs, duplicate/unoccupied cells, inconsistent found words and invalid bonuses. Pure HintLogic is deterministic. Copy-returning getters prevent accidental mutation through snapshots.

**Assessment:** appropriate P1 rule API, directly covered by the new focused run below. Its `completed` signal is an in-memory fact, never authority to grant or navigate before persistence. A1 is a future cross-content-version problem in the current strict snapshot contract. P2 paid hint/reveal must specify a candidate mutation and its commit outcome, not bolt a debit onto the existing free reveal after the fact.

### 7. LevelController and lifecycle

`game/features/level/level_controller.gd:39–93` retains pending mutations after I/O failure and retries them before accepting another meaningful action. `_busy` guards the normal durable publication sequence; the existing contract does not promise arbitrary reconfiguration from callbacks is transaction-safe. Success effects come after Progress flush. `game/features/level/level.gd:79–90,239–263,385–405` owns scene-local Progress, board binding and signal cleanup. Terminal resume displays completion without issuing another grant/effect.

The wheel tracks one owner pointer, original tile identity and backtracking; cancellation, background and exit clear without submission (`game/ui/components/LetterWheelView.gd:207–281,305–315`). Hint/shuffle are disabled while dragging (`level.gd:185–218`). Normal Continue is exposed after durable completion, so the P2 destruction risk in Q1 is not an established ordinary P1 continuation bug.

**Evidence:** source and `test_level_scene.gd`, `test_level_completion.gd`, `test_progress_persistence.gd`, wheel input/shuffle tests. **Assessment:** coherent current lifecycle, with the transaction owner and failure-visible state requiring explicit P2 contracts.

### 8. Pipeline stage contracts, trust and determinism

`pipeline/src/wordgame_pipeline/stages.py:26–48` fixes the canonical 13 stages and selects P1 stages 1,2,3,5,6,7,9,13. Handlers receive config plus prior payload. Canonical UTF-8 envelopes have schema/pipeline/config/stage identity and predecessor hashes; the runner preflights handlers and atomically replaces individual artifacts (`stages.py:76–148`). Whole build/directory power-loss atomicity is not implied.

Generic resume validates predecessor hash shape, not the claimed earlier bytes; this is the explicit T-0120 boundary. Stage-specific validation/export rechecks pins, handmade intent, schemas, tiers and semantics. `content.py:34–82,111–212` validates the shipped bundle/evidence; `p1.py:64–134` rebuilds actual grids/export from committed compact input records and compares output bytes. `export/publish.py:56–102` checks managed file sets/hashes/version progression and handles directory replacement rollback. Single-writer and handled-I/O guarantees remain narrower than concurrent-reader or power-loss atomic publication.

The committed tier extracts are trusted reviewed inputs. Matching their claimed native-artifact hash does not independently prove membership against downloaded dictionaries. Native evidence regeneration/review remains necessary for content PRs. Future released-slot immutability (T-0302), scoring/dedupe/sequence rules and full annotation replay are not already established by P1 replay.

**Assessment:** a useful deterministic pipeline within its stated trust model; no new critical/high defect established. The independent in-memory probe below confirms the exact nonrecursive envelope boundary instead of assuming stronger authentication.

## Q1–Q4 resolved and concrete P2 requirements

**Q1 — Progress lifetime: accept P1; require the existing configured Progress autoload as the authoritative P2 domain owner.** A Level scene should bind/unbind its board, not own the lifetime of completion/reward state. Current `Progress._pending` is instance memory (`progress.gd:13,97–109,183–190`). Fail completion flush, free the screen, then let another Save owner flush: the advanced dirty document can persist after the instance holding the pending completion has gone away. The existing test at `test_progress_persistence.gd:174–187` retains the same instance through unbind, so does not prove destruction/recreation safety. This is not a current lost P1 economy grant because there are none. T-0241/T-0242 and T-0276 must specify owner/binding lifetimes, navigation and language changes. Persist transaction identity/status needed for process-restart recovery; merely changing a Node’s lifetime is insufficient. Add failure→screen destruction→other-owner flush, process restart, duplicate callback and stale-board tests.

**Q2 — Content trust: accept the exact bundled/offline P1 boundary.** Keep full validation/replay in CI and reviewed native generation provenance. A pack hash proves byte identity, not source authority, and the generic artifact envelope does not authenticate its payload or ancestry. If downloadable/remote content is later introduced, that change needs authenticated manifest/integrity rules, schema/semantic/resource limits, atomic installation/recovery and compatibility tests before use. It is not required to add runtime dictionary validation to today’s bundled prototype. T-0238/T-0302 must preserve or explicitly migrate versioned schema contracts and enforce released-slot locks; include A1 before content updates that exercise it.

**Q3 — Allocations/performance: accept the T-0105 exception, with bounded claims.** Pointer-only motion reuses preallocated chain/geometry/line storage; chain changes and submission copy the active prefix. Preview spelling also allocates (`LevelData.spell:85–95`, `level.gd:270–274`). Therefore “no allocations throughout a whole gesture” is false. T-0135 measures input dispatch to an engine rendering boundary, excluding sensor/OS delay, GPU completion and scanout (`docs/qa/T-0135-performance.md:16–18`); it is not finger-to-photon latency. Require the actual Galaxy A15 T-0139 observations and P2 T-0282/T-0322 device results, including the submission/persistence frame, before performance acceptance. No immediate speculative architecture rewrite is justified by headless evidence.

**Q4 — Transaction semantics: require one durable commit of all related domain changes before successful publication/SDK finish.** `Save.set_section:99–109` changes shared memory before `flush:137–148`; BoardState also mutates before persistence. Another owner can flush that dirty state. Existing free P1 retry behavior is intentional, not rollback. Freeze in T-0229/T-0232/T-0241 how owners produce a validated candidate document containing related progress, economy and processed-operation keys, how one commit publishes it, and what reads/retries see after failure. Persist idempotency keys for grants/debits and store transactions, not transient signal-delivery flags. Do not use Events as the transaction coordinator. T-0261/T-0271 must handle duplicate/late/pending/unfinished callbacks and finish store transactions only after durable entitlement/grant recording; T-0278 must atomically pair cost with reveal; T-0280/T-0281 must avoid duplicate bonus/completion rewards. Fault tests must reload from disk between each failure boundary, exercise a second owner’s flush, and distinguish “committed but notification lost” from “not committed”. Settings consumers (T-0284) also need a defined policy for failed dirty changes and subsequent notification/retry.

These are required inputs to dependent P2 tasks. They do not assert that those future systems are implemented or that T-0143 has approved starting them.

## Verification evidence and limits

New checks executed by Astra:

1. Exact-source diff checks and searches of core dependencies, feature/UI Platform access, autoload declarations, schemas, relevant source and historical task contracts.
2. Godot **4.7.2.stable.official.ed1daf0bf**, GUT 9.7.1: **18/18 tests, 100 assertions passed**, no script/runtime errors in this run:

```sh
/tmp/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path game \
  -s addons/gut/gut_cmdln.gd -gconfig= \
  -gtest=res://tests/unit/board/test_board_state.gd,res://tests/unit/board/test_board_state_contract.gd,res://tests/unit/board/test_level_data.gd \
  -gexit -glog=1
```

3. A read-only in-memory Python probe against the actual `read_artifact` implementation, using the real loaded PL config and patched `Path.read_bytes`: canonical grid envelopes with unrelated predecessor hashes `0` × 64 and `f` × 64 were both accepted; `not-a-hash` was rejected with `Invalid predecessor hash`. This confirms the stated shape-only boundary. No artifact/source file was modified by that probe.

A harmless attempt to supply a Godot script through `/dev/stdin` was rejected by the resource loader before execution; it is excluded from test evidence. No custom runtime A1/A2 reproduction was performed, and no claim of process-kill/device fault injection is made.

Prior evidence supplied with the audit: full make check in `/tmp/t0142-check.log` (218 GUT tests / 8524 assertions, 199 pipeline tests, 142 tools tests), prior independent focused run (55 GUT / 739 assertions and 10 Python tests), and source CI run 38015068644 including Android debug build and actual release-resource inspection. Those are explicitly prior evidence, not checks rerun by Astra. They do not replace the missing human/device gates.

**Closure disposition:** attach this actual Astra opinion, retain A1/A2 and Q1–Q4 as explicit requirements for the named follow-up tasks, and T-0142 has no outstanding critical/high architecture finding. T-0143 remains Chris’s separate decision.

## Coordinating record: context, authorization and completion

Chris selected Astra on 2026-10-10 for T-0142 specifically; task revision 2 records
the substitution. The named roadmap model remains unchanged for other tasks.
The complete Astra opinion above is reproduced verbatim from the independent
audit artifact. A1/A2 and Q1-Q4 are retained as requirements for their named
follow-up tasks; A3 is a low documentation correction for the next Platform edit.
No finding requires a P1 runtime change before this architecture checkpoint closes.

The original factual preflight and its preparation evidence remain available in
PR83's earlier commit 52f106183ecd4211d0b733f83055bfb1252d4e01. Preparation received
fresh independent review and 12 successful CI jobs in run 38036637940.
Full local make check passed against the same runtime/source: 218 GUT tests /
8524 assertions, 199 pipeline tests, 142 tools tests, registries and 65 PL levels.
Only this report and the T-0142 task change; the final published documentation
receives task/scope/test-count checks, fresh review and its own CI before merge.

Reproduce the context pack from a checkout of audited source
68d7ccd55d01160c4512347b550136a2f16c93ec:

```sh
uv run python tools/context_pack.py \
  --ref docs/ARCHITECTURE.md --ref docs/CONTENT.md --ref docs/TESTING.md \
  --ref docs/decisions/0002-content-in-packs.md > T-0142-context-pack.md
```

The context pack inventories source paths and marked APIs; implementation bodies
must be inspected separately at the same source SHA. The selected source ZIP is
a review snapshot, not a complete build checkout.

Fresh independent publication review approved
ded84f29d4d81b38368426af8096dafebbe47d78 without blockers. It verified the complete
24,874-byte Astra opinion against the standalone artifact, the two-file scope,
source-backed findings, authorization, anchors and verification provenance. The
task outcome was clarified afterward to state that A3 belongs to the next Platform
edit rather than inventing a dedicated task ID. Task lint (93 tasks), scope
(2 files) and test-count (366 versus 366 on main) passed. Final CI remains the
merge gate, with its run and result recorded in PR83.
