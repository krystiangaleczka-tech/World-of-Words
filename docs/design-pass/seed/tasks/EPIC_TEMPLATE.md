---
id: ENN
title: <epic title>
phase: 1              # 0 | 1 | 2 | 3
status: planning      # planning | active | done
---

## Goal
<What changes for the player or for the production system when this epic is done.>

## Player-facing outcome
<What a player sees/does. "None" for internal epics.>

## Decisions
<!-- Every decision a task would otherwise have to make. Link docs/decisions/NNNN-*.md for big ones. -->
- D1: <decision> — because <reason>
- D2: ...

## Contracts
<!-- APIs, signals, data shapes and config keys that tasks build against. Created first, in a `contract` task. -->
```gdscript
## @api
<signatures>
```
- Config keys: `<area>.<key>` (type, default, range)
- Analytics events: `<name> { params }`

## Waves
<!-- Titles + dependencies only. Detailed task files are written one wave at a time on fresh main. -->
### Wave 1
- T-____ contract: <title>
- T-____ <title> (depends: contract)
### Wave 2 (written after wave 1 merges)
- <title>

## Open questions
<!-- Must be empty for the scope of a wave before that wave's tasks are written. -->
- Q1: <question> — owner: <Chris | Sol | Opus>

## Exit criteria
- <observable, checkable outcome>
