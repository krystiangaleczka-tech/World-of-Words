# Debug P2b — T-0329

Nine focused tests cover injected day/timezone/monotonic behavior, a real shop daily cap boundary, active overrides/buckets and defensive snapshots, bounded registered-event observation, full/failed/denied rejection, lifecycle cleanup and actual PL/EN controls without Save writes or queue draining.

Native evidence: 36 Compatibility captures across three layouts, PL/PSEUDO, default100/HC130 and top/clock/bottom scroll positions. Run with DISPLAY=:106 and pinned Godot: --path game --script ../docs/qa/T-0329/capture.gd.

The debug Clock is shared by normal boot services. Its Unix/calendar offset never changes monotonic time or the OS clock. Diagnostics use transient bounded memory; consent denial clears the log, and no common install/user identifiers are copied. Canonical config/event names remain verbatim under translated headings. SDK delivery remains controlled by the normal Analytics owner.

Both debug feature and service folders remain excluded from Release and checked in the actual exported archive. No balance defaults, save schema or analytic event registry changes.
