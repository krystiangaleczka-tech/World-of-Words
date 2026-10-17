# Durable teaching state (T-0290)

Save owns the existing meta.onboarding_step and meta.coach_marks_seen fields.
No additional section, field, migration, autoload, balance rule or boot activation.
The pure immutable OnboardingState value reads/copies {step,seen}, preserves unknown
historical flags and higher historical steps, and never decreases either domain.
A completed tutorial is step>=1. Coach flags remain independent, so a higher step
never hides an unpresented lower-step coach.

Stable action IDs for the existing onboarding_step {step:int} analytics registry:

| Action | step |
| --- | --- |
| first accepted player-solved tutorial word | 1 |
| shuffle coach | 2 |
| bonus coach | 3 |
| hint coach | 4 |
| journey coach | 5 |
| reveal coach | 6 |

Stored step is the maximum historical action ID. Event step is the newly recorded
action ID, including an out-of-order lower-step coach. No legacy history is guessed
or replayed as a new event; unknown flags survive. Tutorial completion is required
before claiming a coach. No automatic backfill from campaign progression.

## Save-owned commands

Explicit configure_onboarding(events:Node)->Error binds an actual Events instance
after Save.load. It performs no write/event and cannot replace a pending or active
binding. Default Save/boot stays unchanged. Public commands:

- onboarding_snapshot()->Dictionary: independent committed {step,seen}; unloaded {}.
- complete_tutorial()->Error: monotonic first-word teaching completion.
- mark_coach_seen(feature:StringName)->Error: closed shuffle/bonus/hint/journey/reveal.
- retry_onboarding()->Error: same pending action, or ERR_DOES_NOT_EXIST when absent.

Calls returning OK certify durable state; duplicates are no-op without a write or
notification. I/O failure leaves the same action pending and its metadata dirty,
while snapshots retain the previous committed state. Another action/binding is
ERR_BUSY until exact retry or an unrelated successful Save.flush commits it. The
candidate merges only these two meta fields and keeps unrelated owner changes.
The existing Save full-document transaction writes metadata together; active atomic
leases reject staging. Reentrant onboarding commands, including flush/error callbacks,
are busy. During Events.onboarding_step publication all Save writers share a busy
barrier. Observers see committed state; the pending identity clears before emission.

An actual matching commit emits Events.onboarding_step(step:int) once per new
teaching/coach action. Analytics transmission is a future T-0328 listener concern,
with the existing event registry and consent owner; events never authorize gameplay.
Process restart reads durable history and emits no invented historical notification.
This is not an exactly-once durable telemetry outbox: a crash after persistence can
lose the transient side effect, while once-only teaching state remains safe.

## Tutorial integration boundary (T-0291)

Only an accepted player-solved LEVEL or BONUS result, after the corresponding real
Progress checkpoint/completion succeeds, authorizes complete_tutorial. Hints/debug
reveals, invalid, canceled, ignored or repeated attempts do not qualify. Integration
must freeze the accepted source before presentation callbacks can reenter.
Touch hides TutorialHand only for the current presentation; it does not persist a
finished lesson. The caption remains until the first accepted word. If its later
metadata write fails, hide the already accepted teaching presentation for that live
screen and explicitly retry the same pending action; never invent a durable result.
On reopening, committed teaching state and restored player-found words must both be
examined; do not infer a player solve from hint-revealed cells. The integration task
must specify/test the exact restored-board reconciliation before activation.

## CoachMark presentation protocol (T-0292)

No CoachMark component, overlay, scrim or scene is introduced in this contract.
The future caller-owned presenter API is show(feature:StringName,target:Control,
caption:Label)->Error, dismiss()->void and active_feature()->StringName. The supplied
inline Caption uses onboarding.coach.<feature>; the existing visible eligible
catalog target uses its highlighted state. Validate target/caption and eligibility
before claiming Save.mark_coach_seen; persist successfully before showing. A failed
write shows nothing, keeps the exact request pending and requires explicit retry.
Persist-before-display provides at-most-once presentation authorization; a crash in
the small commit-to-paint interval may skip a coach rather than display it twice.

One active coach at a time. Queue eligibility while consent, another coach, a modal,
or completion feedback is active; showing is exempt from automatic prompt budget.
Any tap anywhere or timeout Tokens.Motion.TOAST_HOLD*2 dismisses it without marking
input handled or blocking the wheel; no button is forced. Dismissal clears only the
presenter's own highlight/caption/timer, never a foreign animation. Exit cancels
owned work and disconnects; retained entry cannot replay a committed coach.
T-0292 implements presentation and tests the actual input path; T-0290 adds no UI.
