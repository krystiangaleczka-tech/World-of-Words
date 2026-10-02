## Task
T-NNNN (revision N) — tasks/T-NNNN-slug.md

## Summary
<What changed, in 2–4 bullet points.>

## Deviations / concerns
None
<!-- Anything that differs from the task, or doubts about the task. Anything other than "None" triggers a Sol review. -->

## Escalations
None
<!-- STOP rule id, question, answer received. -->

## Test evidence
```
<tail of `make check` output>
```

## Screenshots
<!-- UI tasks: per DESIGN.md#pr-screenshot-rules. Gallery screenshots come from the CI artifact once it exists (T-0327); device screenshots are Chris's. Compare with the referenced mockup. -->

## Checklist
- [ ] Only files from `touch` changed (plus the task status)
- [ ] Every test from the task exists and fails if the implementation is reverted
- [ ] No new autoloads, dependencies, magic numbers, or unregistered analytics events
- [ ] UI tasks: catalog components and tokens only; strings are translation keys with no plural-dependent sentences
- [ ] Rebased on current `main`; conflicts: none / mechanical (described) / re-implemented
