# T-0231 pure economy implementation

EconomyLedger owns an isolated wallet and global bonus counter. Reasoned grant/spend delegates
atomic immutable arithmetic; malformed/insufficient/overflow requests never partially mutate.
Configured prices/rewards use RewardTable; doubling is level-only. A configured zero reward is
a no-op. No service, save, event, analytics, config registry or running-screen behavior changes.

Eligible bonus credits accumulate only; add_bonus never pays. Explicit redeem_bonus_chests is for
future level-complete integration and uses exact integer quotient/remainder. Multiple pending
chests use injected reward value; surplus survives serialized reload. Duplicate settlement with
no new credits pays nothing. Multiplication/wallet overflow leaves both wallet and counter intact,
so callers can retry after space becomes available. Zero configured payout still consumes chests.

Core does not identify words or durable intents: BoardState/service later supplies unique eligible
credits, unlock state and level-complete boundary. Service T-0232/T-0233 owns bounded journal,
analytics and atomic persistence; snapshot contains only wallet/bonus fields and must be merged
with service-owned journal/extensions. Unknown inventory items reject rather than disappear.
This task does not claim app-kill retry or purchase durability beyond in-memory atomic arithmetic.

Seven deterministic tests cover factory JSON/config validation and deep isolation, reasoned mixed
operations, configured prices/rewards, unlock/no-midlevel/multichest/carry-over/repeated settle,
retry-preserved credit under counter/multiplication/wallet overflow, exact large integer division,
zero payouts and safe unconfigured calls. Pinned4.7.2 GUT438/438, full make check, task/scope lint,
fresh exact-head independent reviewer/checklist and13CI required before sequential squash merge.
