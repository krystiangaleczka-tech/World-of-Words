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
