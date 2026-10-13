# T-0225 motion B

WordPreview owns a preallocated passive bonus ghost: BASE/IN_OUT moves its visual center to a
validated same-canvas target while scaling to0.4. Arrival is presentation only; gallery caller
fills the existing meter and triggers its existing icon pop. Source cue holds TOAST_HOLD then
fades FAST. Replacement/exit cancel silently; resize/live reduction settle once with static word;
freed/removed targets restore the word without emitting arrival. Reentrant arrival can replace
feedback safely. Generic already targets pulse1.06 twiceFAST and restore original scale/pivot;
BonusMeter retains its own pulse ownership. LevelScreen uses its existing P1 bonus Label.

Valid preview pops1.08 FAST/SPRING. Invalid uses three ±24cycles BASE/OUT, TEXT→ERROR FAST then
FAST fade; translated × cue remains available in high contrast and reduced motion. Silent1–2tile
release emits a separate wheel signal and FAST/IN fade without core attempt or result/audio events.
Hint/reveal cells start0.6 with alpha0, BASE/SPRING; ordered word reveal uses STAGGERx2, corrects
prior hinted members and flashes the full affected word including filled intersections. Board-owned
pipeline tracks nominal duration for the existing bounded completion sequence. Completion timers
are killed on settlement rather than retaining still-valid SceneTree references until next frame.

Pinned4.7.2 GUT419/419 includes seven new tests: transformed bonus center/scale, atomic validation,
replacement/reentrant arrival, freed target/reentry, resize/reduction, two already peaks and target
restoration, invalid tint/shake/fade, silent short release, ordered hint correction and full-word
flash. Float tolerances apply to scale; timer callbacks are checked1ms after BASE boundaries.
Existing assertions retained except documented obsolete P1 timing/state oracles and Reward-only
CSS count scoping (SHAKE_OFFSET24 is dimensional). Full make check and13CI required before merge.

Native Compatibility/llvmpipe captures in ignored builds/T-0225-preview cover24 actual Powerups
gallery configurations: three classes ×PL/PSEUDO ×default100/HC130 ×normal/reduced; normal captures
show mid-flight, reduced show static word and completed meter. A further native PSEUDO/HC130
capture verifies invalid × cue. Generated themes are untouched; generated CSS mirrors tokens.
Independent exact-head review is required before merge. Physical devices/readers/taste/Opus and
T-0221 remain open. Final HUD composition is T-0276; no gameplay/save/economy schema changes.

The implementation spans more than five production files/300lines because result motion,
wheel short-release routing, ordered cell effects, catalog demonstration and token mirrors share
lifecycle behavior. S9 continuation was explicitly authorized by the owner ("No rób napraw to").
