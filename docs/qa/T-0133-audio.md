# T-0133 — P1 named placeholder audio

Six DESIGN cue names use original generated mono PCM16 samples, dedicated to
CC0-1.0 with generator/provenance in the repository. No external recording or
final sound direction is claimed. The sound registry declares cue files, gain,
fixed pitch and a bounded eight-voice pool; streams/voices load explicitly at boot.
The play path reads preloaded data and allocates no nodes or file buffers.

Audio applies the live saved sfx_volume. Zero rejects requests and stops active
voices; nonzero changes immediately adjust active gain. Reconfiguring ownership
releases the old settings connection. Unknown/unready cues fail softly. Invalid
reload, including missing resources after a partially successful preload, preserves
the old complete registry/voice pool. Tests inject a sink for accepted requests
and also inspect real AudioStreamPlayer gain, streams and bounded voice behavior.

Existing registry CI now checks the audio schema, PCM files and literal Audio.play
names. Config/analytics-only fixture workspaces remain supported; partial audio
schema/data/asset sets fail. Tests also reproduce every WAV from the generator.

No events are wired in this task: T-0144 maps gameplay side effects to Audio.play.
No save/economy/analytics schema or new autoload changes. No speaker/device
assessment is fabricated; audible comfort is part of Chris's Android QA.
The existing explicit prototype continuation uses technical dependencies, leaving
T-0051's unperformed human phase exit open.

Validation: full make check passed (210 GUT / 8,359 assertions; 199 pipeline
and 87 tools tests), including registry and 65-level content checks.
Fresh independent review approved implementation c8d76351c67c73b771f49df9c06e49c39de30201 with no blockers.
