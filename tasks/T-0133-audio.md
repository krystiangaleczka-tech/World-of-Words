---
id: T-0133
title: Load named P1 sound cues and respect the live sound setting
epic: E09
type: feat
area: services.audio
risk: low
executor: cheap
think: low
ui: none
status: done
depends_on: [T-0034, T-0039, T-0132]
touch:
 - game/services/audio.gd
 - game/services/audio/**
 - game/data/audio/cues.json
 - game/assets/audio/p1/**
 - game/services/nav/boot.gd
 - game/tests/integration/test_audio.gd*
 - tools/generate_placeholder_audio.py
 - tools/check_registries.py
 - tools/tests/test_audio_registry.py
 - docs/qa/T-0133-audio.md
 - tasks/T-0133-audio.md
revision: 1
---

## Goal
Provide Audio.play(cue) with named, source-attributed CC0 placeholder sounds for
P1; loading and settings never control game logic. T-0144 owns event wiring.

## Current state
Audio is the existing ServiceStub autoload; initialize/get_clock exist. Save has
load/get_setting/setting_changed and sfx_volume in [0,1]. Boot owns locale/haptics
and Nav.start loads Save. tools/check_registries validates config/analytics only.
No audio registry, streams or playback implementation exists.
The human T-0051 phase exit is unperformed; this explicit next-five request
continues the authorized prototype using actual delivered prerequisites, as
T-0120/T-0132 do. ROADMAP and human gates are unchanged.

## Specification
1. Add cues.json and its schema: version1, bounded max_voices, named cues containing
   files (one P1 sample), volume_db and fixed pitch_scale. Use DESIGN cue names:
   tile_touch,word_valid,word_bonus,word_already,word_invalid,level_complete.
   Generate six deterministic original PCM WAV placeholders using stdlib; dedicate
   the recordings to CC0-1.0 and retain provenance/generator. No external downloads.
2. Audio.configure(save, sink=Callable()) replaces settings ownership safely;
   Audio.load_cues(path=...) validates all entries and preloads AudioStreams before
   replacing active data. Invalid input preserves the old loaded registry. No I/O
   or node allocation in play(). Precreate a bounded rotating voice pool at load.
3. Audio.play(cue:StringName)->bool rejects unknown/unloaded/unconfigured/muted
   requests, applies cue gain times the live saved sfx_volume, and plays at declared
   pitch. Optional injected sink(cue,linear_gain,pitch) tests requests without
   speakers. Setting changes update active voice gain immediately; zero stops
   voices. Disconnect old settings on reconfiguration and exit. No music yet.
4. Explicit boot configures/loads Audio before Nav.start; loading failure is
   diagnostic and leaves gameplay usable. No new autoload/project edits. No event
   wiring here; no Save writes, balance changes, new analytics or random pitch.
5. Extend registry CI checks with audio schema/asset validation and unknown literal
   Audio.play calls. Existing config/analytics-only synthetic roots remain supported
   when both audio schema/data are absent. Actual partial/missing audio fails.

## Tests
New GUT audio tests: six imported streams/requests, gain/pitch/volume0, unknown cue,
setting changes and replacement ownership, invalid reload preserving old data and
real bounded players. New tools tests: shipped schema/WAV/CC0/generator bytes,
malformed fields/assets/partial registry and unknown literal Audio.play rejection.
Full make check, scope/task lint, fresh review and all CI. No audible/device claim.

## Acceptance
Source-attributed deterministic placeholder WAVs import; all required checks pass.

## Rollback
Revert service/registry/assets/boot initialization together; old stub remains
compatible with the unchanged autoload contract.
