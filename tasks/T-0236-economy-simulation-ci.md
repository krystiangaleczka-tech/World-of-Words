---
id: T-0236
title: Publish deterministic economy simulation reports in CI
epic: E15
type: infra
area: ci
risk: high
executor: sol
think: low
ui: none
status: done
depends_on: [T-0235]
touch:
  - .github/workflows/ci.yml
  - tools/econ_sim_ci.py
  - tools/econ_sim.py
  - tools/tests/test_econ_sim.py
  - tools/tests/test_econ_sim_ci.py
  - tasks/T-0235-economy-simulator.md
  - tasks/T-0236-economy-simulation-ci.md
  - docs/qa/T-0236-economy-simulation-ci.md
revision: 2
---

## Goal
Provide readable economy reports and downloadable JSON/Markdown when relevant config changes.
Owner requested creating and executing this missing task as the second consecutive task.

## Context
Roadmap T-0236; FR-ECON-06; decision 0006 requires readable CI feedback.
Reports remain synthetic assumptions, never balance calibration or native ad evidence.

## Current state
ci.yml runs on pull_request and push main; checkout/upload-artifact v4 are already used.
T-0235 tools/econ_sim.py is a stdlib-only deterministic CLI supporting JSON/Markdown,
no-onboarding and bonus-per-level flags. No economy simulation CI job exists.
Reconcile its merged task status to done within this scope.

## Specification
1. Add independent Ubuntu economy-sim job with full checkout, no new action dependencies,
   permissions, secrets, network endpoints, toolchain changes or other job edits.
2. New stdlib econ_sim_ci.py detects relevant changes with git diff between supplied base/head.
   Trigger all game/data/config/*.json (not only economy: bonus/ads/unlocks/IAP also affect output),
   simulator/detector and their tests, and ci.yml. Unrelated diffs explicitly print SKIP.
   Pull request base uses pull_request.base.sha; main push uses before SHA. Missing/all-zero first
   push base triggers run; invalid nonzero refs fail rather than silently skip.
3. Relevant changes generate default 300-level reports and base-only reports (--no-onboarding
   --bonus-per-level 0); JSON plus Markdown for each. Explain that only base-only saver has no ad
   supply; other policies still model their explicitly requested ads. Print both readable reports,
   append them to GITHUB_STEP_SUMMARY and upload four files as economy-simulation (14 days).
   Upload fails if files are missing. Simulation errors fail the job, no continue-on-error.
4. Existing ci jobs and main/PR triggers remain untouched. No runtime economy/config edits.

## Tests
New test_econ_sim_ci.py: relevant/nonrelevant paths including every config prefix, renamed/deleted
files; actual git base/head diff, initial-zero/missing base, invalid ref failure; CLI changed=true/
false output. Extract and execute new workflow run blocks with supplied CI environment for PR,
main push and skip cases; verify shell syntax, summary and four parseable deterministic artifacts.
Full make check, scope/task lint. Actual new GitHub job must pass and upload four reports before done.

## Rollback
Revert isolated job/detector; other CI and runtime behavior remain unchanged.

## Escalation log
S2 resolved: owner approved fixing Markdown headers in econ_sim.py and its tests in revision 2.

S9: two local make check attempts stopped in Godot import: first a thread propagation crash,
then invalid autoload resource paths from generated import cache. No game/project/export code
changed. Stop and request owner disposition: rebuild generated worktree cache and retry, or
use fresh Linux CI to diagnose before another local run. Draft PR records both failures.

S9 owner disposition: authorized backing up generated worktree cache and one further make check.

S9 resolved: cache backed up; authorized retry passed full make check. GitHub economy job passed
and all four downloaded artifacts match local model byte-for-byte. No game source edits.
