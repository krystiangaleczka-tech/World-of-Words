# T-0142 P0/P1 architecture preflight and review brief

Source: main `68d7ccd55d01160c4512347b550136a2f16c93ec` (T-0138 merge).
Provenance: Codex technical preparation, 2026-10-10. Required Claude Opus
architecture opinion: **pending**. No FUN GATE or P2 entry approval is implied.

## Scope and verdict

Inspected all dimensions in the T-0142 ROADMAP row against the implemented P1
contracts. No confirmed critical defect was established by this preflight.
That is not a final architecture clearance: ownership and trust-boundary questions
below require the assigned independent audit. No runtime or schema was changed.

## Reproducible context

At the exact source commit, generate the repository map, public API inventory and
contract sections using the existing tool:

```sh
uv run python tools/context_pack.py \
  --ref docs/ARCHITECTURE.md --ref docs/CONTENT.md --ref docs/TESTING.md \
  --ref docs/decisions/0002-content-in-packs.md > T-0142-context-pack.md
```

Use a checkout of the named SHA, not an unspecified later main. The context pack
contains paths, marked signatures and docs; it does not contain implementation
bodies. Read the source families and tests cited below from that same checkout.
The preparation PR's task/report are supplemental material, not audited runtime.

## Layering and ownership

- `game/core/board/{level_data,board_state,hint_logic,shuffle,attempt_result}.gd`
  and `game/core/wheel/wheel_geometry.gd` extend RefCounted. No core use of Node,
  FileAccess, Time, OS, autoloads or global randi/randf was found. Shuffle receives
  an RNG; geometry receives positions/radius; matching receives tile IDs.
- `game/features/level/level_controller.gd` orchestrates BoardState and Progress.
  Views consume its state/result/completion signals. `_effect` emits optional
  Events signals after durable publication; no event listener chooses outcomes.
- `game/ui/components/BoardView.gd` reads snapshots and renders cells; it never
  evaluates words or mutates BoardState. The wheel handles pointer/geometry state.
  No feature/component direct Platform call was found in the inspected sources.
- `game/services/haptics_listener.gd` and `audio/audio_listener.gd` translate
  Events into effects, respect live Save settings and disconnect owned listeners.
  Boot owns both listeners; Platform SDK operations are called from services.
- Save owns the document, settings and identity; Progress updates its section.
  Source declarations match that structural ownership, with a P1 lifetime choice
  described under Q1 rather than a newly invented regression.

## Closed autoload list and initialization

`game/project.godot` registers exactly, in documented order:

```text
Config Save Progress Economy Daily Content Monetization Analytics Audio Nav Events Platform
```

Clock is a class (`game/services/clock.gd`), not an autoload. Nav.boot injects
one Clock into the list; `game/tests/integration/test_autoload_stubs.gd` asserts
list/order, shared injection and no implicit initialization work in ServiceStub.
`game/services/nav/boot.gd` registers locales, configures audio, starts Nav,
then mounts the owned effect listeners and a debug-only overlay.

Nav.start loads Save, Config and the PL manifest before entering a valid Level;
errors retain BOOT and emit boot_failed. Unimplemented Economy, Daily and
Monetization are P2 placeholders, not functioning rewards/ads/IAP subsystems.
Config/Analytics implement only their current P1 registries. The draft architecture
also describes future flows; those paragraphs do not establish implemented P1 APIs.

## Platform contracts

`game/platform/*/*_adapter.gd` defines eight typed RefCounted boundaries:

| Adapter | Current interface |
|---|---|
| Ads | initialize(consent), load/show rewarded/interstitial; reward_earned/closed/failed outcomes |
| IAP | query_products, purchase, finish(StoreTransaction), fetch_unfinished, restore; typed transaction signal |
| Analytics | log_event(name, params), set_user_property(key, value) |
| Crash | record(message), set_key(key, value) |
| Consent | request_info, show_form_if_required, request_att, show_privacy_options; State/AttStatus signals |
| Haptics | play(pattern) |
| Review | request_review() |
| Notifications | Later placeholder; no scheduling API yet |

Platform.select_adapters keeps editor/headless/desktop/--fakes inert; registered
mobile SDK factories need the named installed singleton and expected adapter type.
Android haptics uses the engine-backed adapter on device; iOS haptics remains Fake.
The Platform class header's blanket "every build uses inert Fakes" predates that
Android branch; use the branch/tests as evidence of actual behavior, not the header.
`test_platform_adapters.gd` covers selection, bad factories, isolated overrides,
recorded argument copies and scripted outcomes. This is not native SDK/device QA.

## LevelData, pack and manifest boundary

- `pipeline/schema/level.schema.json` freezes uppercase PL tiles (3–8), placements,
  bonus words, grid bounds, campaign/daily IDs and generation metadata. Pack and
  manifest schemas own schema_version; LevelData does not read a level version.
- `pipeline/schema/manifest.schema.json` freezes PL campaign ranges, paths, hashes,
  content version and pipeline identity. Structural JSON schema alone does not
  establish formability, topology or bonus completeness; the validator does.
- `game/core/board/level_data.gd` parses the gameplay subset, makes copy-returning
  snapshots and checks basic shape/grid intersections. Daily omits slot and maps
  to runtime slot 0. It is deliberately not a full Python schema validator.
- `game/services/content.gd` checks contiguous manifest/pack identity and counts,
  lazily caches a pack, reports pack_failed and checks its hash in debug builds.
  Runtime release trusts generated bundled content; full semantic validation and
  byte-identical replay are CI responsibilities, not an in-game dictionary.
- `test_content.gd`, `test_content_schemas.py`, validator tests and the content bot
  cover their respective boundaries. All 65 shipped PL levels are bot-playable;
  this does not assess vocabulary quality or enjoyment (T-0140/T-0141).

## Save v1 to v2 and recovery

`SaveSchema.VERSION=2`. SaveMigrations defaults to the pure MigrateV1ToV2 step:
copy v1, set each language's highest_completed_slot from completed_slot, set version
2, then validate/canonicalize before exposing sections. Future versions and missing
or invalid steps are rejected. Original v1 golden fixtures remain committed.

Save.load checks primary, temp, backup in that order. SaveStorage.commit writes
`.tmp`, flushes, rotates a known valid primary to `.bak`, then promotes temp.
Recovery suppresses rotation of a corrupt primary over a valid backup. Dirty writes
remain retryable; setting signals and Progress completion require successful flush.
Tests interrupt every write checkpoint and cover corruption, first install,
migration preservation, language isolation and retry after another owner flushes.
This demonstrates tested file/recovery semantics, not Android filesystem power-loss
certification or the future P2 multi-domain grant transaction.

## BoardState and LevelController API

BoardState owns found/bonus/revealed state, enforces original tile identities,
ignores short attempts and restores only consistent snapshots for the same level.
HintLogic is deterministic. BoardState.completed is an in-memory rule signal;
LevelController.completed is the durable presentation/effect boundary.

LevelController exposes configure, get_board, submit, hint and is_complete.
Mutations set pending state; failed writes emit persistence_failed and an explicit
later action retries. `_busy` prevents reentrant mutations during publication.
A final hint/word uses Progress.complete_level; ordinary changes use save_level.
LevelScreen consumes controller signals and owns its presentation connections.
`test_level_scene.gd`, `test_progress_persistence.gd` and `test_level_completion.gd`
cover persistence-before-effects, retries, scene restoration and terminal content.
No economy grant is implemented by this P1 path.

## Pipeline stage contracts

`pipeline/src/wordgame_pipeline/stages.py` preserves the canonical 13-stage order;
P1 selects 1,2,3,5,6,7,9,13. Handlers take config + previous payload. Atomic canonical
UTF-8 envelopes contain schema_version, pipeline_version, lang, stage,
config_sha256, input_sha256 and payload; resume validates prerequisite identity,
config/version, hash shape and canonical bytes before writing.

In particular, read_artifact checks input_sha256 shape, not a recursively verified
hash of an available earlier artifact. That matches T-0120 specification item 5.
Do not describe resume alone as authentication of all upstream source bytes.
Stage-specific handlers recheck pins/provenance; validators recheck semantics;
export rechecks validation evidence; publication rejects partial/outdated output.

`content.py` documents the committed tier-extract trust boundary. `p1.py.check`
replays actual grids/export from committed reviewed source extracts and compares
publication byte-for-byte. It verifies current pins/review/schema/config hashes;
it does not redownload and reannotate the complete native dictionary in CI.
Tests include deterministic resume, provenance rejection, stale validation,
publication failure and semantically valid edits that still fail native replay.

## Questions for the assigned audit

- **Q1 — Progress lifetime before P2.** T-0116 explicitly requires a per-screen
  Progress instance using the same Save/Content; the global autoload still exists.
  Decide how P2 will own completion/reward transactions, pending writes, bindings
  and listeners across scene changes. Current screen-local behavior is task-approved
  and tested; a later switch to the global service needs a scoped contract/change.
- **Q2 — Runtime content trust.** LevelData validates a gameplay subset, release
  skips bundled pack SHA checks and resume does not recursively authenticate the
  artifact chain. These are explicit P1 boundaries. Confirm them or require stronger
  validation before any downloadable/remote content is introduced.
- **Q3 — Input allocations and performance wording.** T-0105 explicitly permits
  copied chain prefixes on selection/submission, while continuous pointer-only
  motion reuses buffers. Chain changes also spell/update preview text. Preserve
  that distinction; a claim of zero allocations for the entire gesture is unsupported.
  T-0135 measures an engine render-boundary estimate, not finger-to-photon latency.
  Acceptance still needs Galaxy A15 observations in T-0139.
- **Q4 — P2 transaction semantics.** Save.flush is synchronous and BoardState may
  already hold a pending mutation; it is not a generalized rollback transaction.
  Specify economy/completion atomicity and exactly-once grants before adding paid
  hints, rewards or IAP. Keep Events out of those decisions.

## Opus handoff

Review the named source SHA and the context/source files above. Check the eight
ROADMAP dimensions, classify each finding with a reproducible trigger/evidence,
then record whether Q1–Q4 need a P1 fix or a P2 contract requirement. State reviewer
identity and SHA explicitly. Do not infer device/playtest results from CI.

Required final verdict: **pending**. Critical-finding disposition: **pending
assigned review**. Chris's FUN GATE remains a separate T-0143 decision.

## Validation evidence

The source commit passed full make check and 12 CI jobs in run 38015068644,
including Android debug APK and actual release-resource inspection. Documentation
preparation receives its own full local check, scope/task validation, fresh routine
review and CI below; those do not substitute for the assigned Opus opinion.

Preparation checks: full make check passed (218 GUT tests / 8524 assertions,
199 pipeline tests, 142 tools tests, registries and 65 PL levels). Context pack
was generated from a read-only git archive of the exact source SHA, excluding
working-tree preparation files. The source ZIP is a selected review snapshot,
not a complete build checkout. No new runtime tests were needed for this report.

Fresh routine reviewer approved preparation SHA
be039523f9063e02d7d90d1f6a7c6ed0116106f9 with no blockers. Independently checked
861 source paths, 240 marked API signatures, four requested docs, selected archive
bytes and the T-0105/T-0116 choices. This approval covers the preparation only;
task remains blocked and PR draft pending the assigned architecture opinion.
