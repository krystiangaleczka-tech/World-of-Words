---
id: T-0171
title: Safely handle destroyed audio settings owner
epic: E08
type: fix
area: services.audio
risk: med
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0170]
touch:
  - game/services/audio.gd
  - game/tests/integration/test_audio_owner_lifetime.gd
  - game/tests/integration/test_audio_owner_lifetime.gd.uid
  - tasks/T-0171-audio-owner-lifetime.md
revision: 1
---

## Goal
Safely handle destroyed audio settings owner. Owner requested another five pre-P2 technical tasks.

## Context
AGENTS.md requires owned signal cleanup and injected services; T-0165 diagnostics exclude background observations. Original Astra P2 ownership requirements and human gates remain separate.

## Current state
Audio exposes configure(save: SAVE_SCRIPT, sink: Callable = Callable()), play(cue: StringName) -> bool, load_cues(path: String = REGISTRY) -> Error. configure/_volume/_disconnect_settings access _save after null checks.

## Specification
Implement T-0170 Audio settings section, changing only configure, _volume, _disconnect_settings guards. Preserve signatures, cue/voice/settings semantics and hot-path allocation behavior.

## Tests
In-memory loaded Save with injected clock and audio sink: freed Save makes play false without sink call/errors; replacement after owner free restores play and preference updates; configure(null) safe after free; audio teardown safe after Save destruction, real loaded voices remain bounded. No sleeps/native calls.

## Acceptance
All specified behavior/tests; full make check, scope/count, fresh independent review and final-head green CI before sequential squash merge. No human/phase approval inferred.
