# Offline curator review packet contract

T-0155..T-0159 provide a source-backed catalog, required-word report and opt-in
readiness check. Chris requested five further tasks. T-0160..T-0164 make those
outputs usable for actual word review, before the still-open human FUN GATE.

The wave creates a standalone Polish HTML review of all 65 committed levels,
a draft CSV worksheet, a read-only candidate comparison and one module CLI.
It does not implement P2, create vocabulary decisions, change game visuals,
assign runtime difficulty or alter optional bonus eligibility.

## Frozen boundaries

- All actual packets are based on build_report, which first performs existing
  p1.check replay. HTML maps that report to manifest-listed committed geometry,
  preserving wheel tile multiplicity, intersections and required answer order.
- HTML is deterministic, responsive and self-contained: inline CSS, native
  links/details, escaped text, no JavaScript, external resources or network.
  Visible proposal/unknown/missing labels prevent a preview implying approval.
  It is a curator QA page, not a mockup of final game design.
- CSV uses the existing word,band,status,reviewer,rationale contract. It retains
  existing judgments, sorting unique required forms. Missing annotations become
  explicitly unassigned proposals with no band. Nothing becomes reviewed merely
  by export, file validation, a device test or successful CI.
- The curator edits exact per-word judgments and attribution in a separate draft.
  Read-only comparison validates native source membership, exact required-word
  coverage, records changed annotations and shows the optional early verdict.
  Hash receipts identify inspected bytes; they cannot authenticate reviewer identity.
- Comparison JSON: schema_version 1; inputs baseline_sha256, candidate_sha256,
  tiers_sha256 and packs; candidate coverage missing/proposed/reviewed; changes
  ordered by Unicode word, each {word,before,after}; before/after contain the
  five WordReview fields. Missing before keeps the report's missing annotation.
  early_check has slots 15, max_band 2 and ordered issues from early_issues.
- The CLI emits HTML, CSV or canonical comparison JSON to stdout. Explicit
  shell redirection creates a local artifact; the tool itself never writes.
  A valid report returns 0 even with unresolved judgments. Early acceptance is
  its explicit verdict, not the generic command exit. Invalid data returns 1;
  malformed command syntax keeps argparse's normal error behavior.

The current packet must still show 103 Codex proposals and 24 early unresolved
answers. No automatic importer or overwrite command is provided. Applying actual
curator decisions to the committed catalog will need a separately scoped content
change and review. Native tiers, packs, provenance, save formats and runtime
remain unchanged; no new dependency, existing build integration or phase approval.

## Five tasks and verification

T-0160 freezes these interfaces, scope and tests. T-0161 renders faithful grids
and escaped annotations; T-0162 exports editable drafts without inferred review;
T-0163 validates and compares candidate decisions; T-0164 exposes commands,
usage and locally generated user-preview artifacts. Each implementation has
focused behavior tests, full engineering checks and a fresh independent review;
all final-head CI jobs must pass before each sequential squash merge.
