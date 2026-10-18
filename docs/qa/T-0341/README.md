# T-0341 — authoritative restore results

Preflight: fresh main 0998d7a. Merged IapFlow already observes authoritative restore
batches for analytics, but no application-facing restore result existed. Generic
purchase errors could not safely identify a restore error. Phase-2 rolling-wave
planning extracts this T-0288 prerequisite as a bounded contract task.

## Verification

16 focused GUT tests / 196 assertions passed without leaks or engine errors. Tests
use real Save/Economy/Monetization and controlled IapFake, including actual failed
file-write checkpoints and committed proof checks before acknowledgement.

Coverage: unavailable/idle copied snapshots; accepted versus success; duplicate
command/rebinding barriers; empty, owned and duplicate-key batch counts; malformed
and consumable batch rejection; durable-write retry without another provider call;
existing unfinished recovery; explicit failure versus unrelated purchase error;
provider timeout, late receipt settlement and late-result suppression; duplicate
outcomes; notification reentry; Fake generation suppression; real Timer signal
wiring, timeout duration, ALWAYS processing and time-scale independence. Timeout
from inside the requested notification prevents obsolete provider dispatch.

Full make check, fresh independent review and exact-head CI evidence are recorded
in the PR before merge. No UI changes or screenshot claim.

## Boundaries

No save schema, economy grant, analytics schema, product IDs, SDK, boot, endpoint,
permission or signing change. The service facade's explicit restore methods take
its public method count past the generic lint cap, so only max-public-methods is
locally disabled; other lint rules remain active.

Provider adapters must implement current-operation terminal suppression for real
store results. Settings row binding and physical/native restore certification
remain open. A terminal batch awaiting durable proof is settling, not completed;
its provider timer is stopped and the caller offers explicit settlement recovery.
