# AGENTS.md

Read this file fully before any work. It is short on purpose. If anything here conflicts
with a task file, STOP and escalate (rule S4).

## Project in 10 lines
- Mobile word-connect puzzle game (swipe letters on a wheel → fill a crossword grid).
- Engine: Godot 4.x.y (pinned in `game/project.godot`), typed GDScript. Android + iOS, portrait only.
- Offline-first. No backend. No LLM at runtime.
- Levels are generated offline by the Python pipeline in `pipeline/` and shipped as JSON packs in
  `game/content/`. The game has NO dictionary: each level contains its words and all bonus words.
- Balance numbers live in `game/data/config/*.json`, never in code.
- Source-of-truth docs: `docs/PRODUCT.md`, `docs/GAME_DESIGN.md`, `docs/ARCHITECTURE.md`,
  `docs/CONTENT.md`, `docs/DESIGN.md`, `docs/TESTING.md`, decisions in `docs/decisions/`.
- Work arrives as task files `tasks/T-NNNN-*.md`. One task = one branch = one PR.

## Repo map
```
game/core/        pure logic (RefCounted). No Node, no I/O, no Time, no randi(). Fully unit-tested.
game/services/    autoloads (closed list in ARCHITECTURE.md#autoloads). State + persistence.
game/platform/    SDK adapters + fake/ implementations. Only services call these.
game/features/    screens (scenes + scripts). Use services and ui components only.
game/ui/          tokens.gd, generated theme, components/, gallery/
game/data/        registries: config/, analytics/, audio/ (one file per area)
game/content/     GENERATED level packs. Never edit by hand.
game/tests/       GUT tests: unit/ mirrors core/, integration/, fixtures/
pipeline/         Python content pipeline (uv, pytest)
tools/            tasks.py, check_scope.py, context_pack.py, review_pack.py
```

## Commands
| Command | What |
|---|---|
| `make check` | everything CI runs except platform builds. Must be green before opening a PR. |
| `make test` | GUT unit + integration tests |
| `make fmt` / `make lint` | gdformat/ruff format; gdlint/ruff |
| `make run` | run the game in the editor binary |
| `make pipeline-test` | pytest for pipeline/ |

## Workflow
1. Read the task file. Check `status: ready` and that all `depends_on` tasks are `done`.
2. Create branch `t/NNNN-slug` from fresh `main`.
3. **Preflight:** verify every file, class, signature and signal listed in "Current state" exists
   exactly as described. If not → STOP (S1).
4. Implement. Change only files matching the task's `touch` globs (CI enforces this).
5. Write every test listed in the task's "Tests" section. You may add more tests, never fewer.
6. Run `make check` until green. Max 2 failed attempts at the same problem → STOP (S9).
7. Set the task's `status: review`. Commit: `type(scope): summary [T-NNNN]`.
8. Open PR titled `T-NNNN type(scope): summary` using the PR template. Fill "Deviations / concerns".
9. If `main` moved: rebase. Mechanical conflict (imports, adjacent lines in different functions):
   resolve and note it in the PR. Any conflict inside the same function, in logic, or in a contract
   file: do NOT resolve. Delete the branch and re-implement the task on fresh `main` (`-r2` suffix).

## STOP rules — escalate instead of deciding
Stop, write an `## Escalation` section (rule id, what you found, options you see, what you did)
in the PR description (open it as draft) and wait. Do not guess. Stop when:

- **S1** Preflight fails: something in "Current state" is missing or different.
- **S2** You need to change a file outside `touch`.
- **S3** You need to change a public API (`## @api` or anything in `core/`) the task does not specify.
- **S4** The task contradicts the docs, the code, or itself.
- **S5** A required test cannot pass without changing an existing test the task does not list.
- **S6** The change touches save format, economy values or rules, IAP, ads, consent, the analytics
  schema, or pipeline validators, and the task does not explicitly ask for it.
- **S7** You need a new dependency, addon, plugin, or a change to `project.godot`/export settings.
- **S8** Tests unrelated to your change fail on clean `main`. Report; do not fix.
- **S9** Two failed attempts at getting `make check` green.
- **S10** Rebase conflict in logic or in a contract file and re-implementation is impossible.
- **S11** Anything involving secrets, keys, signing, network endpoints, app permissions, manifest, plist.
- **S12** You would delete or rewrite existing code the task does not mention.

If you think the task is wrong but it can be implemented as written: implement it as written and
describe your concern under "Deviations / concerns". Never "fix" the task on your own.

## Code rules
- Static typing everywhere: typed vars, params, returns. Untyped declarations are errors.
- Layers: `core/` imports only `core/`. `features/` never calls `platform/` directly.
  Upward communication via signals. `Events` autoload is ONLY for side effects (analytics, audio,
  haptics), never for game logic.
- No new autoloads, singletons or global state.
- No magic numbers: balance → `Config`; visuals/motion → `ui/tokens.gd`.
- Time and randomness are injected (`Clock`, `RandomNumberGenerator` with seed). Never `randi()`,
  `randf()` or `Time.*` inside `core/`.
- Money/coins are `int`. All balance changes go through `Economy.grant()` / `Economy.spend()`.
- Analytics: only events defined in `game/data/analytics/*.json`. New event = add it to the registry
  in the same task (only if the task says so).
- Strings shown to players go through translation keys (`game/locale/<area>.csv`).
- Prefer building small UI scenes; keep `.tscn` edits minimal. Never hand-edit `game/content/`
  or the generated theme.
- No allocations in the swipe input path or in `_process`.
- Kill previous tweens before starting new ones; disconnect signals you connect manually.

## Godot 4 pitfalls (models often write Godot 3 code)
| Wrong (Godot 3) | Right (Godot 4) |
|---|---|
| `yield(x, "sig")` | `await x.sig` |
| `export var a := 1` | `@export var a := 1` |
| `onready var n = $N` | `@onready var n: Node = $N` |
| `connect("sig", self, "_m")` | `sig.connect(_m)` |
| `KinematicBody2D`, `Spatial` | `CharacterBody2D`, `Node3D` |
| `Tween` node | `create_tween()` |
| `rand_range()` | `rng.randf_range()` with injected rng |
| `PoolStringArray` | `PackedStringArray` |
| `File.new()` | `FileAccess.open()` |
| `instance()` | `instantiate()` |

## Tests
- Test public behavior, not private fields. A test must fail if the implementation is reverted.
- No sleeps, no real clock, no unseeded randomness.
- Unit tests for `core/` live in `game/tests/unit/<same path>/test_<name>.gd`.
- Do not modify or delete existing tests unless the task lists that file in `touch`.

## Definition of Done (every task)
- [ ] Every Behavior item and Edge case in the task is implemented.
- [ ] Every test in the task exists and passes.
- [ ] `make check` is green.
- [ ] Only `touch` files changed (plus the task file's `status`).
- [ ] No TODOs without a task ID. No commented-out code.
- [ ] PR template filled, including "Deviations / concerns" (write "None" if none).
