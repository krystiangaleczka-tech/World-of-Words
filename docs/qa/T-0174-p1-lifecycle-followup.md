# T-0174 — P1 lifecycle follow-up

## Corrected scope
The approved T-0170–T-0174 wave repairs two confirmed defects: LevelScreen debug routing (T-0173) and overlapping pause/focus notifications (T-0174). T-0171 revision 2 corrects the initial assessment; T-0172 protects existing Audio/Haptics lifetime behavior with regression coverage and changes no production services.

The original source-only claim that freed Nodes evade null guards was incorrect. Exact Godot 4.7.2 runtime confirms freed Node == null is true and is_instance_valid is false. Three Audio tests / 53 assertions passed the unchanged baseline. The unproven guard rewrite in PR #109 was closed without merge. The owner approved the concrete corrected wave. The original Astra report remains unchanged.

## Implemented behavior
Debug uses the current injected navigation owner. Unconfigured or explicitly null ownership preserves global fallback; destroyed or incapable supplied owners do not reroute globally.

Performance diagnostics track application pause and focus independently. Observation resumes only when both permit it, regardless of notification order. Duplicate notifications preserve pending input and frame history. Direct set_foreground remains an explicit window override and does not rewrite platform state. Snapshot/log schema, translations, gameplay and wheel behavior remain unchanged.

## Deterministic evidence
Godot 4.7.2, real scenes/services and memory storage, injected clocks, public signals/notifications, forced draws; no sleeps, real-clock assertions or private-state inspection.

- T-0172: seven lifetime tests / 76 assertions pass. Removing event disconnection in an isolated copy fails one test / five assertions. Existing lifetime safety is coverage, not a newly fixed defect.
- T-0173: three routing tests / 24 assertions pass. Reverting routing in an isolated copy fails two tests / seven assertions. Full checks passed: 270 GUT tests / 13,271 assertions, 311 pipeline tests, 183 tools tests, 65 levels; fresh independent review approved; PR #112 final-head CI passed all 12 jobs before squash merge.
- T-0174: five tests / 61 assertions pass. Reverting only overlay implementation in an isolated copy fails four tests / 17 assertions without script errors. Tests cover both mixed notification orders, one close per transition, no background samples/history, resumed first-frame anchors, duplicate pending/history preservation, stable emitted records, explicit override and callback disconnection. Full-check/review/final-head CI receipts are recorded in the task outcome and PR before merge.

## Remaining owner evidence
These are desktop deterministic checks, not phone observations or acceptance measurements. Galaxy A15 reference-device checks, per-word review, five-outsider sessions and FUN GATE remain pending unless separately documented by the owner. Previous S26 Ultra approval does not supply those observations. No P2 phase gate is inferred. T-0150 remains owner-local; Android signing secrets are not configured by this wave. Follow T-0169 capture instructions for device performance evidence.
