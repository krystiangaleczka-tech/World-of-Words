# T-0233 Durable Economy service

Preflight confirmed merged typed stubs, Save's synchronous candidate/flush API and inherited
Clock. Config has no loaded accessor: readiness checks the required journal key instead.

Transactions preserve bonus_counter, extensions and opaque legacy journal entries. Failed
flushes expose the before state and retain one candidate; identical retries flush/publish it
once, including after another owner flushes. Conflicting economy replacement is never overwritten.
Mutation/publication reentrancy is rejected. No boot wiring or gameplay rewards are activated.
Restart reads complete Save documents. The diagnostic journal is not an idempotency key; future
paid/completion callers must implement durable identity and joint operation protocols.

Validation: seven new integration tests, 449/449 Godot tests, 311 pipeline and 451 tools tests;
full make check OK. Tests use fixed Clock, injected failures, a private real-storage path and
restart/reload. Existing contract tests remain unchanged. Scope and metadata validated.

The task exceeds the approximate line budget because persistence-failure and recovery tests
are retained; only one production service changes. Independent review and CI remain required.
