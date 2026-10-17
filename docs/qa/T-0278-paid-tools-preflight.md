# T-0278 paid tools preflight

Main 14c0895 includes all four original dependencies. Existing AtomicRequest,
AtomicSave assembly and concrete Progress/Economy preparation only support campaign
completion. A standalone spend followed by Progress.save_level is unsafe: a crash
between writes charges without reveal, or reveals without charge. Dirty Save flush
is not a substitute for the closed candidate/proof protocol.

T-0336 extends that existing protocol with paid_tool requests, detached board plans,
item-first canonical Economy authorization and stable before-board identity. Final
reveals include the existing completion batch. Existing v4 receipt fields remain;
new operation namespaces require retaining the extended reader after activation.

T-0278 revision 2 will bind this capability explicitly, keep the P2 HUD inert without
it, serialize animation/input and add catalog Sheet alternatives with real provider
readiness. Native/store/device and FUN release gates remain open.
