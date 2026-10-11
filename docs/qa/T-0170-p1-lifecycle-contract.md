# T-0170 — P1 lifecycle correction wave

Owner requested another five pre-P2 technical tasks. No new commits or ready tasks
follow T-0169. Source inspection originally suggested four lifecycle defects; address
these with regressions, not speculative P2 ownership/economy changes. The original four-defect claim
was corrected by the runtime evidence below; two defects remain confirmed.

## Correction authorized by the owner
T-0170's original source-only assessment incorrectly described null guards as
unsafe for freed Nodes. Exact Godot4.7.2 runtime independently confirms freed
Node==null true, is_instance_valid false. Three new Audio tests/53assertions also
pass on unchanged main. The guard rewrite was discarded, PR109 closed without
merge. Owner approved the concrete corrected wave with "Rob" (Polish: "Rób").
T-0171 revision2 corrects this plan and future scopes; T-0172 adds regression
coverage for behavior already implemented. Only T-0173 and T-0174 repair defects.
Original Astra findings and human gates are unchanged.

## T-0172 — Existing Audio/Haptics owner-lifetime safety
Do not rewrite either production service. Test existing Audio.configure/play and
HapticsListener.configure behavior with null, freed and replaced owners; tree
reentry/teardown, live preferences, current adapter selection, no duplicate
connections and bounded prepared voices. Memory storage and injected clocks;
no disk/native calls/sleeps. Tests assert public effects and signal connections.
Coverage protects against future missing-guard or stale-subscription regressions;
baseline passing is expected and does not demonstrate a new production fix.

## T-0173 — Debug button must use the screen's navigation owner
`LevelScreen.configure_navigation(nav)` supplies its owner; `_on_continue` uses it,
but `_on_debug` always calls global Nav. Route debug through the supplied owner,
or existing Nav when unconfigured/explicitly configured with null. Track
`_navigation_supplied: bool=false`; configure_navigation sets it from
is_instance_valid(nav). Choose the owner by that flag, then check target validity.
A formerly live supplied owner comparing equal to null after destruction must
NOT cause a fallback to global Nav.
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
Fresh main per branch; one active task/PR/squash (discarded blocked draft retained as history). Full make check, fresh independent review
and final-head12job CI per task. New tests exercise public effects/signals; no
existing tests changed. Source-level findings are not phone observations. Original
Astra report, pending reference-device tests, per-word reviews, five-outsider tests
and FUN GATE remain untouched. No P2 phase start, secrets or project/export edits.
