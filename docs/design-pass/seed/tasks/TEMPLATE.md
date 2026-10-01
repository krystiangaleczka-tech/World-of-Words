---
id: T-NNNN
title: <short imperative title>
epic: ENN
type: feat            # contract | feat | fix | refactor | test | content | infra | spike | docs
area: <one area from ARCHITECTURE.md#areas>
risk: low             # low | medium | high (see rules below)
executor: cheap       # cheap | sol | human
status: draft         # draft | ready | in_progress | review | blocked | done
depends_on: []
touch:                # allowlist of globs; CI rejects changes outside it
  - <path/glob>
revision: 1
---

<!--
RISK RULES
high:   save format, economy, IAP, ads, consent, pipeline validators/export, contracts,
        project.godot, released content slots
medium: new logic in core/, player-visible behavior change, new analytics event
low:    UI from existing components, tests, mechanical refactor, small fixes

SIZE: < ~300 changed lines, <= ~5 production files, one area. Bigger → split.
Delete every optional section that would be empty. Quote the 1–3 rules that matter.
-->

## Goal
<1–3 sentences: what the player or system can do after this change, and why.>

## Context
- <DOC.md#anchor> — "<quoted rule that matters>"
- <max 5 references>

## Current state
<!-- Generated from tools/context_pack.py. The executor verifies all of this in preflight. -->
- `<path>`
  - `<class_name / signature / signal>`
- <what does NOT exist yet and will be created by this task>

## Specification
### Behavior
1. <testable statement>
2. ...

### Interface            <!-- only if an API or data shape is created/changed -->
```gdscript
## @api
<exact signatures>
```

### States               <!-- only if stateful -->
| State | Event | Next state | Side effects |
|---|---|---|---|

### Edge cases
| Case | Expected |
|---|---|

### UX                   <!-- only for UI tasks -->
- Components: <existing components only>
- Tokens: <Space.*, Motion.*, Palette.*, Type.*>
- Visual states: <...>
- Reference: <docs/design/... screenshot or mockup>

### Analytics            <!-- only if events are emitted -->
- <event_name { param: type }> (existing | add to game/data/analytics/<area>.json)

## Out of scope
- <tempting thing NOT to do>

## Tests
File: `<path>`
- `test_<name>`: given <concrete input>, when <action>, then <concrete expected output>.

## Acceptance
- All tests above exist and pass.
- Manual check for reviewer (UI only): <steps>

## Implementation notes   <!-- optional -->
- <suggested approach, pitfalls; never dictate line-by-line code>

## Rollback               <!-- risk: high only -->
- <why a squash revert is or is not enough; migration / config flag / content lock>

## Escalation log
<!-- rule id → question → answer (revision N) -->
