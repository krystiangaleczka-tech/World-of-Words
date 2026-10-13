# T-0224 motion A

Passive MAX_TILES ghost pool is created on enter, attached for flight only and freed on exit.
Canvas-global origin, ordered letters, BASE/IN_OUT and stagger reach unique grid targets, with
nominal glyph-size scaling. Logical fill is immediate; landing FAST1.1 pop and BASE1.25brightness
flash include whole-word intersections. Replays/refresh/resize/exit settle all owned cells and
kill old timers. Live reduction removes movement without allocating new effect objects; initial
reduction uses owned FAST in-place fades. No gameplay, persistence or controller side effects.

Completion waits for word effects then diagonal wave. The full last-word→layer sequence uses
CELEBRATE budget, uniformly speeding pre-layer stages only when necessary; one STAGGER reserves
native layout time. Layer starts after native body sorting, retargets internal minimum-size reflow,
and settles on viewport/class resize or exit. SLOW fade/48slide; resume/reduction direct. Existing
completion/debug persistence and visibility assertions retained, deterministic cosmetic settling
added before final layer checks. Audio letter_land is absent from current registry; no invented cue.

Pinned4.7.2 full make check and8new tests (412GUT) cover atomic flight, actual ghost movement/stagger,
peaks, full budget/exactly-once, whole lifecycle, standalone wave resize cancellation and layer
resize/exit. Native12 Compatibility/llvmpipe captures in ignored builds/T-0224-preview use actual
fixture LevelScreen,3classes xdefault100/HC130 xnormal/reduced mid-flight. Independent exact-head
review and13CI required before merge. Physical devices/readers/taste/Opus remain open.

Native captures certify motion only: P1 debug/action HUD composition is still provisional and
contains baseline narrow-button wrapping; final screen composition belongs to T-0276. No claim
that the entire level screen is visually finished. Exit-before-native-sort gap also restores alpha.
