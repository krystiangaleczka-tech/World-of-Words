---
id: T-0327
title: Render the actual catalog gallery and publish CI screenshot artifacts
epic: E13
type: infra
area: ci
risk: high
executor: sol
think: med
ui: low
status: review
depends_on: [T-0211, T-0210]
touch:
  - .github/workflows/ci.yml
  - game/ui/gallery/capture.gd*
  - tools/gallery_screenshots.py
  - tools/tests/test_gallery_screenshots.py
  - docs/qa/T-0327/**
  - tasks/T-0327-gallery-screenshots.md
revision: 2
---

## Goal
Provide the CI gallery artifact required by DESIGN: actual Compatibility screenshots for every registered GalleryShell page, with an offline browseable index and machine-verifiable manifest.

## Context
- ROADMAP T-0327, decision 0006: native rendered evidence is required for visual review.
- docs/DESIGN.md#pr-screenshot-rules: artifacts on UI PRs, three layouts and PL/PSEUDO for text changes.
- docs/DESIGN.md#design-review-checklist: text at 130%, high contrast, catalog states and touch sizes.

## Current state
- GalleryShell.configure(layout,language,high_contrast,text_percent,reduced,insets,page) and preview_viewport expose the actual catalog preview. SIZES has COMPACT/REGULAR/TABLET; PAGES currently contains 15 pages including script-backed Samples.
- All pages use existing generated themes and LocaleCatalog; the gallery owns pseudolocalization settings and restores them on exit.
- CI has 15 checks and uses the pinned 4.7.2 toolchain image. No gallery artifact job exists. ui/gallery is already excluded from Release and the export archive inspector verifies this.
- builds/ is ignored. No new Python dependency or game/project/export setting is required.

## Specification
- New gallery/capture.gd SceneTree script defers work until autoloads exist, instantiates the real GalleryShell and drives only its public configure/preview APIs. Render every PAGES entry × three SIZES × PL/PSEUDO × default100/HC130, with reduced motion and no debug safe insets. Current count is 180 images; adding a catalog page automatically expands it. No duplicated component/page construction or fabricated UI.
- Force real Compatibility/X11 drawing, settle a fixed frame count, save actual unscaled preview PNGs at each target size, check nonempty/nonuniform image data, and fail on errors. Record page/layout/locale/theme/size/file matrix and actual engine/display/renderer metadata in manifest.json. Use names <page>_<class>_<lang>_<state>.png. No reference-device or pixel-diff claim.
- New standard-library Python runner pins/checks Godot, imports assets, runs capture under xvfb-run when DISPLAY is absent, and always sets LIBGL_ALWAYS_SOFTWARE=1 and Dummy audio. Existing DISPLAY may be used for local native verification. Capture import/render logs; reject nonzero engine exits or engine ERROR/SCRIPT ERROR logs even if exit is zero.
- Output must be an empty directory under builds; reject stale/nonempty directories or paths outside builds rather than deleting user files. Validate exact complete matrix coverage, unique safe filenames, PNG framing/CRCs/dimensions and bounded IDAT decompression/scanline framing and actual Compatibility metadata. Add per-image byte counts/SHA256, then generate an offline HTML image index. Missing/truncated/corrupt/incomplete output fails.
- Path filter covers game/ui/**, game/features/** and game/locale/**, plus this tool/capture/workflow during development. Use a verified base commit and git diff --no-renames with NUL names so deletes and renames out of UI still trigger capture. Irrelevant docs-only changes skip rendering and remain a successful check.
- Add PR-only CI job with checkout/full history, safe Git directory, change filtering, explicitly authorized Ubuntu packages xvfb/xauth/Mesa/X11 libraries, and Compatibility software rendering. No Docker image rebuild or new secrets/permissions. Upload builds/gallery (logs, PNGs, manifest and index) as a PR artifact even if rendering failed, preserving the failing job status; do not hide missing artifacts. Timeout bounds the job.

## Tests
New Python tests cover required/irrelevant paths and actual Git rename/deletion behavior; fresh-output path validation and stale rejection; manifest completeness/uniqueness/unsafe paths; missing, truncated, corrupt PNGs and wrong dimensions; engine nonzero and error-log rejection; index escaping/local links. Use subprocess fakes only for failure-path unit tests; actual local native capture must render all 180 images through the real GalleryShell.
Full make check, independent review, CI gallery artifact and both Android checks pass. Download/inspect the actual CI manifest and a screenshot before merging.

## Acceptance
The new gallery check publishes the complete native artifact for this PR and future relevant UI PRs; docs-only PRs skip the render. All 16 exact-head checks pass, with artifact link in the PR.

## Rollback
Squash revert removes only the new tooling/job. No production save, gameplay, engine or exported Release content changes; gallery remains excluded.

## UX rules (docs/DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1: A screen task may not create a component. This task only drives existing GalleryShell pages.
- R-UI-2: New component = separate task, including its gallery entry. None are created here.
- R-UI-3: No raw visual values in feature/component scenes; this tool uses the public gallery sizes.
- R-UI-4: Strings shown to players use translation keys. Output index/logs are development tooling.
- R-UI-5: Never edit generated themes. Capture selects the existing default100/HC130 themes.
- R-UI-6: UI med/high attaches the required gallery evidence. This tooling produces the CI artifact.

## Preflight evidence
Fresh main 00923e5; T-0210 and T-0211 are merged (task status remains review by repository convention).
Verified GalleryShell's exact public signatures, three SIZES, 15 PAGES, theme/pseudo restoration,
CI image/root package installation, builds ignore and Release gallery exclusion on this base.
