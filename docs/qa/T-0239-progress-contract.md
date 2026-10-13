# T-0239 Pure progress contract

Two unused RefCounted values define immutable domain state and injected fixed-one-star rules.
Counts canonicalize integral JSON values; IDs/credits preserve retired records. Piece thresholds
use exact integer division and never remove credits. Unlocks retain prior IDs across changed config.

Domain-only location_stars/completed_locations are not new Save fields. T-0241/T-0242 must specify
legacy adaptation, persistence and transaction identity before integrating the mutable T-0240 owner.
No runtime, economy, Save, content or Config changes.

Six new GUT tests cover factory/config validation, copy isolation, safe-range/cross-field rejection,
exact large division, thresholds/full completion, monotonic credits/unlocks and region/location gates.
Full make check passed: 461 Godot, 329 pipeline and 488 tools tests. Scope/task lint validated.
Two production classes; tests increase approximate line budget. Fresh review/CI required before merge.
