# Startup recovery — T-0295

Twelve integration tests use actual Save/Config/Content/Nav with isolated memory Save and mutable copies of the shipped three-level fixture. Cases cover missing/corrupt content, inline Home retry, first-Level backup Toast, wholly lost/fresh saves, real modal focus trap, failed Continue flush, restore initiation, deferred/coalesced canonical telemetry and PL/EN status.

Native evidence: 60 Compatibility captures (three layouts × PL/PSEUDO × default100/HC130 × content error/Home error/lost save/restore unavailable/restore requested). Reproduce with DISPLAY=:106 and pinned Godot: --path game --script ../docs/qa/T-0295/capture.gd.

The error controls use StatePanel and TextButton; lost-save uses the existing non-dismissible Sheet to trap input/focus. Restore reports initiation only; actual native SDK setup remains separately gated. Save acknowledgement is transient within the presenter because Save.load is idempotent for the same instance and preserves its boot report; the ordinary persisted fresh Save prevents a panel on next process startup.

Content failure telemetry is best effort after a successful retry using the normal Analytics owner. Unrecovered processes cannot report; no exception text or file path is included. No global offline banner, automatic retry loop, save schema or balance change.
