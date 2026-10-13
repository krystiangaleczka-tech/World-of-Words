# T-0236 Economy simulation CI

New independent job detects PR/main changes, emits explicit skips and generates four JSON/Markdown
reports plus readable logs/job summary. Standard Ubuntu Python and existing checkout/upload actions
only; no new permissions, secrets or dependencies. Artifact errors fail the job.

16 tests cover real git diffs, renames/deletions, invalid refs, initial push and PR/main environment,
actual workflow shell execution, four artifacts, repeatability, summaries and simulation failure.
Owner approved S2 scope expansion to repair per-policy Markdown table headers; one new regression
test plus 20 existing simulator tests passed. Combined focused tests: 37/37.

Full make check blocked twice in unchanged Godot import: thread propagation crash, then corrupted
cached autoload paths. S9 applies: no third attempt without owner disposition. Python format/lint,
YAML parsing (14 jobs), task lint and diff checks passed. Draft PR records unresolved escalation.
T-0235 merged status is reconciled to done within task scope.

## Owner-authorized recovery and final evidence

Owner authorized backing up generated worktree cache and retrying. Full make check then passed:
451 Godot, 311 pipeline, 488 tools tests. No game source or project configuration changed.
S9 is resolved. Cache backup: /private/tmp/wow-t0236-godot-cache-backup-1144886.

Actual economy job passed in run 38422629722. Downloaded economy-simulation artifact contains
base-only.json/base-only.md/default.json/default.md. Each JSON has three 300-level policies;
each Markdown has three complete tables. Downloaded JSON/Markdown match the local deterministic
model exactly. All four artifacts retained by CI for 14 days. Remaining review stays independent.
