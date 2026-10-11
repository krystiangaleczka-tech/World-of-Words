# T-0170 — P1 lifecycle correction wave

Owner requested another five pre-P2 technical tasks. No new commits or ready tasks
follow T-0169. Source inspection identifies four bounded lifecycle defects; fix
these with regressions, not speculative P2 ownership/economy changes.

## T-0171 — Audio settings owner can be destroyed first
`audio.gd` tests `_save != null` before `is_loaded` and signal access. A freed Node
reference is not a live service. Guard configure/volume/disconnect with
is_instance_valid. A missing/freed settings owner makes play return false without
sink calls; configure(null) and replacement after old owner destruction work.
Existing live preference/retry/cue/voice behavior and signatures stay unchanged.
No new lifetime ownership, data/save changes, allocations, stop-on-destruction API,
registry edits or platform operations. Sound already playing is not forcibly
stopped by a new destruction watcher; subsequent calls are safely unavailable.

## T-0172 — Haptics dependencies can be destroyed first
`haptics_listener.gd` uses null tests before event/settings/platform access.
Guard event connect/disconnect and settings/platform checks with is_instance_valid.
Destroyed dependencies make effects silent and teardown/reconfiguration safe.
Rebinding live services reconnects exactly once, old emitters are detached;
preference and current-adapter selection stay unchanged. Existing RefCounted
adapter null checks remain. No new service, subscriptions or native SDK changes.

## T-0173 — Debug button must use the screen's navigation owner
`LevelScreen.configure_navigation(nav)` supplies its owner; `_on_continue` uses it,
but `_on_debug` always calls global Nav. Route debug through the supplied owner,
or existing Nav when `_navigation` is null (unconfigured/null retains prior behavior).
A destroyed owner or one without go_debug safely does nothing, without rerouting
to the global service. Keep OS debug gate; continue behavior/API/copy/geometry and
release visibility unchanged. Existing IconButton only; no new player UI.

## T-0174 — Pause and focus notifications overlap
Overlay currently maps each RESUMED/FOCUS_IN directly to active=true, so focus-in
can resume probes while application remains paused (or resume while focus is lost).
Track `_application_paused=false` and `_application_focused=true`. Notification
handlers update one flag and call existing set_foreground(!paused && focused).
Duplicate and mixed-order notifications preserve active histories until both flags
permit observation. Direct set_foreground(bool) remains the explicit test/owner
window switch; it does not synthesize platform notifications or change flags.
Keep T-0165 snapshot/log schema and gameplay/wheel behavior unchanged. No input or
frame allocations. Locale notification still refreshes. Real injected-clock tests
must cover both pause→focus-in→resume and focus-out→resume→focus-in orders, duplicate
notifications, no background samples, correct close-once/resume anchor and cleanup.

## Review boundaries
Fresh main per branch; one task/PR/squash. Full make check, fresh independent review
and final-head12job CI per task. New tests exercise public effects/signals; no
existing tests changed. Source-level findings are not phone observations. Original
Astra report, pending reference-device tests, per-word reviews, five-outsider tests
and FUN GATE remain untouched. No P2 phase start, secrets or project/export edits.
