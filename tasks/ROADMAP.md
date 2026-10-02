# ROADMAP.md — Project WORD task breakdown

- Status: v2 (2026-10-02): aligned to PRODUCT.md v1 and DESIGN.md v1, review findings applied. Task
  status lives in task files, not here. Owner: Sol (planner). Chris approves each wave.
- Planner-owned: **executors never edit this file.** Status lives in task files `tasks/T-NNNN-*.md`
  (front-matter `status`); `tools/tasks.py board` renders the board. This file changes only in
  `plan/*` or `docs/*` PRs by Sol or Chris.
- Sources: `docs/PRODUCT.md` (FR/NFR IDs), `docs/DESIGN.md` (components, flows, anchors), design pass
  `docs/design-pass/01..11` (imported by T-0001; wins on conflicts with the research), decisions
  `0004`, `0005`, `0006`.
- This is the task list Chris calls TASK.md. Replaces the research idea "TASKS.md with 50–70 tasks": rows here are planning units. Detailed task
  files are written one wave (3–6 tasks) at a time on fresh `main` (design pass 05 §1, 06 §6).

## How to use this file

### Column legend

| Column | Meaning |
|---|---|
| ID | `T-NNNN`, unique; increasing in roadmap order except for rows added after v1 (see [Rolling-wave rule](#rolling-wave-rule)). Never renumbered, never reused. The task file is `tasks/T-NNNN-<slug>.md`, branch `t/NNNN-<slug>`. |
| Title | What the PR delivers. `[HS]` = touches a hotspot file (see below); such a task is always type `infra` or `contract`, always in lane `H`, and never runs next to another `H` task. |
| Type | `contract` (API/schema + stubs + contract tests), `feat`, `fix`, `refactor`, `test` (automated or manual device/playtest; manual results go to `docs/qa/`), `content` (pipeline run, overrides, hand-made levels), `infra` (CI, Makefile, project.godot, export, plugins), `spike` (time-boxed, output = report + decision, code not merged into `game/`), `docs` (source docs, decisions, gates; human-only external work such as store consoles records its outcome in `docs/store/`). |
| Area | Exactly one area from `ARCHITECTURE.md#areas` (closed list). Primary area; `touch` globs may name a few files elsewhere (e.g. a registry entry), and `tasks.py plan` checks overlaps. |
| Depends | Task IDs that must be `done` first. They always appear earlier in roadmap order: normally a lower ID, but a task added during re-planning may carry a higher ID and is listed above its dependents. The graph is acyclic; `tools/tasks.py lint` checks cycles, unknown IDs and roadmap order, not numeric order. `—` = none. |
| Lane | Parallel queue inside a phase. Tasks in one lane run one at a time; tasks in different lanes may run at once when their deps are done. Within a phase every area belongs to exactly one lane, so two lanes never touch the same area. |
| Exec | `SOL` = GPT-5.6 Sol via ChatGPT + GitHub MCP (no runtime; CI is its test loop; decision 0006). `CHEAP` = Gemini Flash / GPT Luna agent in the Docker image (runs `make check`). `OPUS` = Claude Opus in Claude Code (has a runtime). `HUMAN` = Chris. Combos (`OPUS+HUMAN`, `CHEAP+HUMAN`, `SOL+HUMAN`) mean both are genuinely needed: the model does the work, Chris decides, tests on device or does the external step. |
| Think | Reasoning effort for the model executor: `low`, `med`, `high`, `xhigh`. `—` for HUMAN-only tasks. |
| UI | Impact on UI/UX/design: `none`, `low`, `med`, `high`. `high` = task must cite a mockup or screen spec (`DESIGN.md#screen-specs`) and needs Chris's device review; screenshots per `DESIGN.md#pr-screenshot-rules`. On HUMAN, gate and playtest rows `high` means Chris judges on device; no citation required. |
| Risk | `low` / `med` / `high` per design pass 06 §2 (front-matter spells `med` as `medium`): high = save, economy, IAP, ads, consent, pipeline validators/export, contracts, project.godot, released slots; med = new `core/` logic, player-visible behaviour, new analytics event; low = UI from existing components, tests, mechanical. Drives the review path (07 §7). |
| Refs | Requirement IDs from `PRODUCT.md` (`FR-AREA-NN`, `NFR-NN`; `FR-X-01..05` = inclusive range) and doc anchors (`DESIGN.md#level-motion`, `GAME_DESIGN.md#hints`). `dpNN §x` = design pass file `docs/design-pass/NN-*.md`, section x. `GAME_DESIGN.md`, `ARCHITECTURE.md`, `CONTENT.md`, `TESTING.md` anchors are created by Phase 0 docs tasks. |

Hotspot files (only `infra`/`contract` tasks, serially, lane `H`): `game/project.godot` (includes the
autoload list), `game/export_presets.cfg`, save schema (`game/services/save.gd` + migrations + golden
files), LevelData / manifest / daily-pack schema (`pipeline/schema/`), `.github/workflows/*`,
`Makefile`, `game/addons/*`. Lane `H` also holds the remaining `infra`/`ci` work and, per phase,
the service areas that own a hotspot (`services.save`, `services.content`).

### Rolling-wave rule

- **Phase 0 and Phase 1 rows are firm.** Sol writes their task files wave by wave as written here
  (titles may be sharpened; scope may not grow without Chris).
- **Phase 2 and Phase 3 rows are planned, not frozen.** At the start of each wave Sol re-plans the next
  3–6 tasks of an epic on fresh `main` (current APIs, merged contracts, playtest and audit findings).
  Allowed: split a row, merge rows, change deps/lane/exec, drop a row that turned out unnecessary
  (mark it `(dropped: reason)` here, never delete the ID).
- **IDs stay stable.** New tasks take the next free ID at the end of the range reserved for their
  phase and are inserted in roadmap order above the rows that depend on them, so roadmap order and ID
  order diverge only for added tasks. v2 already added T-0144, T-0326 … T-0329 and T-0475 … T-0483 this
  way, and moved a few rows (T-0226, T-0315 into E12; T-0258 into E25; T-0320 above T-0318; T-0421
  above T-0416; T-0474 below T-0476).

| Phase | Reserved ID range | Used by v1 |
|---|---|---|
| Phase 0 Foundation | T-0001 … T-0099 | T-0001 … T-0051 |
| Phase 1 Core Prototype | T-0100 … T-0199 | T-0100 … T-0144 |
| Phase 2 Vertical Slice | T-0200 … T-0399 | T-0200 … T-0329 |
| Phase 3 Production | T-0400 … T-0599 | T-0400 … T-0483 |
| Later (data-gated) | T-0600 … | none yet (epic-level list only) |

Epics: E00–E04 Phase 0, E05–E10 Phase 1, E11–E25 Phase 2, E26–E37 Phase 3, E40+ Later. Each epic gets
`tasks/epics/ENN-<slug>.md` from `tasks/EPIC_TEMPLATE.md` when its first wave is planned; decisions and
contracts live there, not in this file.

### How Sol turns a row into a task file

1. Check the row's deps are `done` on `main` and the epic's open questions for this wave are empty.
2. Run `make context` (`tools/context_pack.py`) for the row's area and refs; read the cited doc anchors.
3. Copy `tasks/TEMPLATE.md` to `tasks/T-NNNN-<slug>.md`. Front-matter: `id`, `title`, `epic`, `type`,
   `area`, `risk` from the row (`med` → `medium`); `think` and `ui` from the row (Think `—` → `none`);
   `executor` = `sol` / `cheap` / `human` (OPUS rows use `human` + a note, because Opus sessions are
   started by Chris); `depends_on` from the row; `touch` = the smallest glob allowlist inside the area
   (plus exact registry/locale files); `status: ready`; `revision: 1`.
4. Body: Goal, Context (quote the 1–3 rules that matter from the Refs anchors), Current state (from the
   context pack; preflight list), Specification (Behavior, Interface for contracts, States, Edge cases,
   UX with components and tokens for `UI ≥ med`, Analytics with registry entries), Out of scope, Tests
   (given/when/then with concrete values), Acceptance, Rollback for `risk: high`.
5. Size check: < ~300 changed lines, ≤ ~5 production files, one area. Bigger → split into new IDs.
6. `tools/tasks.py lint` passes; commit the wave in one `plan/ENN-waveN` PR; Chris skims and merges.
7. `tools/tasks.py plan` releases runnable tasks; Sol never assigns two tasks in the same area or lane.

## Phase overview

| Phase | Goal | Exit criteria (design pass 11 §4) | Lanes | Max concurrent | Chris checkpoints |
|---|---|---|---|---|---|
| 0 Foundation | Everything that must exist before agents deliver tasks in series | S1 passed (or engine changed); `make check` green in CI; a cheap model merged ≥3 tasks without Chris fixing code; docs v1 merged; language decisions recorded | DOC, ADM, H, SPK-P, SPK-W, SPK-C, SPK-G, D1–D4 | 1 repo-changing task (lane H), paced by Chris's Sol sessions; docs + spikes by other actors beside it; dry run: 4 | T-0011, T-0012, T-0023, T-0027/28 device runs, T-0029, T-0030, T-0033 engine gate, T-0050, T-0051 (T-0027/28 are OPUS+HUMAN sessions on Chris's machine) |
| 1 Core Prototype | "Is it fun?": raw visuals, perfect swipe, 30–50 PL levels, Android build | Fun gate: 5 outsiders play ≥20 min without instructions; swipe without perceivable lag on the reference low-end Android; Chris decides go / fix core / stop | H, BRD, WHL, FLOW, PRG, PIPE, CPL, SUP, GATE | 3 agent tasks + Chris | T-0129, T-0130, T-0136, T-0139, T-0140, T-0141, T-0143 |
| 2 Vertical Slice | First 30 minutes at release quality on Android + iOS | Device checklist (`TESTING.md`) passes on 3 reference devices; IAP and ads work in sandbox; Opus slice audit without critical findings; Chris: "a game I would download myself"; closed testing / TestFlight started | H, DOC, UI, ART, LVL, ECO, META, DATA, TOOL, PLAT, SCR, PIPE, CPL, STORE | 4 agent tasks + Chris | Key gates: T-0203 decisions, T-0204/T-0205 taste, T-0226 iOS build loop, T-0221 gallery, T-0237 economy, T-0267 ads device test, T-0268 IAP products, T-0275 IAP device test, T-0282 feel, T-0305/T-0307 content, T-0318 closed test, T-0322–T-0325 (full list in [Chris checkpoints](#chris-checkpoints)) |
| 3 Production | Content machine, daily + streak, soft launch, data loop, then EN, then DE | Derived (11 §4 lists scope, not criteria): release pipeline ships from CI; daily + streak + ~500 PL levels live in soft launch; ad-frequency experiment read out; dictionary and difficulty loops running; EN content shipped; DE content shipped | H, DOC, UI, DAILY, META, LVL, PLAT, DATA, SCR, TOOL, PIPE, ART, CPL, CEN, CDE, STORE | 5–6 agent tasks (review-bound) | T-0402, T-0427, T-0434, T-0438, T-0440, T-0443, T-0447, T-0450, T-0451, T-0452, T-0455, T-0457, EN/DE reviewer tasks, T-0477 exit |

Phase 2 note: closed testing (T-0318) does **not** wait for the slice to be finished. It needs a store
name, a store listing with icon (T-0320, T-0310), a privacy policy, the data-safety and rating forms and
a signed AAB, and its 14-day clock gates production access in Phase 3. Start it with the first stable P2
build.

## Critical path

### To the fun gate (end of Phase 1)

```
T-0001 repo ─► T-0002 seed ─► T-0003 decision 0001 (proposed) ─► T-0026 S1 plan ─┐
T-0012 store accounts + devices ──────────────────────────────────────────────────┴─► T-0027 S1 Android ─► T-0028 S1 iOS ─┐
T-0003 ─► T-0013 layout ─► T-0014 image ─► T-0029 S2 swipe ──────────────────────────────────────────────────────────────────┴─► T-0033 ENGINE GATE

T-0033 ─► T-0034 autoloads ─► T-0036 Save v1 ─► T-0043 Nav (boot → level) ─► T-0044 boot smoke ─► T-0045 dry-run wave ─► T-0046..T-0049 ─► T-0050 retro ─► T-0051 P0 exit
T-0051 ─► T-0100 BoardState ─► T-0101 ─► T-0115 LevelController ─► T-0116 level scene ─► T-0117 HUD ─► T-0118 complete ─┐
T-0051 ─► T-0120 pipeline ─► T-0121 … T-0126 validate ─► T-0127 export ─► T-0131 content ─► T-0140 Chris plays ─────────┤
T-0136 keystore ─► T-0137 Android build ────────────────────────────────────────────────────────────────────────────────┤
T-0118 ─► T-0144 P1 cues + strings ─────────────────────────────────────────────────────────────────────────────────────┤
                                                                                                                        └─► T-0139 wheel feel on device ─► T-0141 playtest ─► T-0143 FUN GATE
```

- Phase 0: the longest chain is lane H, serial by design (repo → image → toolchain → task and scope
  tools → CI → branch protection → contracts → dry run, about 18 tasks, each paced by a Sol session
  Chris opens). S1 (store accounts → Android → iOS → engine gate) runs beside it and gates E03; start
  T-0012 on day 1, because identity verification can take weeks.
- Phase 1: the wheel-to-level chain (T-0103 … T-0118, then the debug overlay and wheel feel) and the
  pipeline lane (T-0120 … T-0131, 9 serial tasks + Chris) are about equally long; start both on the
  first day of Phase 1.
- Game feel (T-0139) is iterative and human-bound; plan at least two device rounds.

### To soft launch and Phase 3 exit

```
T-0143 ─► T-0200..T-0203 GAME_DESIGN + Opus + Chris ─► T-0229 Save v3 ─► T-0232/T-0233 Economy ─► T-0261 Monetization contract
        ─► T-0263 consent/ads ─► T-0264 AdMob plugin ─► T-0265 consent ─► T-0266 ads ─► T-0267 device test ─────────────┐
T-0208 ─► T-0226 iOS build loop (every iOS adapter and device test needs it) ───────────────────────────────────────────┤
T-0269 IAP plugins ─► T-0271 IAP flow ─► T-0272 Play ─► T-0273 StoreKit ─► T-0275 IAP device test ──────────────────────┤
T-0204 visual direction ─► T-0206 tokens ─► T-0207 theme ─► T-0211..T-0220 components (serial) ─► T-0276..T-0283 level ─┼─► T-0322 checklist ─► T-0324 Opus audit ─► T-0325 P2 EXIT
T-0207 ─► T-0222..T-0225 level game feel ─► T-0276 ─────────────────────────────────────────────────────────────────────┤
T-0328 analytics P2b ─► T-0258 funnels ─────────────────────────────────────────────────────────────────────────────────┘
T-0312 name + T-0310 icon ─► T-0320 listing; T-0313/T-0314 privacy + forms; T-0315 AAB ─► T-0318 CLOSED TEST (≥14 days) ───────────┐
T-0325 ─► T-0400..T-0402 P3 decisions ─► T-0413 Save v4 / T-0414 core/daily ─► T-0415 ─► T-0416 ─► T-0424 streak ─► T-0427 device ─┤
T-0405 landmarks ─► T-0407 daily pool ─► T-0408 scale ─► T-0437..T-0440 content to 500 ────────────────────────────────────────────┼─► T-0449 audit ─► T-0450 ─► T-0451 GO/NO-GO
T-0409/T-0410 release pipeline ────────────────────────────────────────────────────────────────────────────────────────────────────┘
T-0451 ─► T-0452 data review ─► calibration, dictionary loop, PL to 1000 (E34) ─► EN (E35) ─► DE (E36) ─► T-0477 P3 EXIT
```

- By dependency count the longest Phase 2 chain is visual direction → tokens → theme → the serial
  `ui.components` lane (T-0211 … T-0220) → Level integration (T-0276 … T-0283). Start T-0204 the day the
  fun gate passes.
- Platform integration (PLAT lane: consent → ads → IAP, each with device tests) is shorter but the least
  predictable; it joins Level integration at T-0278 through T-0274. The iOS build loop (T-0226) comes
  early in P2 because every iOS adapter and device test depends on it.
- Content to 500 levels needs Chris's QA sampling (T-0438, T-0440); that is the Phase 3 human bottleneck.

## Phase 0 — Foundation

Serial on the repo. Docs, spikes and accounts run beside it because different actors do them.

### E00 Docs and decisions
Goal: source-of-truth docs v1 and Phase 0 decisions in the repo. Exit: docs v1 merged and approved by
Chris after one Opus second opinion.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0001 | Repo (public until P2 content production, Chris 2026-10-02: free Actions and branch protection on GitHub Free); import PRODUCT.md, DESIGN.md, ROADMAP.md, decisions 0004–0006 and the design pass as read-only `docs/design-pass/` | docs | docs | — | DOC | HUMAN | — | none | low | dp04 §1, dp04 §2 |
| T-0002 | Adopt seed: AGENTS.md (+ CLAUDE.md / GEMINI.md one-liners), tasks/TEMPLATE.md, tasks/EPIC_TEMPLATE.md, PR template; epic files E00–E04 | docs | docs | T-0001 | DOC | SOL | med | none | low | seed/AGENTS.md, dp06 §2, dp07 §6 |
| T-0003 | Decision 0001 engine, status proposed: Godot 4.x.y conditional on S1, failure criteria, plan B Unity 6 LTS | docs | docs | T-0002 | DOC | SOL | med | none | med | dp02 §3 |
| T-0004 | Decision 0002 content in packs: no runtime dictionary, complete bonus lists, packs + manifest | docs | docs | T-0002 | DOC | SOL | low | none | low | dp03 §1, FR-CORE-02, FR-CONT-01 |
| T-0005 | Decision 0003 local device date for daily and streak; no clock-rollback protection | docs | docs | T-0002 | DOC | SOL | low | none | low | dp03 §4.5, FR-DAILY-01, FR-DAILY-06 |
| T-0006 | GAME_DESIGN.md v1 from PRODUCT.md: every `GAME_DESIGN.md#…` anchor PRODUCT cites; copies the canonical config key list and defaults from `PRODUCT.md#first-10-minutes-timeline` unchanged (`unlocks.*_slot`, `consent.*_after_slot`, `ads.interstitial.first_slot`, `hint.offer_*`) | docs | docs | T-0002 | DOC | SOL | high | low | med | PRODUCT.md#functional-requirements, PRODUCT.md#first-10-minutes-timeline, DESIGN.md#feature-unlock-gating, dp03 §6 |
| T-0007 | ARCHITECTURE.md v1 from dp03/dp04: layers, dependency rules, closed autoload list `#autoloads`, `#areas` (closed area list → paths; boot scene under `services.nav`), hotspots, `#save`, IAP flow, `#platform`, registries, owner of the `settings` save section (no new autoload) | docs | docs | T-0002 | DOC | SOL | high | none | med | dp03 §2, dp03 §3, dp03 §4, dp03 §5, dp04 §1, FR-PLAT-01, FR-SAVE-01 |
| T-0008 | CONTENT.md v0 from dp09: stages and artifacts, `#level-schema`, `#manifest`, `#slot-policy`, `#curve`, tiers, overrides, QA sampling, determinism | docs | docs | T-0002 | DOC | SOL | high | none | med | dp09, decision 0004, FR-CONT-01..06 |
| T-0009 | TESTING.md v1 from dp08: pyramid, test matrix, device checklist, release checklist, reference devices | docs | docs | T-0002 | DOC | SOL | med | none | low | dp08, NFR-15 |
| T-0010 | Opus second opinion on PRODUCT + ARCHITECTURE, including save format, LevelData schema, slot policy and IAP flow (one session; findings list) | docs | docs | T-0006, T-0007, T-0008 | DOC | OPUS | high | low | med | dp05 §2, dp11 §3 |
| T-0011 | Apply accepted Opus findings to the docs; Chris approves docs v1 | docs | docs | T-0009, T-0010, T-0004, T-0005 | DOC | SOL+HUMAN | med | low | med | dp04 §2 |

### E01 Repo, tooling, CI and accounts
Goal: one command of truth (`make check`), CI that is Sol's test loop, scope enforcement, accounts started.
Exit: CI green on `main`, branch protection on, tools usable by executors.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0012 | Store accounts: Google Play Console (personal vs organization; closed-test rule applies to new personal accounts, verify) + Apple Developer; identity verification; pick and provision reference devices (Q13); Play payments profile (needed for IAP tests in S1); EU trader status (DSA) and the public contact address decision | docs | store | T-0001 | ADM | HUMAN | — | none | med | PRODUCT.md#compliance-and-store-requirements, DESIGN.md#reference-devices |
| T-0013 | Repo layout per dp04 + `game/project.godot`: Godot 4.x.y pinned to the version decision 0001 names, portrait, 1080×1920 canvas_items/expand, typed warnings as errors; .gitignore; README [HS] | infra | infra | T-0003 | H | SOL | med | low | high | dp04 §1, dp02 §4, DESIGN.md#layout |
| T-0014 | Docker image + devcontainer: pinned Godot headless + Android export templates, Android SDK + JDK 17 + Gradle cache, gdtoolkit, Python + uv, make; publish workflow to GHCR; the CI image build is the test loop [HS] | infra | infra | T-0013 | H | SOL | med | none | high | dp02 §4, dp07 §8, decision 0006 |
| T-0015 | GUT pinned in `game/addons/gut` + one sample unit test running headless [HS] | infra | infra | T-0014 | H | CHEAP | low | none | high | dp02 §4, dp08 §3 |
| T-0016 | Python toolchain: uv workspace, pyproject for `pipeline/` and `tools/`, ruff, pytest, hypothesis, pinned gdtoolkit; sample tests | infra | tools | T-0014 | H | CHEAP | low | none | low | dp02 §4 |
| T-0017 | Makefile: check, test, lint, fmt, run, pipeline-test, content-validate, registries, context, review, board, plan (targets with missing inputs skip explicitly) [HS] | infra | infra | T-0015, T-0016 | H | SOL | med | none | high | dp04 §1, dp07 §5 |
| T-0018 | CI v1 `ci.yml`: format, lint, godot-import + log scan, unit + integration (GUT), pipeline pytest when `pipeline/` changes; readable failure output [HS] | infra | ci | T-0017 | H | SOL | high | none | high | dp07 §5, decision 0006, NFR-15 |
| T-0019 | `tools/tasks.py` lint / board / plan + tests (front-matter schema, areas from ARCHITECTURE.md#areas, acyclic deps, plan = ready ∧ deps done ∧ disjoint area/touch vs in_progress); lint / board / plan read only `tasks/T-*.md` (ROADMAP.md, TEMPLATE.md, EPIC_TEMPLATE.md and `tasks/epics/` ignored) | infra | tools | T-0016, T-0007 | H | SOL | high | none | med | dp05 §4, dp06 §1, dp06 §6 |
| T-0020 | `tools/check_scope.py` + tests: changed files ⊆ touch ∪ own task file; task resolved from branch `t/NNNN-*` | infra | tools | T-0019 | H | SOL | med | none | med | dp07 §2, dp07 §5 |
| T-0021 | `tools/count_tests.py` + tests: test count never drops vs `main`; label exception | infra | tools | T-0020 | H | SOL | low | none | low | dp07 §5 |
| T-0022 | CI v2: add scope, tasks-lint, test-count jobs [HS] | infra | ci | T-0018, T-0021 | H | SOL | med | none | high | dp07 §5 |
| T-0023 | Branch protection: squash only, required checks, up-to-date branches, no force push, auto-delete; labels risk / type / test-count-exception | infra | ci | T-0022 | H | HUMAN | — | none | med | dp07 §3 |
| T-0024 | `tools/context_pack.py`: repo map, `## @api` signatures, doc sections by anchor, open tasks | infra | tools | T-0019 | H | SOL | med | none | low | dp05 §4, decision 0006 |
| T-0025 | `tools/review_pack.py T-NNNN`: task + diff + cited doc sections + reviewer checklist | infra | tools | T-0024 | H | SOL | low | none | low | dp07 §7 |

### E02 Spikes and engine gate
Goal: evidence before production code. S5 (can Sol work on the repo directly) is resolved by decision
0006 and has no task. Exit: engine decision accepted; dictionary sources decided; generator feasible.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0026 | S1 plan: plugin survey for the candidate Godot version (AdMob + UMP, Play Billing, StoreKit 2, Firebase vs HTTP analytics, Crashlytics vs Sentry, iOS haptics), test matrix, pass/fail criteria; decide the final Android applicationId and iOS bundle ID (permanent after the first upload; neutral, without the working title) and a separate `.spike` id for throwaway apps | spike | platform.analytics | T-0003 | SPK-P | SOL | high | none | med | dp02 §3, dp11 §1, PRODUCT.md#compliance-and-store-requirements |
| T-0027 | S1 Android: throwaway project on the low-end Android; rewarded + interstitial (test units) with UMP; Play Billing consumable + non-consumable + restore (internal track); analytics event and crash visible in dashboards; haptics; report `docs/spikes/S1-android.md` (Claude Code on Chris's machine; the same session family continues into T-0028) | spike | platform.ads | T-0026, T-0012 | SPK-P | OPUS+HUMAN | xhigh | none | high | dp02 §3, FR-PLAT-01, FR-ADS-04, FR-IAP-03 |
| T-0028 | S1 iOS: same matrix on iPhone (StoreKit 2 sandbox incl. restore, UMP, ATT, native haptics, silent switch); report `docs/spikes/S1-ios.md` | spike | platform.iap | T-0027 | SPK-P | OPUS+HUMAN | xhigh | none | high | dp02 §3, FR-CONSENT-04, FR-AUDIO-04 |
| T-0029 | S2 swipe: throwaway letter wheel on the low-end Android (input path, Line2D, haptic tick); Chris rates latency; report with recommended input approach | spike | level.wheel | T-0012, T-0014 | SPK-W | CHEAP+HUMAN | high | high | med | dp11 §4, NFR-01, FR-WHEEL-02 |
| T-0030 | S3a PL word sources and licences: SJP.pl variants, PoliMorf / Morfeusz, frequency data (wordfreq CC BY-SA vs corpus); count of 3–7-letter words; Chris decides → decision NNNN-pl-word-sources (Q11) | spike | pipeline.ingest | T-0002 | SPK-C | SOL+HUMAN | high | none | high | dp09 §8, decision 0004, PRODUCT.md#compliance-and-store-requirements |
| T-0031 | S3b classification trial: 200 PL words through two cheap models (sensitivity, familiarity), agreement rate, cost per 1k words; Chris reviews disagreements | spike | pipeline.classify | T-0030, T-0016 | SPK-C | CHEAP+HUMAN | med | none | med | dp09 §3 |
| T-0032 | S4 generator prototype: Python, 50 levels from a small PL list, ASCII grids, quality notes; code kept in `pipeline/spikes/s4/` as the P1 starting point | spike | pipeline.grid | T-0016 | SPK-G | CHEAP | high | none | med | dp09 §2, dp11 §4 |
| T-0033 | ENGINE GATE: accept decision 0001 (Godot pinned) or switch to Unity 6 LTS and re-plan the Godot-specific E01 rows (T-0013, T-0014, T-0015, T-0018), E03 and E04; record providers (Q8), min Android API / iOS (Q9), haptics and silent-switch approach, mobile screen-reader support on the pinned version (FR-A11Y-04) → decision NNNN-platform-providers | docs | docs | T-0028, T-0029 | DOC | SOL+HUMAN | high | none | high | dp02 §3, NFR-09, PRODUCT.md#open-questions, FR-A11Y-04 |

### E03 Architecture skeleton (contracts)
Goal: the contracts every later task builds against, built serially by Sol. Blocked by the engine gate.
Exit: autoloads, Platform with Fakes, Save v1, registries + CI check, LevelData schema + Content + bot
test, Nav boot → level, boot smoke green.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0034 | Autoload stubs for the closed list (Config, Save, Progress, Economy, Daily, Content, Monetization, Analytics, Audio, Nav, Events, Platform) registered in project.godot; typed `## @api` stubs; injectable Clock; `run/main_scene` = boot scene stub under `services.nav` per ARCHITECTURE.md#areas [HS] | contract | infra | T-0033, T-0023, T-0011 | H | SOL | high | none | high | dp03 §3, ARCHITECTURE.md#autoloads |
| T-0035 | Platform container + adapter interfaces (ads, iap, analytics, crash, consent, haptics, review, notifications) + no-op Fakes; SDK/Fake selection | contract | infra | T-0034 | H | SOL | high | none | high | FR-PLAT-01, ARCHITECTURE.md#platform, dp02 §3 |
| T-0036 | Save v1: `schema_version`, sections, `install_id`, atomic temp + rename, `.bak` fallback, corrupt → clean start + `Events.save_corrupted`, migration chain framework, golden `tests/fixtures/save/v1.json`, interruption test [HS] | contract | services.save | T-0034 | H | SOL | xhigh | none | high | FR-SAVE-01..05, FR-SAVE-07, NFR-13, dp03 §4.6, ARCHITECTURE.md#save |
| T-0037 | Config registry: `data/config/*.json` entry schema (default, type, range, description, owner), typed `Config.get` with validation; first files `unlocks.json`, `hint.json` (keys and defaults from GAME_DESIGN.md#config-key-registry) | contract | services.config | T-0034 | H | SOL | high | none | high | FR-CFG-01, dp03 §4.7 |
| T-0038 | Analytics registry: `data/analytics/*.json` schema; `Analytics.track` validation (debug builds fail loudly); queue stub to the Fake adapter | contract | services.analytics | T-0035 | H | SOL | high | none | high | FR-ANL-01, dp03 §4.8 |
| T-0039 | Registries CI check: `tools/check_registries.py` (every `Analytics.track` / `Config.get` literal registered; registry files schema-valid) wired into Makefile + CI [HS] | infra | ci | T-0037, T-0038 | H | SOL | med | none | high | dp07 §5, FR-CFG-01, FR-ANL-01 |
| T-0040 | LevelData JSON Schema + manifest schema in `pipeline/schema/` (shared by pipeline and game tests), `schema_version` field [HS] | contract | services.content | T-0011 | H | SOL | xhigh | none | high | CONTENT.md#level-schema, CONTENT.md#manifest, FR-CONT-01, FR-CONT-02 |
| T-0041 | Content autoload: manifest + pack loading, LevelData typed class (`core/board/level_data.gd`, tiles as indices), level by slot; fixture pack (3 levels) | contract | services.content | T-0040, T-0034 | H | SOL | high | none | high | FR-CONT-01, FR-CONT-02, FR-CORE-03, dp03 §4.1 |
| T-0042 | Runtime bot integration test: every shipped level (fixtures + `game/content/`) loads; each level word is formable from tile indices and placed on the grid (upgraded to BoardState in T-0119) | test | services.content | T-0041 | H | CHEAP | med | none | med | FR-CONT-07, dp08 §2 |
| T-0043 | Nav: screen state machine Boot → Level (current slot) ↔ Home (empty; reachable from debug in P1); boot loads Save, Config, Content manifest | contract | services.nav | T-0036, T-0037, T-0041 | H | SOL | med | low | high | dp03 §3, DESIGN.md#screen-map, FR-ONB-01 |
| T-0044 | Boot smoke integration test: headless boot with Fakes reaches Level with no errors in the log | test | services.nav | T-0043 | H | CHEAP | low | none | low | dp08 §2, FR-PLAT-01 |

### E04 Workflow dry run
Goal: prove the loop plan → parallel cheap executors → CI → review → merge on 4 small tasks.
Exit: ≥3 merged without Chris fixing code; template and AGENTS.md corrected; Phase 0 exit signed.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0045 | Write the dry-run wave (4 task files, epic E04) and release it with `tasks.py plan` | docs | docs | T-0044, T-0039, T-0042, T-0025 | DOC | SOL | med | none | low | dp05 §1, dp06 §4 |
| T-0046 | Fake haptics: records pattern calls, respects `haptics_enabled`, debug log; tests | feat | platform.haptics | T-0045 | D1 | CHEAP | low | none | low | FR-AUDIO-02, FR-PLAT-01 |
| T-0047 | Config registry tests: type and range rejection cases for `unlocks.json` and `hint.json` | test | data.config | T-0045 | D2 | CHEAP | low | none | low | FR-CFG-01 |
| T-0048 | Debug screen shell: reachable in debug builds only; shows app and content version; reset save | feat | features.debug | T-0045 | D3 | CHEAP | low | low | low | FR-DEBUG-01, FR-DEBUG-06 |
| T-0049 | `Shuffle.permute` pure function + tests (dp06 §4 spec, core part only) | feat | core.board | T-0045 | D4 | CHEAP | low | none | low | FR-WHEEL-08, FR-HINT-06, dp06 §4 |
| T-0050 | Dry-run retrospective: escalations, red CI runs, Chris's review minutes; fixes to TEMPLATE.md and AGENTS.md | docs | docs | T-0046, T-0047, T-0048, T-0049 | DOC | SOL+HUMAN | med | none | low | dp05 §4 |
| T-0051 | PHASE 0 EXIT: S1 passed or engine switched, `make check` green in CI, ≥3 cheap tasks merged without manual code fixes, docs v1 merged, language and source decisions recorded | docs | docs | T-0050, T-0030, T-0031, T-0032, T-0033 | DOC | HUMAN | — | none | low | dp11 §4 |

## Phase 1 — Core Prototype

Raw but token-driven visuals (`tokens.gd` v0), no economy/ads/IAP/meta/analytics. Android only.

### E05 Board logic
Goal: word matching and hints as pure, tested `core/board`. Exit: all FR-CORE rules unit-tested.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0100 | BoardState contract: `AttemptResult {kind LEVEL/BONUS/ALREADY_FOUND/INVALID, word, cells_to_reveal}`, `evaluate(tiles)`, `reveal_cell`, `is_complete`, `to_dict`/`from_dict`; contract tests | contract | core.board | T-0051, T-0041 | BRD | SOL | high | none | high | FR-CORE-01..03, GAME_DESIGN.md#word-classes, dp03 §4.1 |
| T-0101 | BoardState implementation: repeated letters, length < 3 ignored, banned = INVALID, intersections counted once, completion fires once, bonus counted once | feat | core.board | T-0100 | BRD | CHEAP | med | none | med | FR-CORE-01, FR-CORE-04..07, FR-BONUS-01 |
| T-0102 | `HintLogic.next_cell`: deterministic order per GAME_DESIGN.md#hints; none on a complete level | feat | core.board | T-0101 | BRD | CHEAP | med | none | med | FR-HINT-01, FR-HINT-02 |

### E06 Letter wheel
Goal: the swipe that decides the game. Exit: wheel meets FR-WHEEL on the reference Android; Chris
accepts the feel (T-0139).

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0103 | Tokens v0: `game/ui/tokens.gd` with provisional values and `Tokens.dur()` | contract | ui.tokens | T-0051 | WHL | SOL | low | low | high | DESIGN.md#tokens, DESIGN.md#tokensgd-shape |
| T-0104 | LetterWheelView + LetterTile contract: `chain_changed` / `word_attempted(PackedInt32Array)`, `set_letters`, `set_locked`, `shuffle(rng) -> bool`; pure geometry helper (slot positions for 3–8 tiles, hit test) with tests; `.gd` API + geometry helper only, the `.tscn` is created in T-0105 | contract | level.wheel | T-0103, T-0041, T-0029 | WHL | SOL | high | low | high | DESIGN.md#letterwheelview, DESIGN.md#lettertile, FR-WHEEL-09 |
| T-0105 | Wheel input: touch down / drag / release, hit radius `Touch.TILE_HIT_RATIO`, no tile twice, backtrack, second finger ignored, `Touch.DRAG_SLOP` | feat | level.wheel | T-0104 | WHL | CHEAP | high | med | med | FR-WHEEL-01, FR-WHEEL-03..05 |
| T-0106 | Line follows the finger every frame with preallocated points; tile selected state; WordPreview building state | feat | level.wheel | T-0105 | WHL | CHEAP | high | med | med | FR-WHEEL-02, FR-WHEEL-06, NFR-01, NFR-02, DESIGN.md#wordpreview-addition |
| T-0107 | WordPreview result states: level, bonus, already found, invalid shake; colour + icon/label | feat | level.wheel | T-0106, T-0101 | WHL | CHEAP | med | med | low | FR-BOARD-05, FR-BOARD-06, DESIGN.md#feedback-matrix |
| T-0108 | Shuffle on the wheel: tiles tween to new slots, wheel locked meanwhile, ignored during drag; shuffle IconButton | feat | level.wheel | T-0107, T-0049 | WHL | CHEAP | low | med | low | FR-WHEEL-08, FR-HINT-06, DESIGN.md#level-motion |
| T-0109 | Haptics: Events → `Platform.haptics`; Android adapter (`tick`, `soft`, `success`, `error`); off switch | feat | platform.haptics | T-0046, T-0104 | WHL | CHEAP | med | low | med | FR-WHEEL-07, FR-AUDIO-02 |

### E07 Board view, level flow and progress
Goal: a playable level loop that saves and resumes. Exit: complete → next level with no loading screen;
kill mid-level loses at most the current attempt.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0110 | Save schema v2: `progress` section (current_slot, highest_completed_slot, level_state, per-language key) + migration v1→v2 + golden file [HS] | contract | services.save | T-0100, T-0036 | H | SOL | xhigh | none | high | FR-SAVE-04, FR-PROG-01, FR-CORE-08, ARCHITECTURE.md#save |
| T-0111 | Progress service contract: current slot, `complete_level(slot)`, save/restore level state, Events | contract | services.progress | T-0110 | PRG | SOL | high | none | high | FR-PROG-01, FR-PROG-02, dp03 §4.2 |
| T-0112 | Progress service implementation: save on word found, level complete and app background; resume mid-level | feat | services.progress | T-0111 | PRG | CHEAP | med | none | high | FR-CORE-08, FR-SAVE-05, FR-PLAT-05, NFR-13 |
| T-0113 | BoardView + GridCell (P1): grid from LevelData coordinates, fit to rect, never scroll, cell states | feat | level.board | T-0041, T-0103 | BRD | CHEAP | med | med | low | FR-BOARD-01, FR-BOARD-02, DESIGN.md#boardview, DESIGN.md#gridcell, DESIGN.md#level-screen-geometry |
| T-0114 | Board feedback (P1): letters animate into cells, ALREADY_FOUND highlight, hinted cell state | feat | level.board | T-0113, T-0101 | BRD | CHEAP | med | med | low | FR-BOARD-03, FR-BOARD-04 |
| T-0115 | LevelController contract: `word_attempted` → `BoardState.evaluate` → view calls + Events (word_found, bonus_found, already_found, invalid_word, level_completed) | contract | level.flow | T-0101, T-0104, T-0111 | FLOW | SOL | high | low | high | dp03 §4.1, FR-CORE-01 |
| T-0116 | Level scene (P1) per DESIGN.md#level-p1-provisional + LevelController implementation | feat | level.flow | T-0115, T-0113, T-0108, T-0043 | FLOW | CHEAP | med | med | med | DESIGN.md#level-p1-provisional, DESIGN.md#flow-level-loop |
| T-0117 | HUD (P1): level number, bonus count text, free unlimited hint button (disabled on complete), shuffle wiring | feat | level.hud | T-0116, T-0102 | FLOW | CHEAP | low | med | low | FR-HINT-01, FR-HINT-02, FR-HINT-06, FR-BONUS-01 |
| T-0118 | Level complete (P1): minimal layer, Continue; next level preloaded during completion, no loading screen | feat | level.flow | T-0117, T-0112, T-0114 | FLOW | CHEAP | med | med | med | FR-BOARD-07, FR-PROG-02, NFR-03, DESIGN.md#flow-level-complete |
| T-0119 | Bot test upgrade: every shipped level is completed through `BoardState.evaluate` without hints | test | services.content | T-0101, T-0042 | PRG | CHEAP | low | none | low | FR-CONT-07, FR-ECON-07 |

### E08 Pipeline v0 and P1 content
Goal: reproducible 30–50 PL levels + ~10 hand-made from a real pipeline. Exit: packs exported, validated
in CI, played by Chris.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0120 | Pipeline skeleton: package `wordgame_pipeline`, `wg` CLI, stage artifact contract (`pipeline/build/<lang>/<stage>/`), per-language config loader (`pl.yaml`) | contract | pipeline.ingest | T-0051, T-0030, T-0040 | PIPE | SOL | high | none | high | dp09 §1, dp09 §9 |
| T-0121 | Ingest + normalize PL: download script + checksum, NFC, uppercase, 32-letter alphabet, length 3..N, drop Q/V/X, proper nouns, abbreviations | feat | pipeline.ingest | T-0120 | PIPE | CHEAP | med | none | med | FR-CONT-05, decision 0004, dp09 §2 |
| T-0122 | Annotate: lemma, part of speech, inflection flag, frequency per the sources decision | feat | pipeline.annotate | T-0121 | PIPE | CHEAP | med | none | med | dp09 §2 |
| T-0123 | Tiers v0: rules from `pl.yaml` + `overrides/pl.csv` (no AI yet); base forms + very frequent inflections → `level_ok` | feat | pipeline.tiers | T-0122 | PIPE | CHEAP | high | none | high | FR-CONT-05, decision 0004 |
| T-0124 | Candidates: anagram index, seed word → letter multiset → all formable words; hand-made YAML input (letters + words) | feat | pipeline.candidates | T-0123 | PIPE | CHEAP | med | none | med | dp09 §2, PRODUCT.md#content-requirements |
| T-0125 | Grid builder hardened from S4: greedy + backtracking, many seeds, best layout; hypothesis tests (connected, no accidental adjacency words, ≤ 10×10, portrait aspect, determinism) | feat | pipeline.grid | T-0124, T-0032 | PIPE | CHEAP | high | none | med | FR-CONT-06, dp08 §2, dp09 §4 |
| T-0126 | Validate v0: formable, tiers, bonus completeness, grid invariants, schema, alphabet | contract | pipeline.validate | T-0125, T-0040 | PIPE | SOL | high | none | high | dp09 §4, FR-CONT-01, FR-CORE-05 |
| T-0127 | Export v0: packs (~100 levels) + manifest with version and hashes into `game/content/pl/`; byte-identical rebuilds | contract | pipeline.export | T-0126 | PIPE | SOL | high | none | high | FR-CONT-01, FR-CONT-02, FR-CONT-06, NFR-14 |
| T-0128 | content-validate CI check: one `wg validate-content` entry (schema + validator; lock file added later without CI edits) wired into Makefile + CI [HS] | infra | ci | T-0127, T-0039 | H | SOL | med | none | high | dp07 §5, FR-CONT-01 |
| T-0129 | Chris seeds `overrides/pl.csv`: review top ~300 level-word candidates (ban weird, archaic, vulgar) | content | content.pl | T-0123 | CPL | HUMAN | — | none | med | dp09 §3, decision 0004 |
| T-0130 | Chris authors ~10 hand-made PL levels (YAML) | content | content.pl | T-0124, T-0129 | CPL | HUMAN | — | none | low | PRODUCT.md#content-requirements |
| T-0131 | Content build P1: 30–50 generated PL levels + hand-made ones, ordered by letter count; PR with QA summary | content | content.pl | T-0127, T-0128, T-0130, T-0119 | CPL | CHEAP | med | none | med | FR-CONT-01, PRODUCT.md#content-requirements |

### E09 Debug, audio, locale and Android build
Goal: tools to judge the prototype on a phone. Exit: debug APK from CI on the reference Android.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0132 | Locale setup: CSV per area with English keys; boot registers all `game/locale/*.csv` translations (no per-file project.godot edits); PL strings for P1 screens | infra | locale | T-0051 | SUP | SOL | low | low | low | FR-LOC-02, dp03 §4.9, DESIGN.md#copy-and-tone |
| T-0133 | Audio: `data/audio/cues.json` registry, `Audio.play(cue)`, placeholder CC0 SFX (tile, word, bonus, invalid, complete) | feat | services.audio | T-0039, T-0051 | SUP | CHEAP | low | low | low | FR-AUDIO-01, dp03 §4.10 |
| T-0134 | Debug screen: jump to slot, show answers, complete level, reset save | feat | features.debug | T-0048, T-0118 | SUP | CHEAP | low | low | low | FR-DEBUG-01 |
| T-0135 | Debug overlay: FPS + input-to-line latency estimate | feat | features.debug | T-0134, T-0106 | SUP | CHEAP | med | low | low | FR-DEBUG-02, NFR-01 |
| T-0136 | Chris: Android upload keystore + GitHub secrets (rule S11) | infra | ci | T-0023 | H | HUMAN | — | none | high | AGENTS.md S11 |
| T-0137 | Android export preset + android-build CI job (debug APK artifact); release export excludes debug feature tag, debug and gallery scenes; Android permissions `VIBRATE` and `INTERNET` enabled in both presets [HS] | infra | infra | T-0136, T-0022, T-0051 | H | CHEAP | high | none | high | FR-PLAT-02, FR-DEBUG-06 |
| T-0138 | CI step: inspect the release export file list; fail if debug code or screens are present [HS] | infra | ci | T-0137, T-0134 | H | CHEAP | low | none | high | FR-DEBUG-06 |
| T-0144 | Level P1 wiring: P1 cues via `Audio.play` on tile, word, bonus, invalid and complete; every Level string from the locale CSV | feat | level.flow | T-0118, T-0132, T-0133 | FLOW | CHEAP | low | low | low | FR-AUDIO-01, FR-LOC-02, DESIGN.md#level-p1-provisional |

### E10 Fun gate
Goal: decide whether the core is worth building on. Exit: Chris's go / fix core / stop decision.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0139 | Wheel game-feel rounds on the low-end Android: Chris plays debug APK, CHEAP adjusts token and config values; OPUS-with-runtime if two rounds fail | feat | level.wheel | T-0109, T-0118, T-0135, T-0137, T-0144 | WHL | CHEAP+HUMAN | high | high | med | NFR-01, NFR-02, DESIGN.md#level-motion |
| T-0140 | Chris plays all P1 levels in debug; flags words and levels → overrides + rebuild | content | content.pl | T-0131, T-0134 | CPL | HUMAN | — | none | low | PRODUCT.md#content-requirements |
| T-0141 | Playtest: 5 outsiders, ≥20 minutes, no instructions, reference Android; notes in `docs/qa/` | test | docs | T-0139, T-0140 | GATE | HUMAN | — | high | low | dp11 §4 |
| T-0142 | Opus P0+P1 architecture check on a context pack: layering, autoload list, Platform adapter interfaces, LevelData + manifest schema, save v1→v2 migration chain, BoardState and LevelController APIs, pipeline stage contracts (before P2 contracts build on them) | docs | docs | T-0118, T-0127 | GATE | OPUS | high | none | low | dp05 §2 |
| T-0143 | FUN GATE (Chris): go / fix core (Sol plans a fix wave from P1 reserve IDs, then rerun T-0141) / stop | docs | docs | T-0141, T-0142, T-0138 | GATE | HUMAN | — | high | high | dp11 §4, PRODUCT.md#goals-and-non-goals |

## Phase 2 — Vertical Slice

Planned rows; Sol re-plans per wave. Order inside the phase: decisions → visual foundation → contracts
(save v3, economy, meta, analytics, monetization) → platform integrations (serial) → level integration
→ screens → content → store → QA.

### E11 Product decisions for the slice
Goal: GAME_DESIGN numbers-free rules and intents for everything P2 builds. Exit: intents, Q2, Q7, Q15 and the
onboarding plan decided by Chris after one Opus session.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0200 | GAME_DESIGN P2: economy intents (units of intent), stars rule (Q2), bonus chest, ad policy keys, P2 IAP catalog; consent and unlock keys exactly as in PRODUCT.md (UMP after slot 1, ATT after slot 6) | docs | docs | T-0143 | DOC | SOL | high | low | med | GAME_DESIGN.md#economy-intents, PRODUCT.md#monetization, PRODUCT.md#open-questions, dp03 §6.2, PRODUCT.md#first-10-minutes-timeline |
| T-0201 | GAME_DESIGN#onboarding: 15-level teaching plan on the PRODUCT.md unlock timeline, coach-mark copy keys (`onboarding.coach.<feature>`), prompt budget | docs | docs | T-0200 | DOC | SOL | high | med | med | FR-ONB-01..05, DESIGN.md#feature-unlock-gating, DESIGN.md#flow-first-launch, PRODUCT.md#first-10-minutes-timeline |
| T-0202 | Opus second opinion: economy intents, monetization rules, onboarding plan (one session) | docs | docs | T-0201 | DOC | OPUS | high | med | med | dp05 §2, dp05 §3, PRODUCT.md#principles |
| T-0203 | Chris decides intents, Q2, Q7, Q15 and the onboarding plan; Sol applies to GAME_DESIGN and lists config defaults | docs | docs | T-0202 | DOC | SOL+HUMAN | med | low | med | PRODUCT.md#open-questions |

### E12 Visual direction, tokens and build setup
Goal: one accepted look expressed as tokens, plus the P2 project settings and the Android release and iOS
build loops every device task needs. Exit: mockups in `docs/design/`, tokens v1, generated theme, iOS
build from CI on an iPhone, release AAB.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0204 | Visual direction: verbal moodboard + 2–3 HTML/CSS mockups of Level with token-named CSS variables; Chris picks on his phone | docs | ui.tokens | T-0143 | UI | OPUS+HUMAN | high | high | med | DESIGN.md#how-we-work, DESIGN.md#tokens-css-mirror, dp10 §1, dp10 §7 |
| T-0205 | Mockups of Home, Level complete, Journey, Shop sheet and onboarding overlays (Level 1 TutorialHand + caption, coach mark); font verification (coverage, `tnum`, OFL) → decision NNNN-fonts; iPad portrait check (Q10); art style document for postcards and icon (Q14) | docs | ui.tokens | T-0204, T-0203 | UI | OPUS+HUMAN | high | high | med | DESIGN.md#typography, DESIGN.md#layout, dp10 §7, PRODUCT.md#open-questions, DESIGN.md#feature-unlock-gating, DESIGN.md#tutorialhand-addition |
| T-0206 | `tokens.gd` v1 values transcribed from the accepted mockups (+ `PaletteHC`) and `docs/design/tokens.css` | contract | ui.tokens | T-0205 | UI | SOL | med | high | high | DESIGN.md#tokens, DESIGN.md#tokensgd-shape |
| T-0207 | Theme generator (EditorScript run headless): 6 variants `theme_<default/hc>_<100/115/130>.tres` | infra | ui.tokens | T-0206 | UI | CHEAP | med | med | med | DESIGN.md#accessibility, FR-A11Y-03 |
| T-0208 | project.godot P2: default theme, FontVariation fonts, `quit_on_go_back = false`, low-processor mode for menus; iOS audio session category per the providers decision (silent switch, T-0228) [HS] | infra | infra | T-0207 | H | CHEAP | med | low | high | DESIGN.md#typography, FR-PLAT-04, NFR-08 |
| T-0226 | iOS export preset + `build-ios.yml` on macOS (manual dispatch + nightly) + signing secrets; iOS haptics plugin if the providers decision needs one [HS] | infra | infra | T-0208 | H | SOL+HUMAN | high | none | high | FR-PLAT-02, FR-AUDIO-02, AGENTS.md S11, decision 0006 |
| T-0315 | Android AAB release export (Play App Signing) + Auto Backup rules for the save file [HS] | infra | infra | T-0137, T-0143 | H | CHEAP+HUMAN | med | none | high | FR-SAVE-06, FR-PLAT-02 |
| T-0209 | Icon set import (Lucide or Material Symbols per T-0205) + licence entries | feat | assets.art | T-0205 | ART | CHEAP | low | low | low | DESIGN.md#iconbutton |
| T-0210 | CI checks: `tools/check_tokens.py` (no raw colours/durations), `tools/check_strings.py` (no literal player-facing strings), generated theme up to date [HS] | infra | ci | T-0207, T-0132 | H | SOL | med | none | high | DESIGN.md#rules-quote-these-into-ui-tasks, FR-LOC-02 |

### E13 Components and gallery
Goal: every catalog component in every state in the gallery. Exit: Chris's device review of the gallery.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0211 | Gallery scene shell: switches for layout class, language, contrast, text size, reduced motion, fake insets; sample strings | feat | ui.gallery | T-0207, T-0210 | UI | CHEAP | med | med | low | DESIGN.md#gallery-scene, NFR-12 |
| T-0327 | CI job: render gallery screenshots (COMPACT / REGULAR / TABLET × PL / PSEUDO, default + HC) with the Compatibility renderer under xvfb + Mesa and attach them as a PR artifact when `game/ui/**`, `game/features/**` or `game/locale/**` change [HS] | infra | ci | T-0211, T-0210 | H | SOL | med | low | high | DESIGN.md#pr-screenshot-rules, dp08 §3, decision 0006 |
| T-0212 | ScreenScaffold (final safe areas, `layout_class`) + TopBar | feat | ui.components | T-0211 | UI | CHEAP | med | high | med | FR-PLAT-03, DESIGN.md#screenscaffold-and-safe-areas, DESIGN.md#layout-classes, DESIGN.md#topbar |
| T-0213 | PrimaryButton, SecondaryButton (ad badge), TextButton | feat | ui.components | T-0212 | UI | CHEAP | low | med | low | DESIGN.md#primarybutton, DESIGN.md#secondarybutton, DESIGN.md#textbutton-addition |
| T-0214 | IconButton (required a11y label) + Badge | feat | ui.components | T-0213, T-0209 | UI | CHEAP | low | med | low | DESIGN.md#iconbutton, DESIGN.md#badge, FR-A11Y-04 |
| T-0215 | CurrencyPill (count-up) + ProgressBar | feat | ui.components | T-0214 | UI | CHEAP | low | med | low | DESIGN.md#currencypill, DESIGN.md#progressbar |
| T-0216 | Sheet (scrim, swipe down, Android back, busy, focus trap) + Toast | feat | ui.components | T-0215 | UI | CHEAP | med | med | med | DESIGN.md#sheet, DESIGN.md#toast, FR-PLAT-04 |
| T-0217 | Card, ListRow, StatePanel | feat | ui.components | T-0216 | UI | CHEAP | low | med | low | DESIGN.md#card, DESIGN.md#listrow, DESIGN.md#statepanel-addition |
| T-0218 | Toggle (check glyph), Slider, NavTab | feat | ui.components | T-0217 | UI | CHEAP | low | med | low | DESIGN.md#toggle, DESIGN.md#slider-addition, DESIGN.md#navtab |
| T-0219 | BonusMeter + HintButton (count, price, loading, highlighted) | feat | ui.components | T-0218 | UI | CHEAP | low | med | low | DESIGN.md#bonusmeter, DESIGN.md#hintbutton |
| T-0220 | RewardBurst (one-shot particles; static under reduced motion) + LocationPostcard (pieces) | feat | ui.components | T-0219 | UI | CHEAP | med | high | low | DESIGN.md#rewardburst, DESIGN.md#locationpostcard |
| T-0326 | TutorialHand component + gallery entry (playing, hidden, reduced-motion arrow) | feat | ui.components | T-0220 | UI | CHEAP | med | med | low | DESIGN.md#tutorialhand-addition, FR-ONB-02 |
| T-0221 | Gallery review on reference devices (low-end Android, iPhone, iPad): all states in COMPACT / REGULAR / TABLET, PL and PSEUDO (+35 %) at 130 %, high contrast; findings become fix tasks | test | ui.gallery | T-0220, T-0326, T-0226, T-0327 | UI | HUMAN | — | high | low | DESIGN.md#design-review-checklist, FR-A11Y-01, FR-A11Y-03, NFR-11, NFR-12 |

### E14 Level game feel
Goal: final level visuals, motion, haptics and audio. Exit: every `DESIGN.md#level-motion` row
implemented and tunable from tokens.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0222 | LetterTile, LetterWheelView, WordPreview final styling on the generated theme | feat | level.wheel | T-0207, T-0208 | LVL | CHEAP | med | high | low | DESIGN.md#letterwheelview, DESIGN.md#lettertile, DESIGN.md#wordpreview-addition |
| T-0223 | GridCell, BoardView final styling + layout-class geometry | feat | level.board | T-0222 | LVL | CHEAP | med | high | low | DESIGN.md#level-screen-geometry, FR-BOARD-02 |
| T-0224 | Level motion A: letter flight to grid, landing, word-complete flash, level-complete wave | feat | level.board | T-0223 | LVL | CHEAP | high | high | low | DESIGN.md#level-motion, FR-BOARD-03 |
| T-0225 | Level motion B: bonus flight to meter, already-found pulse, invalid shake, hint/reveal motion; reduced-motion mapping | feat | level.wheel | T-0224, T-0219 | LVL | CHEAP | high | high | low | DESIGN.md#level-motion, DESIGN.md#reduced-motion-mapping, FR-A11Y-02 |
| T-0227 | iOS haptics adapter: native patterns verified on iPhone; Chris runs the iOS build on the iPhone each round; OPUS-with-runtime after two failed rounds | feat | platform.haptics | T-0226 | LVL | CHEAP+HUMAN | med | med | med | FR-AUDIO-02 |
| T-0228 | Audio service final: sound and music volumes, pitch variation from registry, pause/resume API for ads, iOS silent switch | feat | services.audio | T-0133, T-0143, T-0226 | LVL | CHEAP | med | low | med | FR-AUDIO-03, FR-AUDIO-04, FR-ADS-08 |

### E15 Save v3 and economy
Goal: coins, items, rewards and bonus chest with a tested economy and a simulator. Exit: `econ_sim`
report matches the intents Chris approved.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0229 | Save schema v3: economy (wallet, items, journal, bonus counter), meta (stars, pieces, postcards, unlocks), settings, monetization (entitlements, processed transaction ids, consent state), per-language progress; migration v2→v3 + golden; never-decrease test for earned items; monetization also holds ad-policy state (`levels_since_interstitial`, `last_interstitial_time`, `last_purchase_slot`) and the rewarded shop-coins cap (`date`, `count`); meta also holds `coach_marks_seen` and the onboarding step [HS] | contract | services.save | T-0203 | H | SOL | xhigh | none | high | FR-SAVE-04, FR-SAVE-08, FR-PROG-05, FR-META-08, FR-BONUS-03, FR-ECON-03, FR-ADS-02, FR-ONB-03 |
| T-0230 | core/economy contract + tests: wallet (int coins, items), `can_afford`, apply grant/spend, reward tables from config, never negative | contract | core.economy | T-0203 | ECO | SOL | high | none | high | FR-ECON-01, FR-ECON-02, FR-ECON-04, GAME_DESIGN.md#economy-intents |
| T-0231 | core/economy implementation + bonus chest rule (`bonus.chest.words_required`, carry-over) | feat | core.economy | T-0230 | ECO | CHEAP | med | none | high | FR-ECON-02, FR-BONUS-02 |
| T-0232 | Economy service contract: `grant(source, items)`, `spend(sink, items) -> bool`, bounded journal, `Events.economy_changed` | contract | services.economy | T-0231, T-0229 | ECO | SOL | high | none | high | FR-ECON-02, FR-ECON-03 |
| T-0233 | Economy service implementation: persistence via Save, journal bound `economy.journal.max_entries` | feat | services.economy | T-0232 | ECO | CHEAP | med | none | high | FR-ECON-03 |
| T-0234 | Config entries `economy.*`, `bonus.*`, `hint.*`, `ads.*`, `consent.*`, `meta.*`, `onboarding.*`, `iap.*` and final `unlocks.*` values, with defaults from PRODUCT.md and the approved intents | feat | data.config | T-0230 | DATA | SOL | med | none | high | FR-ECON-04, FR-ECON-05, FR-HINT-03, FR-HINT-07, FR-ADS-02, FR-META-02, FR-ONB-04, FR-PROG-04, PRODUCT.md#first-10-minutes-timeline |
| T-0235 | `tools/econ_sim.py`: archetypes (saver, hinter, ad watcher) × 300 levels from economy config | feat | tools | T-0234 | TOOL | CHEAP | med | none | med | FR-ECON-06, dp03 §6.2 |
| T-0236 | CI job: run `econ_sim` and attach the report when `data/config/economy*.json` changes (Sol's feedback loop) [HS] | infra | ci | T-0235 | H | SOL | low | none | high | FR-ECON-06, decision 0006 |
| T-0237 | Tune economy config from the sim report against the intents; Chris approves | feat | data.config | T-0236 | DATA | SOL+HUMAN | high | none | high | FR-ECON-06, FR-ECON-07 |

### E16 Meta: progress, home, journey
Goal: stars, postcards, one region with 3–4 locations, Home and Journey. Exit: a player can see and
fill postcards across one region.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0238 | Manifest schema v1.1 + Content API: slot → location → region, location metadata (postcard id, pieces), regions list; per-slot `landmark: bool` in the manifest schema (unused until P3) [HS] | contract | services.content | T-0203 | H | SOL | high | none | high | FR-PROG-03, CONTENT.md#manifest |
| T-0239 | core/progress contract + tests: stars per level, postcard piece thresholds, location complete, region unlock, unlock evaluation from `unlocks.*` | contract | core.progress | T-0203 | META | SOL | high | none | high | FR-META-01..03, FR-PROG-04, GAME_DESIGN.md#postcards, GAME_DESIGN.md#unlocks |
| T-0240 | core/progress implementation | feat | core.progress | T-0239 | META | CHEAP | med | none | med | FR-META-01..03 |
| T-0241 | Progress service P2 contract: stars, pieces, location/region state, persisted unlocks, per-language progress | contract | services.progress | T-0240, T-0229, T-0238 | META | SOL | high | none | high | FR-PROG-04, FR-PROG-05 |
| T-0242 | Progress service P2 implementation + Events (stars_earned, postcard_piece_revealed, location_complete, feature_unlocked) | feat | services.progress | T-0241, T-0234 | META | CHEAP | med | none | med | FR-META-01..03, FR-PROG-04 |
| T-0243 | Nav P2: boot routing (slot < `unlocks.journey_slot` → Level, else Home), transitions, Android back rules (no quit dialog), pending toasts | feat | services.nav | T-0242, T-0216, T-0208 | META | CHEAP | med | med | med | FR-ONB-01, FR-PLAT-04, DESIGN.md#flow-returning-user, DESIGN.md#screen-map |
| T-0244 | Home screen | feat | features.home | T-0243, T-0220 | META | CHEAP | med | high | low | FR-META-05, DESIGN.md#home, DESIGN.md#flow-returning-user |
| T-0245 | Journey screen (1 region; completed levels shown, not replayable) | feat | features.journey | T-0244 | META | CHEAP | med | high | low | FR-META-04, FR-PROG-06, DESIGN.md#journey-1-region |
| T-0246 | Location postcard screen (revealing, complete stamp) | feat | features.journey | T-0245 | META | CHEAP | med | high | low | FR-META-02, FR-META-03, DESIGN.md#location-postcard |

### E17 Analytics, crash and remote config
Goal: measurable slice, tunable without a build. Exit: events reach the dashboard from Android and iOS;
remote overrides and buckets work; crash reports arrive with versions. Funnel QA is T-0258 in E25,
after the P2b listener.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0247 | Analytics registry P2: every core event with typed params; provider-reserved names avoided | contract | data.analytics | T-0203, T-0033 | DATA | SOL | high | none | high | FR-ANL-01, PRODUCT.md#core-events-seed-of-the-registry |
| T-0248 | Opus review of irreversible names: analytics events, IAP product IDs, config key namespaces | docs | docs | T-0247 | DOC | OPUS | high | none | med | dp05 §2, dp11 §3, PRODUCT.md#iap-catalog |
| T-0249 | Analytics / crash SDK plugins per the providers decision (no-op if HTTP-based); provider config via secrets [HS] | infra | infra | T-0248, T-0208 | H | CHEAP+HUMAN | med | none | high | FR-ANL-05, AGENTS.md S11 |
| T-0250 | Analytics service: bounded offline queue, common params (install_id, versions, language, buckets), consent gating via `Events.consent_changed(analytics_allowed: bool)` declared in this task (queue until the first emission, then send or drop) | feat | services.analytics | T-0247 | DATA | SOL | high | none | high | FR-ANL-02, FR-ANL-03, FR-CONSENT-02, NFR-10 |
| T-0251 | Analytics listener P2a: map Events signals to registry events (lifecycle, level, tools, economy, meta, save_corrupted / save_migrated, invalid_word_submitted with letters) | feat | services.analytics | T-0250, T-0233, T-0242 | DATA | CHEAP | med | none | med | FR-ANL-04, FR-SAVE-03 |
| T-0252 | Platform analytics adapter (real) on Android + iOS; events visible in the dashboard | feat | platform.analytics | T-0249, T-0250, T-0226 | DATA | CHEAP+HUMAN | med | none | med | FR-ANL-02, FR-ANL-03 |
| T-0253 | Crash adapter (real) with app + content version tags; test crash visible | feat | platform.crash | T-0252 | DATA | CHEAP+HUMAN | med | none | med | FR-ANL-05, NFR-07 |
| T-0254 | Remote config contract: static JSON fetch (timeout, never blocks start), validation (unknown ignored + logged, bad type/range rejected), cache of last valid, `hash(install_id + experiment_id) % 100` buckets, experiment schema | contract | services.config | T-0203, T-0037 | DATA | SOL | high | none | high | FR-CFG-02..04 |
| T-0255 | Remote config implementation: HTTP fetch + cache, `experiment_assigned`, buckets as analytics user properties | feat | services.config | T-0254, T-0250 | DATA | CHEAP | med | none | high | FR-CFG-02..04 |
| T-0256 | Config validator test: `consent.ump_after_slot <= consent.att_after_slot < min(unlocks.hint_slot, unlocks.double_reward_slot, ads.interstitial.first_slot)`; unlock slots monotonic as in PRODUCT.md | test | services.config | T-0255, T-0234 | DATA | CHEAP | low | none | low | DESIGN.md#feature-unlock-gating, PRODUCT.md#first-10-minutes-timeline |
| T-0257 | Remote config hosting: `remote/config.json` in repo, schema check in CI, publish workflow to the CDN (GitHub Pages or R2) [HS] | infra | ci | T-0254 | H | SOL+HUMAN | med | none | high | FR-CFG-02, dp02 §4 |

### E18 Consent and ads
Goal: UMP before ads, ATT at a controlled moment, rewarded and interstitial per policy. Exit: device
test T-0267 passes on Android and iPhone.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0259 | AdMob account, app registration, ad units, UMP privacy message (EEA/UK) configuration; developer website domain with `app-ads.txt` (same domain as the privacy policy, T-0313) | docs | store | T-0012, T-0143 | STORE | HUMAN | — | none | high | FR-CONSENT-01, PRODUCT.md#compliance-and-store-requirements |
| T-0260 | core/ad_policy: `should_show_interstitial(state, config, now)` + per-session prompt budget; one test per condition | contract | core.ads | T-0203 | PLAT | SOL | high | none | high | FR-ADS-01..03, FR-ADS-07, FR-ONB-04, GAME_DESIGN.md#ad-policy |
| T-0261 | Monetization service contract: consent orchestration (UMP after `consent.ump_after_slot` before ads init, ATT after `consent.att_after_slot`, retry), emits `Events.consent_changed` per the T-0250 contract; single entry point `Monetization.before_next_level(slot)` (consent step, then interstitial decision) with Fake-based order tests; rewarded (grant only on reward earned; unavailable states), interstitial via ad_policy, Remove Forced Ads entitlement, audio pause, IAP flow API | contract | services.monetization | T-0260, T-0229, T-0233, T-0250 | PLAT | SOL | xhigh | none | high | FR-ADS-04..06, FR-ADS-08, FR-CONSENT-01, FR-IAP-03, FR-IAP-04 |
| T-0262 | Fake ads + fake consent with debug outcomes (fill, no fill, closed early, form required / not, error) | feat | platform.ads | T-0261 | PLAT | CHEAP | low | none | high | FR-PLAT-01, FR-DEBUG-03 |
| T-0263 | Monetization: consent + ads implementation against Fakes (UMP and ATT steps per DESIGN.md#flow-consent-and-att, rewarded flows, interstitial only between campaign levels, Remove Forced Ads) | feat | services.monetization | T-0262, T-0234 | PLAT | CHEAP | high | none | high | FR-ADS-03..07, FR-CONSENT-01, FR-CONSENT-04, DESIGN.md#flow-consent-and-att, DESIGN.md#flow-rewarded, DESIGN.md#flow-interstitial-placement |
| T-0264 | AdMob + UMP plugin; Android manifest and iOS plist entries (app ID, AD_ID, SKAdNetwork, ATT usage string) [HS] | infra | infra | T-0259, T-0208, T-0226 | H | CHEAP+HUMAN | high | none | high | FR-ADS-06, FR-CONSENT-04, AGENTS.md S11 |
| T-0265 | Consent adapter (UMP) + ATT (iOS) + privacy options form; Chris runs the iOS build on the iPhone each round | feat | platform.consent | T-0264, T-0263 | PLAT | CHEAP+HUMAN | high | low | high | FR-CONSENT-01, FR-CONSENT-03, FR-CONSENT-04 |
| T-0266 | Ads adapter (AdMob rewarded + interstitial, test units); OPUS-with-runtime after two failed rounds | feat | platform.ads | T-0265 | PLAT | CHEAP+HUMAN | high | low | high | FR-ADS-04, FR-ADS-05, FR-ADS-08 |
| T-0267 | Device test ads + consent, Android and iPhone: UMP via debug geography, ATT allow/deny, reward only after full watch, offline, background during ad, audio pause | test | platform.ads | T-0266 | PLAT | HUMAN | — | low | high | FR-ADS-04, FR-ADS-05, FR-ADS-08, FR-CONSENT-04, dp08 §2 |

### E19 IAP and shop
Goal: Remove Forced Ads, one coin pack, restore; idempotent purchase flow. Exit: sandbox device test
T-0275 passes in both stores.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0268 | Chris approves P2 catalog and price points (Q6); creates `nc.remove_forced_ads.v1` and `c.coins_s.v1` in App Store Connect (Play products follow in T-0272) | docs | store | T-0248, T-0259 | STORE | HUMAN | — | none | high | PRODUCT.md#iap-catalog, FR-IAP-01 |
| T-0269 | Play Billing + StoreKit 2 plugins per S1 [HS] | infra | infra | T-0264 | H | CHEAP | med | none | high | FR-IAP-08 |
| T-0270 | Fake IAP store with debug outcomes (success, cancel, pending / deferred, crash before finish, duplicate transaction) | feat | platform.iap | T-0261 | PLAT | CHEAP | med | none | high | FR-IAP-03, FR-DEBUG-03 |
| T-0271 | IAP flow: idempotent by `transaction_id`, grant → `Save.flush` → finish, unfinished at start, restore non-consumables, pending; tests incl. crash between steps; Remove Forced Ads is never revoked locally | feat | services.monetization | T-0270, T-0263 | PLAT | SOL | xhigh | none | high | FR-IAP-02..07, FR-SAVE-08, NFR-13, FR-IAP-11 |
| T-0272 | Play Billing adapter + local signature verification; Chris uploads an internal-track AAB with the billing plugin, then creates both products in Play Console | feat | platform.iap | T-0269, T-0271, T-0268, T-0315 | PLAT | CHEAP+HUMAN | high | none | high | FR-IAP-08 |
| T-0273 | StoreKit 2 adapter + signed transaction verification; OPUS-with-runtime after two failed rounds; Chris runs the iOS build each round | feat | platform.iap | T-0272 | PLAT | CHEAP+HUMAN | xhigh | none | high | FR-IAP-08 |
| T-0274 | Shop sheet: Remove Forced Ads, coin pack, rewarded free coins with daily cap, Restore (iOS), every purchase state | feat | features.shop | T-0271, T-0217 | ECO | CHEAP | med | high | high | FR-IAP-01, FR-IAP-06, DESIGN.md#shop-sheet, DESIGN.md#flow-purchase |
| T-0275 | Device test IAP sandbox, both stores: purchase, cancel, restore, kill during purchase, pending / Ask to Buy, Remove Forced Ads stops interstitials | test | platform.iap | T-0273, T-0274 | PLAT | HUMAN | — | low | high | FR-IAP-02..07, dp08 §2 |

### E20 Level screen integration
Goal: the final Level screen with paid tools, bonus chest, rewards and the complete flow. Exit: level
loop matches DESIGN flows and Chris accepts the feel on device.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0276 | Level screen P2 composition (TopBar home / coins / settings, BonusMeter, HintButtons, gating by unlocks); one control per wheel corner and a button / tile-hit overlap assertion in COMPACT / REGULAR / TABLET | feat | level.flow | T-0225, T-0242, T-0233, T-0219 | LVL | CHEAP | med | high | med | DESIGN.md#level-p2-final, FR-PROG-04 |
| T-0277 | `HintLogic.reveal_word`: deterministic word choice | feat | core.board | T-0102, T-0143 | LVL | CHEAP | med | none | med | FR-HINT-04, GAME_DESIGN.md#hints |
| T-0278 | Hint / Reveal paid flow: item else coins, charged exactly once, double-tap safe; unaffordable → Hint options Sheet (rewarded or shop) | feat | level.hud | T-0276, T-0277, T-0263, T-0274 | LVL | CHEAP | high | high | high | FR-HINT-03..05, DESIGN.md#flow-stuck-player |
| T-0279 | Stuck-player offer: idle seconds / invalid streak → HintButton pulse + inline label, once per level | feat | level.hud | T-0278 | LVL | CHEAP | low | med | low | FR-HINT-07 |
| T-0280 | BonusMeter in Level: persistent count, chest opens on Level complete (never mid-level), reward | feat | level.hud | T-0279, T-0231 | LVL | CHEAP | med | med | med | FR-BONUS-02, FR-BONUS-03 |
| T-0281 | Level complete P2: stars, coin count-up, postcard progress, chest RewardBurst, Continue calls `Monetization.before_next_level` then loads the next level (no ordering logic in the scene), x2 rewarded | feat | level.flow | T-0280, T-0242, T-0263, T-0220 | LVL | CHEAP | med | high | high | FR-ECON-05, FR-META-01, DESIGN.md#level-complete, DESIGN.md#flow-level-complete |
| T-0282 | Game-feel tuning on device: Chris plays, CHEAP edits Motion/Ease values in `tokens.gd` | feat | ui.tokens | T-0281, T-0227, T-0228 | UI | CHEAP+HUMAN | med | high | low | DESIGN.md#level-motion, NFR-01 |
| T-0283 | Performance pass: 60 fps Level on low-end Android, no idle redraw, level load ≤ 100 ms timer in debug, cold start measured | feat | level.flow | T-0282 | LVL | CHEAP+HUMAN | high | low | med | NFR-02..04, NFR-08 |

### E21 Onboarding, settings, localization, debug
Goal: first 15 levels, settings, PL + EN UI, accessibility, P2 debug tools. Exit: onboarding playtest
T-0323 shows no blocker; every setting applies immediately.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0284 | Settings data contract: `settings` section accessor (owner per ARCHITECTURE.md, no new autoload), apply hooks (theme variant, `Tokens.reduced_motion`, volumes, haptics), OS reduced-motion default | contract | features.settings | T-0229, T-0207 | SCR | SOL | med | low | high | FR-SET-04, DESIGN.md#accessibility |
| T-0285 | Settings screen: sound, display, language, purchases, privacy, about | feat | features.settings | T-0284, T-0218 | SCR | CHEAP | med | high | med | FR-SET-01, FR-SET-03, DESIGN.md#settings |
| T-0286 | Settings apply: text size + high contrast theme switch, reduced motion, haptics off, volumes; immediate and persisted | feat | features.settings | T-0285, T-0228 | SCR | CHEAP | med | high | low | FR-SET-01, FR-SET-04, FR-A11Y-02, FR-A11Y-03, DESIGN.md#settings, DESIGN.md#accessibility |
| T-0287 | Language selector (languages with shipped content; EN UI debug-only before EN content) + device default | feat | features.settings | T-0286, T-0242 | SCR | CHEAP | med | med | med | FR-SET-02, FR-LOC-01, FR-PROG-05, DESIGN.md#flow-first-launch |
| T-0288 | Settings rows: Restore Purchases, Privacy options, privacy policy link, support (install_id), licences screen | feat | features.settings | T-0287, T-0271, T-0265 | SCR | CHEAP | med | med | med | FR-SET-03, FR-IAP-06, FR-CONSENT-03, DESIGN.md#settings |
| T-0289 | UI strings PL + EN for all P2 screens (no plural-dependent sentences; Chris approves PL); location names and facts | feat | locale | T-0203, T-0246 | SCR | SOL+HUMAN | med | med | low | FR-LOC-03, FR-LOC-04, DESIGN.md#copy-and-tone |
| T-0290 | Onboarding contract: `OnboardingState` (step tracking, once-per-feature coach-mark flags persisted in the save meta section), `onboarding_step` event, CoachMark API (target highlighted state + inline caption, dismissed by any tap without blocking input); no scene | contract | features.onboarding | T-0203, T-0242 | SCR | SOL | med | low | high | FR-ONB-03, FR-ONB-05, DESIGN.md#feature-unlock-gating |
| T-0291 | Level 1 tutorial: TutorialHand over the wheel + caption until the first word; only board, preview and wheel on screen | feat | features.onboarding | T-0290, T-0276, T-0326 | SCR | CHEAP | med | high | low | FR-ONB-02, DESIGN.md#flow-first-launch, DESIGN.md#tutorialhand-addition, DESIGN.md#level-p2-final |
| T-0292 | Coach marks per DESIGN.md#feature-unlock-gating (highlighted state + inline caption, any tap dismisses, no overlay) for shuffle, bonus meter, hint and reveal | feat | features.onboarding | T-0291 | SCR | CHEAP | med | high | low | FR-ONB-03, DESIGN.md#feature-unlock-gating, `docs/design/` onboarding mockup (T-0205) |
| T-0293 | Accessibility pass: a11y labels on IconButton / NavTab / Toggle / Slider / HintButton / CurrencyPill, touch targets, Level screen-reader summary | feat | ui.components | T-0288, T-0292, T-0246 | UI | CHEAP | med | med | low | FR-A11Y-01, FR-A11Y-04, NFR-11 |
| T-0294 | Debug P2a: grant / remove coins and items, toggle Remove Forced Ads, force fake ad / IAP outcomes | feat | features.debug | T-0271, T-0233 | SCR | CHEAP | low | low | low | FR-DEBUG-03 |
| T-0329 | Debug P2b: clock offset, active config + buckets, live analytics event log | feat | features.debug | T-0294, T-0255, T-0251 | SCR | CHEAP | low | low | low | FR-DEBUG-04 |
| T-0295 | Offline and error states: content load failure StatePanel, backup-restored Toast, save-lost panel | feat | services.nav | T-0243, T-0217 | META | CHEAP | med | med | med | DESIGN.md#flow-offline-and-errors, FR-SAVE-03, NFR-06 |
| T-0328 | Analytics listener P2b: consent_result, att_result, ad_offer_shown / ad_shown / ad_reward_earned / ad_failed, shop_opened, iap_*, settings_changed, remote_config_applied, experiment_assigned, hint_stuck_offer_shown, onboarding_step, feature_unlocked | feat | services.analytics | T-0251, T-0255, T-0265, T-0271, T-0274, T-0279, T-0286, T-0292 | DATA | CHEAP | med | none | med | FR-ANL-01, FR-ONB-05, PRODUCT.md#core-events-seed-of-the-registry, PRODUCT.md#funnels |

### E22 PL content production
Goal: 200 production PL levels with tiers, AI classification and Chris's review. Exit: levels 1–15
hand-made, first ~100 played by Chris, region 1 mapped.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0296 | Classify: batch AI classification (before this first production content run Chris switches the repo to private, with GitHub Pro if branch protection must stay), committed cache keyed (word, prompt version, model), two passes, disagreement CSV; Chris adds the API key as a CI / agent secret and sets a spend cap from the T-0031 cost-per-1k figure | feat | pipeline.classify | T-0127, T-0031, T-0143 | PIPE | CHEAP+HUMAN | med | none | med | dp09 §3, FR-CONT-05 |
| T-0297 | Tiers v1: rules + classification suggestion + overrides; tier-distribution diff alarm | feat | pipeline.tiers | T-0296 | PIPE | CHEAP | high | none | high | FR-CONT-05, decision 0004 |
| T-0298 | Scoring: difficulty features × weights (`scoring.yaml`) | feat | pipeline.scoring | T-0297 | PIPE | CHEAP | med | none | med | dp03 §6.1, dp09 §2 |
| T-0299 | Dedupe + diversity: multiset, Jaccard, seed-word spacing K | feat | pipeline.dedupe | T-0298 | PIPE | CHEAP | med | none | med | dp09 §2, PRODUCT.md#content-requirements |
| T-0300 | Sequence: `curve.yaml` (trend, saw-tooth, breather), slot assignment, onboarding constraints, location mapping | feat | pipeline.sequence | T-0299, T-0238 | PIPE | CHEAP | high | none | med | CONTENT.md#curve, dp03 §6.1 |
| T-0301 | Validate v1: all hard rules incl. campaign duplicates, `CELL_MIN` on COMPACT, difficulty window; released-slot lock file, bonus-only changes allowed; `CELL_MIN`, `GRID_MIN_RATIO` and the COMPACT geometry are read from tokens v1, not copied | contract | pipeline.validate | T-0300, T-0206 | PIPE | SOL | xhigh | none | high | FR-CONT-03, FR-CONT-04, dp09 §4, DESIGN.md#level-screen-geometry, CONTENT.md#slot-policy |
| T-0302 | Export v1: manifest v1.1 (regions, locations), lock-file update command | contract | pipeline.export | T-0301, T-0238 | PIPE | SOL | high | none | high | FR-PROG-03, FR-CONT-03 |
| T-0303 | QA report: stats, histograms, weirdest level words, AI "odd for this slot" flags | feat | pipeline.qa | T-0302 | PIPE | CHEAP | med | none | low | dp09 §2 |
| T-0304 | Chris reviews the disagreement queue and flagged candidates → `overrides/pl.csv` (batch 1) | content | content.pl | T-0297 | CPL | HUMAN | — | none | med | dp09 §3, dp11 §1 |
| T-0305 | Chris hand-makes onboarding levels 1–15 (YAML) per GAME_DESIGN.md#onboarding | content | content.pl | T-0304, T-0203 | CPL | HUMAN | — | high | med | FR-ONB-02 |
| T-0306 | Content build P2: 200 PL levels (slots 1–200; 1–15 hand-made), region 1 with 3–4 locations covering every slot | content | content.pl | T-0303, T-0305 | CPL | CHEAP | med | none | high | PRODUCT.md#content-requirements, FR-PROG-03 |
| T-0307 | Chris plays 100 % of the first ~100 levels in debug; flags → overrides; rebuild | content | content.pl | T-0306, T-0294 | CPL | HUMAN | — | none | med | PRODUCT.md#content-requirements |

### E23 Art and audio assets
Goal: region 1 art, icon, final sounds. Exit: assets merged with licence records.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0308 | Region 1 postcards (3–4 illustrations) generated per the style document; Chris selects | feat | assets.art | T-0205 | ART | HUMAN | — | high | med | dp10 §7, dp11 §1 |
| T-0309 | Art processing: WebP sizes per layout class, postcard piece masks, location backgrounds | feat | assets.art | T-0308 | ART | CHEAP | low | med | low | DESIGN.md#locationpostcard |
| T-0310 | App icon + splash per the style document | feat | assets.art | T-0309 | ART | CHEAP+HUMAN | low | high | low | DESIGN.md#flow-first-launch |
| T-0311 | Final SFX set + 1–2 music loops (licensed or CC0), OGG, final `cues.json`; Chris selects | feat | assets.audio | T-0228 | ART | CHEAP+HUMAN | low | med | low | FR-AUDIO-03, DESIGN.md#motion-haptics-and-sound |

### E24 Store, legal and builds
Goal: legal basics, iOS distribution, store listing, closed testing and TestFlight running. Exit: closed test clock started;
TestFlight build available; OS-backup restore verified.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0312 | Trademark search and store name (Q1) | docs | store | T-0143 | STORE | HUMAN | — | none | med | PRODUCT.md#compliance-and-store-requirements, dp11 §1 |
| T-0313 | Privacy policy v1 PL + EN (public URL); data inventory from the registry and SDKs | docs | store | T-0247 | STORE | SOL+HUMAN | high | none | high | FR-LOC-05, NFR-10 |
| T-0314 | Play Data safety, Apple privacy labels + SDK privacy manifests, target audience (18 and over), IARC and App Store age rating | docs | store | T-0313 | STORE | HUMAN | — | none | high | PRODUCT.md#compliance-and-store-requirements |
| T-0316 | iOS distribution signing + TestFlight provisioning; save in a backed-up directory on iOS [HS] | infra | ci | T-0226 | H | SOL+HUMAN | high | none | high | FR-PLAT-02, FR-SAVE-06 |
| T-0317 | App size check in CI (warn at 90 % of budget) [HS] | infra | ci | T-0226, T-0315 | H | SOL | low | none | high | NFR-05 |
| T-0320 | Store listing drafts PL + EN (name, short + full description, icon, screenshots from the current build; final gameplay screenshots in T-0450) | docs | store | T-0312, T-0310 | STORE | SOL+HUMAN | low | med | low | FR-LOC-05 |
| T-0318 | Start Google Play closed testing (recruit ≥12 testers for 14 days; verify the current rule) with the first stable P2 build; listing from T-0320 in place | docs | store | T-0312, T-0314, T-0315, T-0320 | STORE | HUMAN | — | none | high | PRODUCT.md#compliance-and-store-requirements, dp11 §1 |
| T-0319 | TestFlight internal testing | docs | store | T-0316, T-0314 | STORE | HUMAN | — | none | med | FR-PLAT-02 |
| T-0321 | Device test: save restored on a new device through OS backup (Android + iOS) | test | services.save | T-0315, T-0316, T-0229 | H | HUMAN | — | none | high | FR-SAVE-06, PRODUCT.md#hypotheses-to-validate |

### E25 Slice QA and audit
Goal: prove the slice. Exit: the Phase 2 exit criteria.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0258 | Funnels F1–F3 defined in the provider dashboard; event QA on device for the P2a and P2b listeners | test | data.analytics | T-0253, T-0328 | DATA | HUMAN | — | none | low | PRODUCT.md#funnels |
| T-0322 | Device checklist on 3 reference devices (`TESTING.md`): offline / airplane mode, interruptions, clean-install first 10 minutes, battery and thermal, cold start | test | docs | T-0283, T-0275, T-0267, T-0307, T-0293, T-0295, T-0258, T-0221, T-0256, T-0257, T-0289, T-0310, T-0311, T-0329 | DOC | HUMAN | — | high | high | NFR-04, NFR-06, NFR-08, NFR-11, dp08 §2 |
| T-0323 | Onboarding playtest: 5 new players through level 15; funnel observed | test | docs | T-0322 | DOC | HUMAN | — | high | med | FR-ONB-02, FR-ONB-04 |
| T-0324 | Opus slice audit (UX, economy, architecture) on context pack + screenshots + sim report | docs | docs | T-0322, T-0237 | DOC | OPUS | high | high | med | dp11 §4, dp05 §2 |
| T-0325 | PHASE 2 EXIT: sandbox IAP + ads pass, checklist pass on 3 devices, no critical audit findings, Chris: "I would download it" | docs | docs | T-0323, T-0324, T-0318, T-0319, T-0321, T-0317 | DOC | HUMAN | — | high | high | dp11 §4 |

## Phase 3 — Production

Planned rows; Sol re-plans per wave. Soft launch after daily + streak + ~500 PL levels; EN content after
PL works; DE after EN (decision 0005).

### E26 Phase 3 product decisions
Goal: rules for daily, calendar, streak, landmarks, starter pack. Exit: Q3, Q4, Q5 decided.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0400 | GAME_DESIGN P3: daily, monthly calendar (Q3 catch-up), streak (Q4), freeze, repair, landmarks, starter pack (Q5), more coin packs | docs | docs | T-0325 | DOC | SOL | high | low | med | GAME_DESIGN.md#daily, GAME_DESIGN.md#monthly-calendar, GAME_DESIGN.md#streak, GAME_DESIGN.md#landmarks, PRODUCT.md#open-questions |
| T-0401 | Opus second opinion: calendar catch-up, streak repair, starter pack placement, P3 coin packs | docs | docs | T-0400 | DOC | OPUS | high | low | med | dp05 §2 |
| T-0402 | Chris decides Q3, Q4, Q5; Sol applies to GAME_DESIGN and updates the DESIGN.md P3 screen specs (Collection, multi-region Journey, landmark, end of content) to the decisions | docs | docs | T-0401 | DOC | SOL+HUMAN | med | low | med | PRODUCT.md#open-questions, DESIGN.md#screen-specs |

### E27 Pipeline production and review loop
Goal: pipeline at full strength: review mode, landmarks, daily pool, scale. Exit: 1000+ levels build
deterministically in CI time; flags from the game flow back into QA.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0403 | Content review mode in game: play any campaign or daily level by id, flag to a local report, export the file | feat | features.debug | T-0325 | SCR | CHEAP | low | low | low | FR-DEBUG-05 |
| T-0404 | Pipeline: import review flags → QA queue; sampling plan (100 % first 100 + landmarks, ~5 % rest + flagged) | feat | pipeline.qa | T-0403, T-0303 | PIPE | CHEAP | med | none | low | dp09 §2, PRODUCT.md#content-requirements |
| T-0405 | Landmarks in the pipeline: hand-made landmark YAML (up to 8 letters), landmark slots + breather in sequencing | feat | pipeline.sequence | T-0402, T-0302 | PIPE | CHEAP | med | none | med | FR-META-07, CONTENT.md#curve |
| T-0406 | Daily pack + calendar schema and `Content.daily_for(date)` [HS] | contract | services.content | T-0402, T-0238 | H | SOL | high | none | high | FR-CONT-08, FR-DAILY-01, FR-DAILY-05 |
| T-0407 | Daily pool generation (separate pool, no duplicates vs campaign) + calendar export | contract | pipeline.export | T-0406, T-0405 | PIPE | SOL | high | none | high | FR-CONT-08 |
| T-0408 | Pipeline scale: 1000+ levels built deterministically within the CI budget (caching, profiling) | feat | pipeline.grid | T-0407 | PIPE | CHEAP | med | none | med | NFR-14, FR-CONT-06 |

### E28 Release pipeline
Goal: releases from CI, not from a laptop. Exit: tagged commit → Play internal track + TestFlight.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0409 | Signed AAB to Play internal track from CI on tag (fastlane or equivalent); version name and code injected from `game/version.json` at export [HS] | infra | ci | T-0325, T-0315 | H | SOL+HUMAN | high | none | high | FR-PLAT-02, dp11 §4 |
| T-0410 | iOS archive + TestFlight upload from CI (macOS) on tag; version name and code injected from `game/version.json` at export [HS] | infra | ci | T-0409, T-0316 | H | SOL+HUMAN | high | none | high | FR-PLAT-02 |
| T-0411 | `tools/release.py`: bump `game/version.json` (never project.godot or export_presets.cfg), content version, changelog, release notes PL / EN, release checklist output | feat | tools | T-0325 | TOOL | SOL | low | none | low | TESTING.md |
| T-0412 | Non-blocking CI: desktop perf proxy (level load, frame time) + gallery screenshot diff against references (builds on T-0327) [HS] | infra | ci | T-0410 | H | CHEAP | med | none | med | NFR-02, NFR-03, dp08 §2 |

### E29 Daily puzzle and monthly calendar
Goal: one shared daily per local date, calendar month, month postcard. Exit: daily works offline across
day boundaries, time zones and DST.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0413 | Save schema v4: daily + streak sections + migration v3→v4 + golden; plus `monetization.starter_pack_purchased` and `meta.review_prompted` [HS] | contract | services.save | T-0402 | H | SOL | xhigh | none | high | FR-SAVE-04, FR-STREAK-05 |
| T-0414 | core/daily: local date → puzzle id, calendar month state, TZ / DST / rollback behaviour per decision 0003; contract + implementation + tests | contract | core.daily | T-0402 | DAILY | SOL | xhigh | none | high | FR-DAILY-01, FR-DAILY-06, decision 0003 |
| T-0415 | Daily service contract: today, start, complete, calendar, month postcard, reward | contract | services.daily | T-0414, T-0413, T-0406 | DAILY | SOL | high | none | high | FR-DAILY-01..04 |
| T-0421 | Daily and streak analytics events in the registry | contract | data.analytics | T-0402 | DATA | SOL | med | none | high | PRODUCT.md#core-events-seed-of-the-registry |
| T-0416 | Daily service implementation (`economy.reward.daily`, calendar mark, month postcard grant) + Events | feat | services.daily | T-0415, T-0421 | DAILY | CHEAP | med | none | high | FR-DAILY-03..05 |
| T-0417 | CalendarDay + StreakFlame components + gallery entries | feat | ui.components | T-0402 | UI | CHEAP | low | med | low | DESIGN.md#calendarday, DESIGN.md#streakflame |
| T-0418 | Daily calendar screen | feat | features.daily | T-0416, T-0417 | DAILY | CHEAP | med | high | med | DESIGN.md#daily-calendar-p3 |
| T-0419 | Level daily mode: daily puzzle in the Level scene, no interstitials, back to Daily | feat | level.flow | T-0416 | LVL | CHEAP | med | med | med | FR-ADS-03, FR-DAILY-01 |
| T-0420 | Home: Daily NavTab unlock at `unlocks.daily_slot` + NEW badge | feat | features.home | T-0418 | META | CHEAP | low | med | low | FR-DAILY-02 |
| T-0422 | Daily pool content: ≥90 days PL + Chris review; rolling ≥60-day buffer rule in CONTENT.md | content | content.pl | T-0407 | CPL | CHEAP+HUMAN | low | none | med | FR-CONT-08, PRODUCT.md#content-requirements |

### E30 Streak and freeze
Goal: forgiving streak. Exit: streak survives day changes, freezes, repair and backup restore.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0423 | core/streak: consecutive local days, automatic freeze use, weekly grant capped, repair window; DST / TZ / break tests | contract | core.streak | T-0402 | DAILY | SOL | xhigh | none | high | FR-STREAK-01..04, FR-DAILY-06 |
| T-0424 | Streak in the Daily service: freezes, weekly grant, Events | feat | services.daily | T-0423, T-0416 | DAILY | CHEAP | med | none | high | FR-STREAK-01..03, FR-STREAK-05 |
| T-0425 | Streak repair via rewarded ad within the window | feat | services.monetization | T-0424 | PLAT | CHEAP | med | low | high | FR-STREAK-04, FR-ADS-04 |
| T-0426 | StreakFlame in Daily and Home; freeze-used toast; at-risk state; streak repair Card (rewarded) within the window | feat | features.daily | T-0424, T-0418 | DAILY | CHEAP | low | high | low | DESIGN.md#streakflame, DESIGN.md#daily-calendar-p3 |
| T-0427 | Device test daily + streak: day change, TZ change, DST, clock rollback, freeze, repair, backup restore | test | core.daily | T-0426, T-0425 | DAILY | HUMAN | — | low | high | FR-DAILY-06, FR-STREAK-05 |
| T-0475 | Analytics listener P3: daily_start, daily_complete, calendar_month_complete, streak_updated / streak_freeze_used / streak_broken / streak_repaired | feat | services.analytics | T-0421, T-0424, T-0425 | DATA | CHEAP | low | none | med | PRODUCT.md#core-events-seed-of-the-registry, PRODUCT.md#funnels |

### E31 Regions, landmarks and collection
Goal: long-term meta beyond region 1. Exit: regions 2–3, landmarks, collection screen, end-of-content
state live.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0428 | Art batch script: sizes, WebP, piece masks from source images | feat | tools | T-0309, T-0325 | TOOL | CHEAP | low | none | low | dp10 §7 |
| T-0429 | Regions 2–3: location list, names, facts PL/EN | feat | locale | T-0402 | SCR | SOL+HUMAN | low | low | low | FR-LOC-03 |
| T-0430 | Region 2 art batch (Chris generates and selects) | feat | assets.art | T-0429, T-0428 | ART | HUMAN | — | high | low | dp11 §1 |
| T-0431 | Region 3 art batch | feat | assets.art | T-0430 | ART | HUMAN | — | high | low | dp11 §1 |
| T-0432 | Journey multi-region: region list, region complete, next-region teaser | feat | features.journey | T-0402 | META | CHEAP | med | high | med | FR-META-03, FR-META-04, DESIGN.md#journey-multi-region-p3 |
| T-0433 | Landmark presentation in Level (8-letter wheel check, landmark badge, next-landmark caption on the previous Level complete) | feat | level.hud | T-0405 | LVL | CHEAP | med | high | low | FR-META-07, FR-WHEEL-09, DESIGN.md#level-landmark-p3 |
| T-0434 | Chris hand-makes landmark levels for regions 1–3 | content | content.pl | T-0405 | CPL | HUMAN | — | none | med | FR-META-07 |
| T-0435 | Postcard collection screen + NavTab (campaign and monthly postcards) | feat | features.collection | T-0416, T-0432 | META | CHEAP | med | high | low | FR-META-06, DESIGN.md#collection-p3 |
| T-0436 | End-of-content state ("more levels coming", daily still available) | feat | features.home | T-0435, T-0420 | META | CHEAP | low | med | low | FR-PROG-07, DESIGN.md#home-end-of-content-p3 |

### E32 PL content to 500
Goal: ~500 curated PL levels before soft launch. Exit: slots 1–500 locked and sampled.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0437 | Content batch: slots 201–350 + landmarks | content | content.pl | T-0408, T-0434, T-0404, T-0430 | CPL | CHEAP | med | none | high | PRODUCT.md#content-requirements |
| T-0438 | Chris QA sampling for 201–350 (landmarks 100 %, rest ~5 % + flagged) | content | content.pl | T-0437 | CPL | HUMAN | — | none | med | PRODUCT.md#content-requirements |
| T-0439 | Content batch: slots 351–500 | content | content.pl | T-0438, T-0431 | CPL | CHEAP | med | none | high | PRODUCT.md#content-requirements |
| T-0440 | Chris QA sampling for 351–500 | content | content.pl | T-0439 | CPL | HUMAN | — | none | med | PRODUCT.md#content-requirements |

### E33 Soft launch
Goal: a limited public release that produces trustworthy data. Exit: go decision executed.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0441 | In-app review plugin + adapter; Chris verifies via Play internal app sharing and TestFlight [HS] | infra | infra | T-0402 | H | CHEAP+HUMAN | med | none | high | FR-PLAT-06, FR-PLAT-01 |
| T-0442 | Review prompt rule: once, after `review.prompt_after_slot`, at a positive moment, never after an ad or a broken streak; counts toward the prompt budget | feat | level.flow | T-0441, T-0419 | LVL | CHEAP | low | low | med | FR-PLAT-06, FR-ONB-04 |
| T-0443 | Chris creates P3 products (`c.coins_m.v1`, `c.coins_l.v1`, `c.starter_pack.v1`) (starter pack only if Q5 = yes in T-0402) | docs | store | T-0402 | STORE | HUMAN | — | none | high | FR-IAP-09, PRODUCT.md#iap-catalog |
| T-0444 | Starter pack: one purchase per install, contents from config, placement per decision (no popup) (conditional on Q5 in T-0402; marked dropped if Q5 = no) | feat | services.monetization | T-0443, T-0425 | PLAT | SOL | high | med | high | FR-IAP-09 |
| T-0445 | Shop P3: coin packs M/L + starter pack card (starter pack card only if Q5 = yes) | feat | features.shop | T-0444 | PLAT | CHEAP | med | high | high | FR-IAP-09, DESIGN.md#shop-sheet |
| T-0446 | A/B experiment: ad frequency buckets (`ads.interstitial.min_levels_between`) in remote config + analysis plan | feat | data.config | T-0402 | DATA | SOL+HUMAN | high | none | high | FR-CFG-05, FR-ADS-09, PRODUCT.md#hypotheses-to-validate |
| T-0447 | Soft-launch market decision (Q12, H3) | docs | docs | T-0402 | DOC | HUMAN | — | none | med | PRODUCT.md#hypotheses-to-validate, PRODUCT.md#open-questions |
| T-0448 | Telemetry export: per-slot metrics (time, hints, abandon) and weekly top invalid strings → CSV for the pipeline | feat | tools | T-0411 | TOOL | SOL+HUMAN | med | none | med | FR-ANL-06, PRODUCT.md#funnels |
| T-0449 | Opus soft-launch readiness audit: daily/streak UX, P3 economy, architecture, release pipeline | docs | docs | T-0427, T-0425, T-0440, T-0436, T-0442, T-0422, T-0433, T-0446, T-0411, T-0412, T-0475 | DOC | OPUS | high | med | med | dp11 §4, dp05 §2 |
| T-0450 | Final store listings, updated data-safety / privacy forms, production access (closed test complete), soft-launch countries | docs | store | T-0447, T-0449, T-0318 | STORE | HUMAN | — | med | high | PRODUCT.md#compliance-and-store-requirements |
| T-0451 | GO / NO-GO soft launch: release checklist passes, crash-free target on the test cohort; on GO, staged rollout to the soft-launch countries | docs | docs | T-0450, T-0409, T-0410 | DOC | HUMAN | — | none | high | NFR-07, TESTING.md |

### E34 Post-launch data loop
Goal: decisions from data, content beyond 500. Exit: experiment read out, loops running weekly, 1000+
PL levels.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0452 | Weeks 1–2 telemetry review → next waves; D1 gate: if D1 is far below the benchmark, an onboarding fix wave comes before content | docs | docs | T-0451, T-0448 | DOC | SOL+HUMAN | high | med | med | PRODUCT.md#kpis, PRODUCT.md#goals-and-non-goals |
| T-0453 | Difficulty calibration: Sol writes `pipeline/scoring/fit.py` + tests; CI fits the weights on the committed T-0448 CSV and attaches the before / after QA report; Chris approves; re-sequence unreleased slots only | feat | pipeline.scoring | T-0452 | PIPE | SOL+HUMAN | high | none | high | FR-ANL-06, PRODUCT.md#hypotheses-to-validate |
| T-0454 | Dictionary repair loop: invalid strings vs source → review queue → overrides → bonus-only re-export of released slots | feat | pipeline.tiers | T-0452 | PIPE | CHEAP | med | none | high | FR-BONUS-04, FR-CONT-04, PRODUCT.md#funnels |
| T-0455 | Chris reviews the dictionary repair queue (weekly, recurring) | content | content.pl | T-0454 | CPL | HUMAN | — | none | med | dp11 §1, PRODUCT.md#hypotheses-to-validate |
| T-0456 | Onboarding tuning from funnel F1 (config and copy; scene changes split into CHEAP tasks); if the change alters the teaching sequence or unlock moments (not only numbers or copy), Chris runs an Opus second opinion before the wave | feat | features.onboarding | T-0452 | SCR | SOL+HUMAN | med | high | med | FR-ONB-02, PRODUCT.md#funnels, dp05 §3.3 |
| T-0457 | Experiment readout → default ad frequency; economy tuning from soft-launch data (sim + telemetry); Chris approves | feat | data.config | T-0452, T-0446 | DATA | SOL+HUMAN | high | none | high | FR-CFG-05, FR-ECON-06, PRODUCT.md#hypotheses-to-validate |
| T-0458 | Content batch slots 501–750 with calibrated scoring + QA sampling | content | content.pl | T-0453, T-0440 | CPL | CHEAP+HUMAN | med | none | high | PRODUCT.md#goals-and-non-goals |
| T-0483 | Content batch slots 751–1000 with calibrated scoring + QA sampling | content | content.pl | T-0458 | CPL | CHEAP+HUMAN | med | none | high | PRODUCT.md#goals-and-non-goals |
| T-0459 | Opus post-launch direction review: H2 postcards vs world-building, H3 market, which Later epic first | docs | docs | T-0457 | DOC | OPUS | high | low | low | dp05 §2, PRODUCT.md#hypotheses-to-validate |

### E35 EN content
Goal: English content once PL works (decision 0005). Exit: EN selectable with 500 levels and daily pool.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0460 | Chris recruits and contracts a native EN reviewer (scope: word rules, overrides queue, onboarding levels; budget); decision: EN word rules (like 0004) with that reviewer | docs | docs | T-0452 | DOC | SOL+HUMAN | high | none | high | decision 0005 |
| T-0461 | EN sources + licences (SCOWL / ENABLE, frequency) → decision | spike | pipeline.ingest | T-0460 | PIPE | SOL+HUMAN | high | none | high | dp09 §8 |
| T-0462 | EN pipeline config (`en.yaml`, alphabet, normalization) + ingest / annotate | feat | pipeline.annotate | T-0461 | PIPE | CHEAP | med | none | med | decision 0005 |
| T-0463 | EN classification + tiers; native reviewer resolves the queue → `overrides/en.csv` | content | content.en | T-0462 | CEN | CHEAP+HUMAN | med | none | high | FR-CONT-05 |
| T-0464 | EN onboarding levels 1–15 + landmark set (native reviewer + Chris) | content | content.en | T-0463 | CEN | HUMAN | — | high | med | FR-ONB-02 |
| T-0465 | EN content batch slots 1–250 + QA sampling | content | content.en | T-0464 | CEN | CHEAP+HUMAN | med | none | high | FR-CONT-01, FR-CONT-08 |
| T-0478 | EN content batch slots 251–500 + QA sampling | content | content.en | T-0465 | CEN | CHEAP+HUMAN | med | none | high | FR-CONT-01 |
| T-0479 | EN daily pool ≥90 days + native review | content | content.en | T-0465 | CEN | CHEAP+HUMAN | low | none | med | FR-CONT-08 |
| T-0466 | Enable EN content in the language selector; per-language progress test | feat | features.settings | T-0478, T-0479 | SCR | CHEAP | low | low | med | FR-SET-02, FR-PROG-05, FR-LOC-01 |
| T-0467 | EN store listing, consent texts, privacy review | docs | store | T-0466 | STORE | SOL+HUMAN | low | none | med | FR-LOC-05 |

### E36 DE content and DE UI
Goal: German after English. Exit: DE UI complete and DE content selectable.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0468 | Chris recruits and contracts a native DE reviewer; decision: DE word rules (umlaut tiles, ß, compound length caps) | docs | docs | T-0466 | DOC | SOL+HUMAN | high | none | high | decision 0005 |
| T-0469 | DE UI strings complete + gallery check in DE at 130 % | feat | locale | T-0325 | SCR | SOL+HUMAN | med | med | low | FR-LOC-03, NFR-12 |
| T-0470 | DE sources + licences → decision | spike | pipeline.ingest | T-0468 | PIPE | SOL+HUMAN | high | none | high | dp09 §8 |
| T-0471 | DE pipeline config + ingest / annotate | feat | pipeline.annotate | T-0470 | PIPE | CHEAP | med | none | med | decision 0005 |
| T-0472 | DE tiers + native review → `overrides/de.csv` | content | content.de | T-0471 | CDE | CHEAP+HUMAN | med | none | high | FR-CONT-05 |
| T-0473 | DE onboarding levels 1–15 + landmark set (native reviewer + Chris) | content | content.de | T-0472 | CDE | HUMAN | — | high | high | FR-ONB-02, FR-CONT-08 |
| T-0480 | DE content batch slots 1–250 + QA sampling | content | content.de | T-0473 | CDE | CHEAP+HUMAN | med | none | high | FR-CONT-01 |
| T-0481 | DE content batch slots 251–500 + QA sampling | content | content.de | T-0480 | CDE | CHEAP+HUMAN | med | none | high | FR-CONT-01 |
| T-0482 | DE daily pool ≥90 days + native review | content | content.de | T-0480 | CDE | CHEAP+HUMAN | low | none | med | FR-CONT-08 |
| T-0476 | Enable DE content in the language selector; per-language progress test; umlaut tiles on the wheel checked in the gallery | feat | features.settings | T-0469, T-0481, T-0482 | SCR | CHEAP | low | low | med | FR-SET-02, FR-PROG-05, FR-LOC-01, NFR-12 |
| T-0474 | DE store listing, privacy policy and consent texts | docs | store | T-0476 | STORE | SOL+HUMAN | low | none | med | FR-LOC-05 |

### E37 Phase 3 exit
Goal: confirm the Phase 3 exit criteria. Exit: Chris signs the row.

| ID | Title | Type | Area | Depends | Lane | Exec | Think | UI | Risk | Refs |
|---|---|---|---|---|---|---|---|---|---|---|
| T-0477 | PHASE 3 EXIT: release from CI, daily + streak + ~500 PL levels live, ad-frequency experiment read out, dictionary and difficulty loops running, 1000+ PL levels, EN and DE content shipped (dropped rows count as done) | docs | docs | T-0453, T-0455, T-0456, T-0457, T-0459, T-0483, T-0445, T-0467, T-0474 | DOC | HUMAN | — | none | low | dp11 §4 |

## Later (data-gated)

Epic-level only. No task rows until the data condition holds; tasks then take IDs from T-0600 up.
EN and DE content are not here: they are Phase 3 (E35, E36).

| Epic | Scope | Unlocking data condition | Requirements |
|---|---|---|---|
| E40 Events template | One time-limited event type (collect N tokens by finding words; UTC window; reward track) defined in remote JSON | D7/D30 stable at or above benchmark and content production ≥ 4 weeks ahead of the fastest 10 % of players | dp03 §4.11 |
| E41 Local notifications | Opt-in daily reminder | Daily participation (`daily_complete` / DAU) meaningful but D1→D7 drop high, and players opt in when asked in a test | FR-PLAT-07 |
| E42 Cloud save | `Platform.cloud` adapter, per-section merge | H6: `save_corrupted`, backup-restore failures or support requests about device change are material | FR-SAVE-09 |
| E43 Achievements | Data-defined counters fed by Events; Play Games / Game Center only on demand | Retention plateau after day 30 and player requests | FR-PLAT-08 |
| E44 Piggy bank / pass | One additional monetization layer | IAP conversion and ARPPU stable; H1 settled; no retention cost in A/B | FR-IAP-10 |
| E45 Ads mediation | Mediation adapters | Fill rate or eCPM from soft-launch data below target | FR-ADS-10 |
| E46 Downloadable content packs | Content packs without app update | Content updates more often than app releases, or app size near NFR-05 budget | FR-CONT-09 |
| E47 World-building scenes | Changing location art by stage | H2 fails: postcards do not lift D7/D30 past level 10 | PRODUCT.md#hypotheses-to-validate |
| E48 Dark theme | `Palette` dark variant | Player requests; night-session share high | DESIGN.md#palette |
| E49 More content languages | Next language after DE | Soft-launch market data per language | decision 0005 |

## Parallelization map

Rule: lanes are queues; `tools/tasks.py plan` releases at most one task per lane and never two tasks in
the same area or with overlapping `touch`. Within a phase each area maps to exactly one lane. The
concurrency cap is Chris's review throughput, not the number of agents.

| Phase | Lane → areas | Concurrent | Strictly serial and why |
|---|---|---|---|
| 0 | DOC: docs · ADM: store · H: infra, ci, tools, services.save, services.content, services.config, services.analytics, services.nav · SPK-P: platform.analytics, platform.ads, platform.iap · SPK-W: level.wheel · SPK-C: pipeline.ingest, pipeline.classify · SPK-G: pipeline.grid · D1: platform.haptics · D2: data.config · D3: features.debug · D4: core.board | Repo-changing work 1 at a time (lane H); DOC + spikes + ADM beside it (other actors); dry run D1–D4 = 4 | Skeleton contracts (autoloads, save, schema, registries, Nav) are serial: everything else builds on them. S1 Android → iOS is serial (same human, devices, accounts). Engine gate blocks E03. |
| 1 | H: infra, ci, services.save · BRD: core.board, level.board · WHL: ui.tokens, level.wheel, platform.haptics · FLOW: level.flow, level.hud · PRG: services.progress, services.content · PIPE: pipeline.* · CPL: content.pl · SUP: locale, services.audio, features.debug · GATE: docs | 3 agent tasks + Chris (typical mix: PIPE + WHL + BRD/FLOW) | Wheel game feel (WHL) iterates human + device and cannot be split. LevelController (T-0115) waits for BoardState, wheel contract and Progress. Pipeline stages are a chain (each consumes the previous artifact). |
| 2 | H: infra, ci, services.save, services.content · DOC: docs · UI: ui.tokens, ui.components, ui.gallery · ART: assets.art, assets.audio · LVL: level.*, core.board, services.audio, platform.haptics · ECO: core.economy, services.economy, features.shop · META: core.progress, services.progress, services.nav, features.home, features.journey · DATA: services.analytics, services.config, data.analytics, data.config, platform.analytics, platform.crash · TOOL: tools · PLAT: core.ads, services.monetization, platform.ads, platform.consent, platform.iap · SCR: features.settings, features.onboarding, features.debug, locale · PIPE: pipeline.* · CPL: content.pl · STORE: store | 4 agent tasks + Chris (e.g. UI + PLAT + DATA + PIPE early; LVL + META + SCR + CPL late) | Visual direction → tokens → theme → components is serial (no screen before its components). Platform integration (consent → ads → IAP, each with device tests) is serial in PLAT and needs the iOS build loop (T-0226, lane H) first. Save v3 (T-0229) precedes every service contract that persists. Level integration (E20) is serial in LVL because it is one screen and game feel. |
| 3 | H: infra, ci, services.save, services.content · DOC: docs · UI: ui.components · DAILY: core.daily, core.streak, services.daily, features.daily · META: features.home, features.journey, features.collection · LVL: level.flow, level.hud · PLAT: services.monetization, features.shop · DATA: data.config, data.analytics, services.analytics · SCR: features.debug, features.settings, features.onboarding, locale · TOOL: tools · PIPE: pipeline.* · ART: assets.art · CPL: content.pl · CEN: content.en · CDE: content.de · STORE: store | 5–6 agent tasks (DAILY, META, PIPE, PLAT, DATA, SCR) + content review by Chris | Save v4 and daily schema (H) precede the Daily service. core/daily and core/streak are xhigh logic in one lane. Release pipeline tasks share workflows (H). EN content starts only after the soft-launch review (T-0452); DE after EN. |

## Merge order rules

1. Topological by `depends_on`: a PR merges only after all its dependencies are merged.
2. Ties between ready PRs: `contract` → `infra` → `risk: high` → the rest. High risk merges early so its
   regressions surface before other changes stack on it (design pass 06 §6).
3. Lane `H` merges strictly one at a time; every other open PR rebases after an `H` merge.
4. Squash merge only; 1 task = 1 commit; remaining PRs rebase. A non-mechanical conflict = re-run the
   task on fresh `main` (`-r2` branch), never a hand-resolved logic conflict (design pass 07 §4).
5. Content PRs (`content.*`) merge after the pipeline and validator PRs they depend on and never in the
   same hour as a schema change; CI `content-validate` must be green on the rebased branch.
6. Device-test and gate tasks (HUMAN `test` / `docs`) close only after the PRs they verify are merged.
7. A PR written by Sol is reviewed by a fresh Sol chat that sees only the `tools/review_pack.py` output,
   never the chat that wrote it, plus the CHEAP checklist review. For save schemas (T-0036, T-0110,
   T-0229, T-0413), the monetization contract (T-0261) and the IAP flow (T-0271), Chris starts an Opus
   review only if the fresh review leaves an open concern.

## Model usage summary

### Counts per executor and phase

| Phase | SOL | CHEAP | OPUS | HUMAN | SOL+HUMAN | CHEAP+HUMAN | OPUS+HUMAN | Total |
|---|---|---|---|---|---|---|---|---|
| P0 | 29 | 9 | 1 | 4 | 4 | 2 | 2 | 51 |
| P1 | 11 | 26 | 1 | 6 | 0 | 1 | 0 | 45 |
| P2 | 24 | 60 | 3 | 18 | 8 | 15 | 2 | 130 |
| P3 | 10 | 28 | 3 | 14 | 17 | 12 | 0 | 84 |
| All | 74 | 123 | 8 | 42 | 29 | 30 | 4 | 310 |

Tasks involving each executor (combos counted for both): SOL 103, CHEAP 153, OPUS 12, HUMAN 105.
Phase 0 is Sol-heavy (docs, contracts, CI, tools); from Phase 1 on, CHEAP carries scenes, features and
pipeline runs while Sol keeps contracts, validators, pure logic and reviews of every `medium`/`high` PR.

### Every OPUS task and why

| Task | Why Opus |
|---|---|
| T-0010 | Second opinion from another model family on irreversible foundations: product scope, layers, save format, LevelData schema, slot policy, IAP flow (design pass 05 §2). |
| T-0027 | Exploratory native-plugin spike on the engine-gate path; no CHEAP runtime exists yet and Android plugin builds need a local SDK. Same session family as T-0028. |
| T-0028 | S1 iOS is the riskiest unknown (R1): Godot iOS plugins, StoreKit 2, ATT, haptics. Needs a model with a runtime iterating with Chris on a device; Sol has no runtime (decision 0006). |
| T-0142 | P0 + P1 audit before Phase 2 contracts depend on the autoload list, Platform interfaces, LevelData schema, the save migration chain, BoardState, LevelController and pipeline stages. One short session. |
| T-0202 | Economy intents, monetization rules and onboarding are irreversible after launch; Sol drafted them, so the reviewer must be a different model family. |
| T-0204 | Visual direction: HTML/CSS mockups with token names (design pass 10 §1). Opus is the visual foundation owner. |
| T-0205 | Remaining key mockups, font decision, iPad orientation check (Q10), art style document (Q14). Same session family as T-0204. |
| T-0248 | Analytics event names, IAP product IDs and config namespaces cannot be renamed later without breaking data or stores. |
| T-0324 | Phase 2 audit (UX, economy, architecture) is part of the exit criteria. |
| T-0401 | P3 additions that change the economy and retention promises (calendar catch-up, streak repair, starter pack). |
| T-0449 | Readiness audit before real players and real money. |
| T-0459 | Product direction from soft-launch data (which Later epic, world-building or not). |

Fallback-only Opus (not planned, triggered by STOP or two failed rounds): T-0139 wheel feel, T-0227 iOS
haptics, T-0266 ads adapter, T-0273 StoreKit adapter, any cross-module bug that Sol failed twice (design
pass 05 §3.3). Conditional Opus: T-0456 when an onboarding change alters the teaching sequence, and
merge rule 7 reviews of save / IAP contracts when the fresh Sol review leaves a concern.

### Where Sol's missing runtime matters (decision 0006)

| Work | Why runtime matters | Routing |
|---|---|---|
| Godot scenes, components, screens, motion | Visual result and `.tscn` correctness need running the editor/game | CHEAP (Docker image) builds; Sol reviews diffs and the CI-rendered gallery screenshots (T-0327), never screenshots supplied by hand |
| Game-feel iteration (T-0029, T-0139, T-0282) | Iterate-run-feel cycles on a device | CHEAP + Chris on device; OPUS-with-runtime as fallback |
| Platform SDK integration (S1, T-0249, T-0252–T-0253, T-0264–T-0266, T-0269, T-0272–T-0273) | Flaky native plugins, device-only behaviour | CHEAP+HUMAN with Chris running device builds each round; S1 spikes OPUS+HUMAN |
| Build loops (T-0137, T-0226, T-0315) | Every attempt costs a full export | Android: CHEAP iterates locally in the T-0014 image (Android SDK included). iOS: SOL+HUMAN through `build-ios.yml` on macOS CI |
| Difficulty calibration (T-0453) | Fitting needs a run on telemetry | Sol writes `fit.py` + tests; CI runs the fit on the committed CSV and attaches the report |
| Pipeline stages that must be run on real data (T-0121 … T-0125, T-0296 … T-0300, content builds) | Output quality is judged on generated levels | CHEAP runs and attaches reports; Sol writes validators/export (`contract`) whose tests run in CI |
| Economy tuning (T-0237) | Needs `econ_sim` output | CI job T-0236 runs the sim and attaches the report, so Sol tunes from CI output |
| Contracts, pure `core/` logic, docs, CI, tools | Fully covered by unit tests in CI | SOL directly; CI must stay fast and readable (decision 0006 consequence) |

### Thinking-level guidance

| Level | Use for |
|---|---|
| `low` | Mechanical changes, registry entries, fakes, small UI from existing components, content runs with a fixed recipe |
| `med` | Well-specified `feat` with tests, screens from a component tree, docs updates, test-only tasks |
| `high` | Contracts, game-feel and motion work, pipeline algorithms (tiers, grid, sequence), platform adapters, GAME_DESIGN/ARCHITECTURE writing, audits |
| `xhigh` | Save schema and migrations, IAP flow, validators that guard released content, date/streak logic, S1 platform spikes, the monetization contract |

## Chris checkpoints

Every task Chris must do or approve (Exec contains HUMAN), plus gates. OPUS sessions are started by
Chris but listed in the Opus table above.

| Phase | Task | Exec | Chris's part |
|---|---|---|---|
| P0 | T-0001 | HUMAN | Repo (public until P2 content production, Chris 2026-10-02: free Actions and branch protection on GitHub Free); import PRODUCT.md, DESIGN.md, ROADMAP.md, decisions 0004–0006 and the design pass as read-only `docs/design-pass/` |
| P0 | T-0011 | SOL+HUMAN | Apply accepted Opus findings to the docs; Chris approves docs v1 |
| P0 | T-0012 | HUMAN | Store accounts: Google Play Console (personal vs organization; closed-test rule applies to new personal accounts, verify) + Apple Developer; identity verification; pick and provision reference devices (Q13); Play payments profile (needed for IAP tests in S1); EU trader status (DSA) and the public contact address decision |
| P0 | T-0023 | HUMAN | Branch protection: squash only, required checks, up-to-date branches, no force push, auto-delete; labels risk / type / test-count-exception |
| P0 | T-0027 | OPUS+HUMAN | S1 Android: throwaway project on the low-end Android; rewarded + interstitial (test units) with UMP; Play Billing consumable + non-consumable + restore (internal track); analytics event and crash visible in dashboards; haptics; report `docs/spikes/S1-android.md` (Claude Code on Chris's machine; the same session family continues into T-0028) |
| P0 | T-0028 | OPUS+HUMAN | S1 iOS: same matrix on iPhone (StoreKit 2 sandbox incl. restore, UMP, ATT, native haptics, silent switch); report `docs/spikes/S1-ios.md` |
| P0 | T-0029 | CHEAP+HUMAN | S2 swipe: throwaway letter wheel on the low-end Android (input path, Line2D, haptic tick); Chris rates latency; report with recommended input approach |
| P0 | T-0030 | SOL+HUMAN | S3a PL word sources and licences: SJP.pl variants, PoliMorf / Morfeusz, frequency data (wordfreq CC BY-SA vs corpus); count of 3–7-letter words; Chris decides → decision NNNN-pl-word-sources (Q11) |
| P0 | T-0031 | CHEAP+HUMAN | S3b classification trial: 200 PL words through two cheap models (sensitivity, familiarity), agreement rate, cost per 1k words; Chris reviews disagreements |
| P0 | T-0033 **(gate)** | SOL+HUMAN | ENGINE GATE: accept decision 0001 (Godot pinned) or switch to Unity 6 LTS and re-plan the Godot-specific E01 rows (T-0013, T-0014, T-0015, T-0018), E03 and E04; record providers (Q8), min Android API / iOS (Q9), haptics and silent-switch approach, mobile screen-reader support on the pinned version (FR-A11Y-04) → decision NNNN-platform-providers |
| P0 | T-0050 | SOL+HUMAN | Dry-run retrospective: escalations, red CI runs, Chris's review minutes; fixes to TEMPLATE.md and AGENTS.md |
| P0 | T-0051 **(gate)** | HUMAN | PHASE 0 EXIT: S1 passed or engine switched, `make check` green in CI, ≥3 cheap tasks merged without manual code fixes, docs v1 merged, language and source decisions recorded |
| P1 | T-0129 | HUMAN | Chris seeds `overrides/pl.csv`: review top ~300 level-word candidates (ban weird, archaic, vulgar) |
| P1 | T-0130 | HUMAN | Chris authors ~10 hand-made PL levels (YAML) |
| P1 | T-0136 | HUMAN | Chris: Android upload keystore + GitHub secrets (rule S11) |
| P1 | T-0139 | CHEAP+HUMAN | Wheel game-feel rounds on the low-end Android: Chris plays debug APK, CHEAP adjusts token and config values; OPUS-with-runtime if two rounds fail |
| P1 | T-0140 | HUMAN | Chris plays all P1 levels in debug; flags words and levels → overrides + rebuild |
| P1 | T-0141 | HUMAN | Playtest: 5 outsiders, ≥20 minutes, no instructions, reference Android; notes in `docs/qa/` |
| P1 | T-0143 **(gate)** | HUMAN | FUN GATE (Chris): go / fix core (Sol plans a fix wave from P1 reserve IDs, then rerun T-0141) / stop |
| P2 | T-0203 | SOL+HUMAN | Chris decides intents, Q2, Q7, Q15 and the onboarding plan; Sol applies to GAME_DESIGN and lists config defaults |
| P2 | T-0204 | OPUS+HUMAN | Visual direction: verbal moodboard + 2–3 HTML/CSS mockups of Level with token-named CSS variables; Chris picks on his phone |
| P2 | T-0205 | OPUS+HUMAN | Mockups of Home, Level complete, Journey, Shop sheet and onboarding overlays (Level 1 TutorialHand + caption, coach mark); font verification (coverage, `tnum`, OFL) → decision NNNN-fonts; iPad portrait check (Q10); art style document for postcards and icon (Q14) |
| P2 | T-0226 | SOL+HUMAN | iOS export preset + `build-ios.yml` on macOS (manual dispatch + nightly) + signing secrets; iOS haptics plugin if the providers decision needs one [HS] |
| P2 | T-0315 | CHEAP+HUMAN | Android AAB release export (Play App Signing) + Auto Backup rules for the save file [HS] |
| P2 | T-0221 | HUMAN | Gallery review on reference devices (low-end Android, iPhone, iPad): all states in COMPACT / REGULAR / TABLET, PL and PSEUDO (+35 %) at 130 %, high contrast; findings become fix tasks |
| P2 | T-0227 | CHEAP+HUMAN | iOS haptics adapter: native patterns verified on iPhone; Chris runs the iOS build on the iPhone each round; OPUS-with-runtime after two failed rounds |
| P2 | T-0237 | SOL+HUMAN | Tune economy config from the sim report against the intents; Chris approves |
| P2 | T-0249 | CHEAP+HUMAN | Analytics / crash SDK plugins per the providers decision (no-op if HTTP-based); provider config via secrets [HS] |
| P2 | T-0252 | CHEAP+HUMAN | Platform analytics adapter (real) on Android + iOS; events visible in the dashboard |
| P2 | T-0253 | CHEAP+HUMAN | Crash adapter (real) with app + content version tags; test crash visible |
| P2 | T-0257 | SOL+HUMAN | Remote config hosting: `remote/config.json` in repo, schema check in CI, publish workflow to the CDN (GitHub Pages or R2) [HS] |
| P2 | T-0259 | HUMAN | AdMob account, app registration, ad units, UMP privacy message (EEA/UK) configuration; developer website domain with `app-ads.txt` (same domain as the privacy policy, T-0313) |
| P2 | T-0264 | CHEAP+HUMAN | AdMob + UMP plugin; Android manifest and iOS plist entries (app ID, AD_ID, SKAdNetwork, ATT usage string) [HS] |
| P2 | T-0265 | CHEAP+HUMAN | Consent adapter (UMP) + ATT (iOS) + privacy options form; Chris runs the iOS build on the iPhone each round |
| P2 | T-0266 | CHEAP+HUMAN | Ads adapter (AdMob rewarded + interstitial, test units); OPUS-with-runtime after two failed rounds |
| P2 | T-0267 | HUMAN | Device test ads + consent, Android and iPhone: UMP via debug geography, ATT allow/deny, reward only after full watch, offline, background during ad, audio pause |
| P2 | T-0268 | HUMAN | Chris approves P2 catalog and price points (Q6); creates `nc.remove_forced_ads.v1` and `c.coins_s.v1` in App Store Connect (Play products follow in T-0272) |
| P2 | T-0272 | CHEAP+HUMAN | Play Billing adapter + local signature verification; Chris uploads an internal-track AAB with the billing plugin, then creates both products in Play Console |
| P2 | T-0273 | CHEAP+HUMAN | StoreKit 2 adapter + signed transaction verification; OPUS-with-runtime after two failed rounds; Chris runs the iOS build each round |
| P2 | T-0275 | HUMAN | Device test IAP sandbox, both stores: purchase, cancel, restore, kill during purchase, pending / Ask to Buy, Remove Forced Ads stops interstitials |
| P2 | T-0282 | CHEAP+HUMAN | Game-feel tuning on device: Chris plays, CHEAP edits Motion/Ease values in `tokens.gd` |
| P2 | T-0283 | CHEAP+HUMAN | Performance pass: 60 fps Level on low-end Android, no idle redraw, level load ≤ 100 ms timer in debug, cold start measured |
| P2 | T-0289 | SOL+HUMAN | UI strings PL + EN for all P2 screens (no plural-dependent sentences; Chris approves PL); location names and facts |
| P2 | T-0296 | CHEAP+HUMAN | Classify: batch AI classification (before this first production content run Chris switches the repo to private, with GitHub Pro if branch protection must stay), committed cache keyed (word, prompt version, model), two passes, disagreement CSV; Chris adds the API key as a CI / agent secret and sets a spend cap from the T-0031 cost-per-1k figure |
| P2 | T-0304 | HUMAN | Chris reviews the disagreement queue and flagged candidates → `overrides/pl.csv` (batch 1) |
| P2 | T-0305 | HUMAN | Chris hand-makes onboarding levels 1–15 (YAML) per GAME_DESIGN.md#onboarding |
| P2 | T-0307 | HUMAN | Chris plays 100 % of the first ~100 levels in debug; flags → overrides; rebuild |
| P2 | T-0308 | HUMAN | Region 1 postcards (3–4 illustrations) generated per the style document; Chris selects |
| P2 | T-0310 | CHEAP+HUMAN | App icon + splash per the style document |
| P2 | T-0311 | CHEAP+HUMAN | Final SFX set + 1–2 music loops (licensed or CC0), OGG, final `cues.json`; Chris selects |
| P2 | T-0312 | HUMAN | Trademark search and store name (Q1) |
| P2 | T-0313 | SOL+HUMAN | Privacy policy v1 PL + EN (public URL); data inventory from the registry and SDKs |
| P2 | T-0314 | HUMAN | Play Data safety, Apple privacy labels + SDK privacy manifests, target audience (18 and over), IARC and App Store age rating |
| P2 | T-0316 | SOL+HUMAN | iOS distribution signing + TestFlight provisioning; save in a backed-up directory on iOS [HS] |
| P2 | T-0320 | SOL+HUMAN | Store listing drafts PL + EN (name, short + full description, icon, screenshots from the current build; final gameplay screenshots in T-0450) |
| P2 | T-0318 | HUMAN | Start Google Play closed testing (recruit ≥12 testers for 14 days; verify the current rule) with the first stable P2 build; listing from T-0320 in place |
| P2 | T-0319 | HUMAN | TestFlight internal testing |
| P2 | T-0321 | HUMAN | Device test: save restored on a new device through OS backup (Android + iOS) |
| P2 | T-0258 | HUMAN | Funnels F1–F3 defined in the provider dashboard; event QA on device for the P2a and P2b listeners |
| P2 | T-0322 | HUMAN | Device checklist on 3 reference devices (`TESTING.md`): offline / airplane mode, interruptions, clean-install first 10 minutes, battery and thermal, cold start |
| P2 | T-0323 | HUMAN | Onboarding playtest: 5 new players through level 15; funnel observed |
| P2 | T-0325 **(gate)** | HUMAN | PHASE 2 EXIT: sandbox IAP + ads pass, checklist pass on 3 devices, no critical audit findings, Chris: "I would download it" |
| P3 | T-0402 | SOL+HUMAN | Chris decides Q3, Q4, Q5; Sol applies to GAME_DESIGN and updates the DESIGN.md P3 screen specs (Collection, multi-region Journey, landmark, end of content) to the decisions |
| P3 | T-0409 | SOL+HUMAN | Signed AAB to Play internal track from CI on tag (fastlane or equivalent); version name and code injected from `game/version.json` at export [HS] |
| P3 | T-0410 | SOL+HUMAN | iOS archive + TestFlight upload from CI (macOS) on tag; version name and code injected from `game/version.json` at export [HS] |
| P3 | T-0422 | CHEAP+HUMAN | Daily pool content: ≥90 days PL + Chris review; rolling ≥60-day buffer rule in CONTENT.md |
| P3 | T-0427 | HUMAN | Device test daily + streak: day change, TZ change, DST, clock rollback, freeze, repair, backup restore |
| P3 | T-0429 | SOL+HUMAN | Regions 2–3: location list, names, facts PL/EN |
| P3 | T-0430 | HUMAN | Region 2 art batch (Chris generates and selects) |
| P3 | T-0431 | HUMAN | Region 3 art batch |
| P3 | T-0434 | HUMAN | Chris hand-makes landmark levels for regions 1–3 |
| P3 | T-0438 | HUMAN | Chris QA sampling for 201–350 (landmarks 100 %, rest ~5 % + flagged) |
| P3 | T-0440 | HUMAN | Chris QA sampling for 351–500 |
| P3 | T-0441 | CHEAP+HUMAN | In-app review plugin + adapter; Chris verifies via Play internal app sharing and TestFlight [HS] |
| P3 | T-0443 | HUMAN | Chris creates P3 products (`c.coins_m.v1`, `c.coins_l.v1`, `c.starter_pack.v1`) (starter pack only if Q5 = yes in T-0402) |
| P3 | T-0446 | SOL+HUMAN | A/B experiment: ad frequency buckets (`ads.interstitial.min_levels_between`) in remote config + analysis plan |
| P3 | T-0447 | HUMAN | Soft-launch market decision (Q12, H3) |
| P3 | T-0448 | SOL+HUMAN | Telemetry export: per-slot metrics (time, hints, abandon) and weekly top invalid strings → CSV for the pipeline |
| P3 | T-0450 | HUMAN | Final store listings, updated data-safety / privacy forms, production access (closed test complete), soft-launch countries |
| P3 | T-0451 **(gate)** | HUMAN | GO / NO-GO soft launch: release checklist passes, crash-free target on the test cohort; on GO, staged rollout to the soft-launch countries |
| P3 | T-0452 **(gate)** | SOL+HUMAN | Weeks 1–2 telemetry review → next waves; D1 gate: if D1 is far below the benchmark, an onboarding fix wave comes before content |
| P3 | T-0453 | SOL+HUMAN | Difficulty calibration: Sol writes `pipeline/scoring/fit.py` + tests; CI fits the weights on the committed T-0448 CSV and attaches the before / after QA report; Chris approves; re-sequence unreleased slots only |
| P3 | T-0455 | HUMAN | Chris reviews the dictionary repair queue (weekly, recurring) |
| P3 | T-0456 | SOL+HUMAN | Onboarding tuning from funnel F1 (config and copy; scene changes split into CHEAP tasks); if the change alters the teaching sequence or unlock moments (not only numbers or copy), Chris runs an Opus second opinion before the wave |
| P3 | T-0457 | SOL+HUMAN | Experiment readout → default ad frequency; economy tuning from soft-launch data (sim + telemetry); Chris approves |
| P3 | T-0458 | CHEAP+HUMAN | Content batch slots 501–750 with calibrated scoring + QA sampling |
| P3 | T-0483 | CHEAP+HUMAN | Content batch slots 751–1000 with calibrated scoring + QA sampling |
| P3 | T-0460 | SOL+HUMAN | Chris recruits and contracts a native EN reviewer (scope: word rules, overrides queue, onboarding levels; budget); decision: EN word rules (like 0004) with that reviewer |
| P3 | T-0461 | SOL+HUMAN | EN sources + licences (SCOWL / ENABLE, frequency) → decision |
| P3 | T-0463 | CHEAP+HUMAN | EN classification + tiers; native reviewer resolves the queue → `overrides/en.csv` |
| P3 | T-0464 | HUMAN | EN onboarding levels 1–15 + landmark set (native reviewer + Chris) |
| P3 | T-0465 | CHEAP+HUMAN | EN content batch slots 1–250 + QA sampling |
| P3 | T-0478 | CHEAP+HUMAN | EN content batch slots 251–500 + QA sampling |
| P3 | T-0479 | CHEAP+HUMAN | EN daily pool ≥90 days + native review |
| P3 | T-0467 | SOL+HUMAN | EN store listing, consent texts, privacy review |
| P3 | T-0468 | SOL+HUMAN | Chris recruits and contracts a native DE reviewer; decision: DE word rules (umlaut tiles, ß, compound length caps) |
| P3 | T-0469 | SOL+HUMAN | DE UI strings complete + gallery check in DE at 130 % |
| P3 | T-0470 | SOL+HUMAN | DE sources + licences → decision |
| P3 | T-0472 | CHEAP+HUMAN | DE tiers + native review → `overrides/de.csv` |
| P3 | T-0473 | HUMAN | DE onboarding levels 1–15 + landmark set (native reviewer + Chris) |
| P3 | T-0480 | CHEAP+HUMAN | DE content batch slots 1–250 + QA sampling |
| P3 | T-0481 | CHEAP+HUMAN | DE content batch slots 251–500 + QA sampling |
| P3 | T-0482 | CHEAP+HUMAN | DE daily pool ≥90 days + native review |
| P3 | T-0474 | SOL+HUMAN | DE store listing, privacy policy and consent texts |
| P3 | T-0477 **(gate)** | HUMAN | PHASE 3 EXIT: release from CI, daily + streak + ~500 PL levels live, ad-frequency experiment read out, dictionary and difficulty loops running, 1000+ PL levels, EN and DE content shipped (dropped rows count as done) |

Not listed as rows but always Chris's: merging every PR (glance for `low`, device check for `high`),
skimming each planned wave (`plan/*` PR), and reviewing `content` PRs (word lists) before merge.

Driving the models is also Chris's work: Sol has no scheduler, so every SOL row, wave plan and Sol
review is a ChatGPT session Chris opens. Budget one Sol session per wave that (a) writes the next wave's
task files, (b) reviews all open `medium` / `high` PRs from `tools/review_pack.py`, and (c) implements at
most one SOL row. Chris also starts the CHEAP harness runs and the OPUS sessions.

### Chris load per phase

| Phase | Rows with Chris (Exec has HUMAN) | OPUS sessions Chris starts | UI `high` rows (device review) | Risk `high` rows | All rows |
|---|---|---|---|---|---|
| P0 | 12 | 3 | 1 | 19 | 51 |
| P1 | 7 | 1 | 3 | 16 | 45 |
| P2 | 43 | 5 | 29 | 56 | 130 |
| P3 | 43 | 3 | 11 | 38 | 84 |

Phases 2 and 3 carry the most Chris rows, and Phase 2 also has the most UI `high` and risk `high` rows. Rules
that keep this realistic:
- Device tests for `risk: high` are batched. Chris installs the CI build of each open `high` PR once per
  wave and checks them in one sitting.
- `risk: high` rows of type `contract`, `infra` or `content` with no player-visible change are verified
  by CI plus the next scheduled HUMAN device row (T-0139, T-0221, T-0267, T-0275, T-0282, T-0322,
  T-0427), not per PR.
- While Chris has an open HUMAN row in STORE, CPL or ART, Phase 2 runs at most 3 agent tasks.
- UI `high` screenshots for review come from the CI gallery job (T-0327); Chris's own device check is
  reserved for screens and the gated device rows.

## FR coverage matrix

Every requirement in `PRODUCT.md` → tasks that implement or verify it. Generated from the Refs column;
Sol regenerates it when re-planning a wave.

| Requirement | Phase | Tasks |
|---|---|---|
| FR-ADS-01 | P2 | T-0260 |
| FR-ADS-02 | P2 | T-0229, T-0234, T-0260 |
| FR-ADS-03 | P2 | T-0260, T-0263, T-0419 |
| FR-ADS-04 | P2 | T-0027, T-0261, T-0263, T-0266, T-0267, T-0425 |
| FR-ADS-05 | P2 | T-0261, T-0263, T-0266, T-0267 |
| FR-ADS-06 | P2 | T-0261, T-0263, T-0264 |
| FR-ADS-07 | P2 | T-0260, T-0263 |
| FR-ADS-08 | P2 | T-0228, T-0261, T-0266, T-0267 |
| FR-ADS-09 | P3 | T-0446 |
| FR-ADS-10 | Later | Later: E45 |
| FR-ANL-01 | P2 | T-0038, T-0039, T-0247, T-0328 |
| FR-ANL-02 | P2 | T-0250, T-0252 |
| FR-ANL-03 | P2 | T-0250, T-0252 |
| FR-ANL-04 | P2 | T-0251 |
| FR-ANL-05 | P2 | T-0249, T-0253 |
| FR-ANL-06 | P3 | T-0448, T-0453 |
| FR-AUDIO-01 | P1 | T-0133, T-0144 |
| FR-AUDIO-02 | P1 | T-0046, T-0109, T-0226, T-0227 |
| FR-AUDIO-03 | P2 | T-0228, T-0311 |
| FR-AUDIO-04 | P2 | T-0028, T-0228 |
| FR-BOARD-01 | P1 | T-0113 |
| FR-BOARD-02 | P1 | T-0113, T-0223 |
| FR-BOARD-03 | P1 | T-0114, T-0224 |
| FR-BOARD-04 | P1 | T-0114 |
| FR-BOARD-05 | P1 | T-0107 |
| FR-BOARD-06 | P1 | T-0107 |
| FR-BOARD-07 | P1 | T-0118 |
| FR-BONUS-01 | P1 | T-0101, T-0117 |
| FR-BONUS-02 | P2 | T-0231, T-0280 |
| FR-BONUS-03 | P2 | T-0229, T-0280 |
| FR-BONUS-04 | P3 | T-0454 |
| FR-CFG-01 | P1 | T-0037, T-0039, T-0047 |
| FR-CFG-02 | P2 | T-0254, T-0255, T-0257 |
| FR-CFG-03 | P2 | T-0254, T-0255 |
| FR-CFG-04 | P2 | T-0254, T-0255 |
| FR-CFG-05 | P3 | T-0446, T-0457 |
| FR-CONSENT-01 | P2 | T-0259, T-0261, T-0263, T-0265 |
| FR-CONSENT-02 | P2 | T-0250 |
| FR-CONSENT-03 | P2 | T-0265, T-0288 |
| FR-CONSENT-04 | P2 | T-0028, T-0263, T-0264, T-0265, T-0267 |
| FR-CONT-01 | P1 | T-0004, T-0008, T-0040, T-0041, T-0126, T-0127, T-0128, T-0131, T-0465, T-0478, T-0480, T-0481 |
| FR-CONT-02 | P1 | T-0008, T-0040, T-0041, T-0127 |
| FR-CONT-03 | P2 | T-0008, T-0301, T-0302 |
| FR-CONT-04 | P2 | T-0008, T-0301, T-0454 |
| FR-CONT-05 | P1 | T-0008, T-0121, T-0123, T-0296, T-0297, T-0463, T-0472 |
| FR-CONT-06 | P1 | T-0008, T-0125, T-0127, T-0408 |
| FR-CONT-07 | P1 | T-0042, T-0119 |
| FR-CONT-08 | P3 | T-0406, T-0407, T-0422, T-0465, T-0473, T-0479, T-0482 |
| FR-CONT-09 | Later | Later: E46 |
| FR-CORE-01 | P1 | T-0100, T-0101, T-0115 |
| FR-CORE-02 | P1 | T-0004, T-0100 |
| FR-CORE-03 | P1 | T-0041, T-0100 |
| FR-CORE-04 | P1 | T-0101 |
| FR-CORE-05 | P1 | T-0101, T-0126 |
| FR-CORE-06 | P1 | T-0101 |
| FR-CORE-07 | P1 | T-0101 |
| FR-CORE-08 | P1 | T-0110, T-0112 |
| FR-DAILY-01 | P3 | T-0005, T-0406, T-0414, T-0415, T-0419 |
| FR-DAILY-02 | P3 | T-0415, T-0420 |
| FR-DAILY-03 | P3 | T-0415, T-0416 |
| FR-DAILY-04 | P3 | T-0415, T-0416 |
| FR-DAILY-05 | P3 | T-0406, T-0416 |
| FR-DAILY-06 | P3 | T-0005, T-0414, T-0423, T-0427 |
| FR-DEBUG-01 | P1 | T-0048, T-0134 |
| FR-DEBUG-02 | P1 | T-0135 |
| FR-DEBUG-03 | P2 | T-0262, T-0270, T-0294 |
| FR-DEBUG-04 | P2 | T-0329 |
| FR-DEBUG-05 | P3 | T-0403 |
| FR-DEBUG-06 | P1 | T-0048, T-0137, T-0138 |
| FR-ECON-01 | P2 | T-0230 |
| FR-ECON-02 | P2 | T-0230, T-0231, T-0232 |
| FR-ECON-03 | P2 | T-0229, T-0232, T-0233 |
| FR-ECON-04 | P2 | T-0230, T-0234 |
| FR-ECON-05 | P2 | T-0234, T-0281 |
| FR-ECON-06 | P2 | T-0235, T-0236, T-0237, T-0457 |
| FR-ECON-07 | P2 | T-0119, T-0237 |
| FR-HINT-01 | P1 | T-0102, T-0117 |
| FR-HINT-02 | P1 | T-0102, T-0117 |
| FR-HINT-03 | P2 | T-0234, T-0278 |
| FR-HINT-04 | P2 | T-0277, T-0278 |
| FR-HINT-05 | P2 | T-0278 |
| FR-HINT-06 | P1 | T-0049, T-0108, T-0117 |
| FR-HINT-07 | P2 | T-0234, T-0279 |
| FR-IAP-01 | P2 | T-0268, T-0274 |
| FR-IAP-02 | P2 | T-0271, T-0275 |
| FR-IAP-03 | P2 | T-0027, T-0261, T-0270, T-0271, T-0275 |
| FR-IAP-04 | P2 | T-0261, T-0271, T-0275 |
| FR-IAP-05 | P2 | T-0271, T-0275 |
| FR-IAP-06 | P2 | T-0271, T-0274, T-0275, T-0288 |
| FR-IAP-07 | P2 | T-0271, T-0275 |
| FR-IAP-08 | P2 | T-0269, T-0272, T-0273 |
| FR-IAP-09 | P3 | T-0443, T-0444, T-0445 |
| FR-IAP-10 | Later | Later: E44 |
| FR-IAP-11 | P2 | T-0271 |
| FR-LOC-01 | P2 | T-0287, T-0466, T-0476 |
| FR-LOC-02 | P1 | T-0132, T-0144, T-0210 |
| FR-LOC-03 | P2 | T-0289, T-0429, T-0469 |
| FR-LOC-04 | P2 | T-0289 |
| FR-LOC-05 | P2 | T-0313, T-0320, T-0467, T-0474 |
| FR-META-01 | P2 | T-0239, T-0240, T-0242, T-0281 |
| FR-META-02 | P2 | T-0234, T-0239, T-0240, T-0242, T-0246 |
| FR-META-03 | P2 | T-0239, T-0240, T-0242, T-0246, T-0432 |
| FR-META-04 | P2 | T-0245, T-0432 |
| FR-META-05 | P2 | T-0244 |
| FR-META-06 | P3 | T-0435 |
| FR-META-07 | P3 | T-0405, T-0433, T-0434 |
| FR-META-08 | P2 | T-0229 |
| FR-ONB-01 | P2 | T-0043, T-0201, T-0243 |
| FR-ONB-02 | P2 | T-0201, T-0291, T-0305, T-0323, T-0326, T-0456, T-0464, T-0473 |
| FR-ONB-03 | P2 | T-0201, T-0229, T-0290, T-0292 |
| FR-ONB-04 | P2 | T-0201, T-0234, T-0260, T-0323, T-0442 |
| FR-ONB-05 | P2 | T-0201, T-0290, T-0328 |
| FR-PLAT-01 | P1 | T-0007, T-0027, T-0035, T-0044, T-0046, T-0262, T-0441 |
| FR-PLAT-02 | P1 | T-0137, T-0226, T-0315, T-0316, T-0319, T-0409, T-0410 |
| FR-PLAT-03 | P2 | T-0212 |
| FR-PLAT-04 | P2 | T-0208, T-0216, T-0243 |
| FR-PLAT-05 | P1 | T-0112 |
| FR-PLAT-06 | P3 | T-0441, T-0442 |
| FR-PLAT-07 | Later | Later: E41 |
| FR-PLAT-08 | Later | Later: E43 |
| FR-PROG-01 | P1 | T-0110, T-0111 |
| FR-PROG-02 | P1 | T-0111, T-0118 |
| FR-PROG-03 | P2 | T-0238, T-0302, T-0306 |
| FR-PROG-04 | P2 | T-0234, T-0239, T-0241, T-0242, T-0276 |
| FR-PROG-05 | P2 | T-0229, T-0241, T-0287, T-0466, T-0476 |
| FR-PROG-06 | P2 | T-0245 |
| FR-PROG-07 | P3 | T-0436 |
| FR-SAVE-01 | P1 | T-0007, T-0036 |
| FR-SAVE-02 | P1 | T-0036 |
| FR-SAVE-03 | P1 | T-0036, T-0251, T-0295 |
| FR-SAVE-04 | P1 | T-0036, T-0110, T-0229, T-0413 |
| FR-SAVE-05 | P1 | T-0036, T-0112 |
| FR-SAVE-06 | P2 | T-0315, T-0316, T-0321 |
| FR-SAVE-07 | P1 | T-0036 |
| FR-SAVE-08 | P2 | T-0229, T-0271 |
| FR-SAVE-09 | Later | Later: E42 |
| FR-SET-01 | P2 | T-0285, T-0286 |
| FR-SET-02 | P2 | T-0287, T-0466, T-0476 |
| FR-SET-03 | P2 | T-0285, T-0288 |
| FR-SET-04 | P2 | T-0284, T-0286 |
| FR-STREAK-01 | P3 | T-0423, T-0424 |
| FR-STREAK-02 | P3 | T-0423, T-0424 |
| FR-STREAK-03 | P3 | T-0423, T-0424 |
| FR-STREAK-04 | P3 | T-0423, T-0425 |
| FR-STREAK-05 | P3 | T-0413, T-0424, T-0427 |
| FR-WHEEL-01 | P1 | T-0105 |
| FR-WHEEL-02 | P1 | T-0029, T-0106 |
| FR-WHEEL-03 | P1 | T-0105 |
| FR-WHEEL-04 | P1 | T-0105 |
| FR-WHEEL-05 | P1 | T-0105 |
| FR-WHEEL-06 | P1 | T-0106 |
| FR-WHEEL-07 | P1 | T-0109 |
| FR-WHEEL-08 | P1 | T-0049, T-0108 |
| FR-WHEEL-09 | P1 | T-0104, T-0433 |
| NFR-01 | NFR | T-0029, T-0106, T-0135, T-0139, T-0282 |
| NFR-02 | NFR | T-0106, T-0139, T-0412 |
| NFR-03 | NFR | T-0118, T-0412 |
| NFR-04 | NFR | T-0322 |
| NFR-05 | NFR | T-0317 |
| NFR-06 | NFR | T-0295, T-0322 |
| NFR-07 | NFR | T-0253, T-0451 |
| NFR-08 | NFR | T-0208, T-0283, T-0322 |
| NFR-09 | NFR | T-0033 |
| NFR-10 | NFR | T-0250, T-0313 |
| NFR-11 | NFR | T-0221, T-0293, T-0322 |
| NFR-12 | NFR | T-0211, T-0221, T-0469, T-0476 |
| NFR-13 | NFR | T-0036, T-0112, T-0271 |
| NFR-14 | NFR | T-0127, T-0408 |
| NFR-15 | NFR | T-0009, T-0018 |

Notes on P1 requirements implemented in P2 form: FR-PLAT-02 (P1 = Android CI build T-0137; iOS
nightly arrives in P2 T-0226), FR-LOC-02 (P1 convention T-0132; CI enforcement P2 T-0210), FR-SAVE-03
(P1 fallback T-0036; `save_corrupted` analytics from P2 T-0251).
