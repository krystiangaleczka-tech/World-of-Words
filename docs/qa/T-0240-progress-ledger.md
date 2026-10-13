# T-0240 Pure progress ledger

One unused core class plans sequential per-language progress independently of Save/Events/UI.
Factory validates canonical primitive metadata and deserializes copied state, preserving retired
credits. Completed slots advance once; each gains the injected fixed star, local stars and ordered
piece credits. Short locations fill remaining postcard pieces at their endpoint. Region/feature
availability follows current-slot boundaries.

Seven unit tests cover exact five-slot progression across two regions/three locations, duplicate/
stale/skip/end/reload, threshold/cap/multi-piece behavior, retired credits, snapshot/result/input
isolation, overflow, invalid metadata and legacy queries with no retrospective star/card grants.
Full make check: 469 Godot, 329 pipeline, 488 tools tests passed. Task/scope checks validated.

No Save adapter, legacy policy, economic reward, gameplay caller or durable operation identity is
implemented here. T-0241/T-0242 must define domain field adaptation and commit candidates before
publishing any success. Asset capacity remains Content/owner responsibility; pure pieces use Config.
First-class domain logic is one production file; tests exceed approximate line budget.
Fresh independent review and final CI remain required before merge.
