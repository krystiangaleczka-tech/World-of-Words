# T-0246 postcard evidence

Native Godot 4.7.2 `ed1daf0bf`, X11/Xvfb, OpenGL compatibility renderer.
`capture.gd` generates the 28 PNG files in this directory. Run it from an isolated copy of
`game/` as `res://capture246.gd`; its output path points at this evidence directory.

## Fixtures and coverage

The Journey test catalog supplies three locations. The gradient illustration and the Harbor
sample fact are injected review fixtures, not shipped content or proposed final art/copy.
Production packs without illustrations or facts show the translated pending-content state;
final assets/copy belong to T-0289. Market deliberately has no fact to exercise that fallback.

The matrix is COMPACT 1080x1920, REGULAR 1080x2340 and TABLET 1440x1920, each with PL and
35% PSEUDO, default 100% and high contrast 130%, for partial Market and complete Harbor (24 PNGs).
All use safe inset fixtures (24 horizontal, 48 vertical). Four additional REGULAR PL default
captures cover missing art, terminal campaign, reduced-motion reveal and normal-motion reveal.
The capture asserts four displayed pieces and RewardBurst `static`/`playing`, respectively.

Visual inspection: wrapped copy, completion caption and Continue remain inside the reading
surface, including COMPACT PSEUDO HC130. Missing art retains saved numeric progress; terminal
Continue is disabled with an explanation. The native integration test additionally uses a tall
portrait fixture to require pointer scrolling and confirms Continue can be brought fully into
view in all three classes. A completion-origin Back goes Home instead of replaying the board.

## Validation

- Postcard integration: 13 tests / 259 assertions, headless and native X11.
- Reveal tests cover transition settlement, one-shot refresh/re-entry, reduced motion and cleanup.
- Full repository checks and exact-head independent review are recorded in the PR.

Physical-device screenshots and Chris's visual/taste approval remain pending. These native
captures validate layout and behavior, not device certification or final illustration quality.
