# Paid board tools

T-0336 extends the existing concrete AtomicProgressPort/Save owner protocol.
AtomicProgressPort.certifies_tools(save, progress, economy, content, config) verifies
the exact current owner pair plus P2 content/config/port bindings before UI activation. It is
not a new autoload and does not activate P2 in Boot/Nav.

`PaidToolPlan.after(board: BoardState, kind: StringName) -> BoardState` returns a
validated detached board after deterministic Hint or Reveal; null means invalid or
complete. Historical bonus credits are preserved. No mutation of the supplied board.

`Economy.tool_commands(kind: StringName, complete: bool = false) -> Array[Dictionary]`
proposes a single item-first spend, otherwise the canonical configured coin price.
An unaffordable spend produces no commands; completion rewards cannot finance it.
AtomicProgressPort.tool_commands exposes this port's exact bound Economy proposal.
A final reveal appends the existing level completion/onboarding grants.

`Progress.paid_tool_request(board: BoardState, kind: StringName,
commands: Array[Dictionary]) -> Dictionary` registers one candidate only for the
actual current bound board whose before snapshot matches durable Progress. It must
match content, language, lineage and unlock config. The caller transacts through
its already certified AtomicProgressPort. Reuse the exact returned request on retry.

The closed request retains all campaign fields and adds `tool: {kind, before, after}`.
`kind` is `paid_tool`. Identity is
`paid_tool:<language>:<slot>:<hint|reveal>:<SHA256 before snapshot>`; Save namespaces
receipts by lineage. The full request hash covers content, price, exact commands and
both snapshots. Conflicting reuse is rejected. Paid candidates cannot be approved
through a free UI mutation or a caller-supplied boolean.

Incomplete tools change only the current language's level_state and Economy debit;
slot/stars/delta remain unchanged. Final tools atomically include completion progress,
rewards and unlocks through the existing owners. No live board or debit-success
notification is published until the full candidate resolves durably. UI adopts the
candidate only after a matching receipt. Unresolved writes keep the global lease;
other owner writes and replacements return busy. A rejected pre-write lease is aborted.

The v4 eleven-field receipt layout is unchanged, with a newly validated operation
namespace. Existing v4 files need no migration. A rollback must retain this reader;
older builds are not supported downgrades once paid proofs exist. Receipts are never
trimmed with the bounded Economy journal. Explicit replay may reissue notifications
once in a new process; it never reapplies a debit or a reward.

The storage policy remains primary, then temp, then backup. A crash while primary
is valid may discard the unpromoted temp candidate: neither charge nor reveal survives.
After backup rotation the valid temp is promoted and the entire candidate survives.
These are filesystem checkpoint guarantees, not physical power-loss certification.

## Issued price stability (T-0337)
Before the first storage attempt, both owners still compare current authorization
context. Once Save.transaction_started(transaction) is true for the current valid
lease, Economy's registered immutable payload retains its original price, rewards
and journal limit. A remote price change cannot strand that pending operation or
reprice a retry. Subsequent distinct operations use the new configuration. This
never authorizes a forged/different approval, hash, request, board or owner.

## Explicit Level caller (T-0278)
LevelScreen.configure_paid_tools(progress, port, monetization=null, ios=false) must
follow configure_p2 and precede mounting, with the exact certified owner pair,
content, price configuration and current slot. Default Boot/Nav remain P1; simply
showing P2 controls does not activate payment. A foreign provider is rejected by
Monetization.matches_tool_owners. Provider-less fallback remains explicit/offline.

LevelController.use_paid_tool keeps its exact request on an unresolved write and
adopts the validated after board only after a matching issued Save receipt. The
local paid_tool_committed signal carries newly revealed cells for presentation.
An input/feedback lock rejects rapid/reentrant calls and free hint/word bypasses.
Ordinary word submissions continue through their existing Progress path and retain
BoardView geometry. A retained screen preserves its bound pending board and retry
across exit/reentry; prepare_navigation returns busy until resolution. A caller
must respect that result: forced screen destruction while ignoring it is unsupported.
A whole process restart uses the file selection policy described above.

Unaffordable operations open an existing ShopSheet with alternative catalog controls.
Get coins replaces content within the same Sheet with the real owner-backed catalog
or an explanatory offline StatePanel. An ad explicitly grants configured Hint items
through the existing Economy.grant reward callback; it does not automatically use
a Hint or Reveal. Pending reward writes retry without another ad and block dismissal.
Success uses a catalog Toast and HintButton count pop: RewardBurst currently has no
Hint-item variant, so this flow does not invent a new component state or coin reward.
Payment-specific analytics integration remains T-0275; no P1 payment is fabricated.
