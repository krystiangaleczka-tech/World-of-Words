# T-0241 Progress P2 contract

## Boundary

Progress keeps the existing P1 implementation and exposes typed, unavailable P2 reads and
configuration. Even an available injected port cannot activate this contract-only surface.
ProgressCommitPort is an inert protocol placeholder with independent unavailable responses.
No boot wiring, persistence, Economy call, migration, config value or Events schema is changed.

## Required activation evidence

The task specifies committed versus pending views, stable operation identity, joint owner-validated
Save candidates, durable replay proof beyond journal trimming, stale-context rejection, restart
recovery and notification-independent correctness. The current Save/Economy APIs cannot certify
this protocol. A separately scoped owner preparation/atomic commit capability and verified legacy
adaptation policy are required before T-0242 can activate it. Existing global stars are not silently
allocated to locations and historical grants are not manufactured by reads.

## Verification

New integration tests cover unavailable default and injected APIs, copy isolation, no request
mutation, rejection of apparent capability, unchanged P1 current/highest slots and injected Clock,
no dependency calls or Save writes and no Progress/Events signals. Existing P1 persistence tests
remain unchanged and run in the full check. Production crash/replay/migration evidence belongs to
the later real coordinator implementation; these stubs do not claim it.

Full local `make check`: PASS (472 Godot, 329 pipeline, 488 tools tests).
