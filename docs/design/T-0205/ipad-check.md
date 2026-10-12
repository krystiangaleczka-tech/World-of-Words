# Q10 — iPad orientation and resizing check

Checked 2026-10-12. **Q10 remains open for Chris and the native build task.**
This report does not change PRODUCT's portrait-only requirement, iOS settings or plist.

## Current primary-source finding
Apple [TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key)
was revised 2026-08-13. Full-screen compatibility is deprecated from iPadOS 26.
For apps built with the iOS 27 SDK, UIRequiresFullScreen no longer exempts them from
resizing; it can produce discrete resizing. Apple's resizable-scene migration requires
all interface orientations and geometry updates. Orientation-lock requests are preferences
and are not guaranteed. Thus a permanent fixed portrait-only iPad window cannot be
certified by this documentation check. This is an SDK/windowing constraint, not a
claim that every portrait game will be rejected by App Review.

## Proposed disposition, not an adopted requirement
Keep phone gameplay portrait. For iPad, investigate a centered portrait composition inside
resizable windows, recomputing layout/safe areas and preserving touch geometry. That approach
may require a future PRODUCT/architecture/platform decision about allowed host orientations.
Chris must decide it after a pinned Godot iOS 27 export and real iPad test. Do not silently
reinterpret "No landscape" as permission to change export orientation or supported devices.

## Browser evidence
T-0205 checks 768x1024, 512x768 and 1024x768. A capped column keeps these documentation
mockups readable; menu content and the Shop sheet scroll internally, while Level fixtures
fit without scrolling. This establishes browser geometry only, not UIKit/scene integration,
Godot iOS behavior, OS insets, App Review acceptance or a physical iPad observation.

## Native handoff
T-0208/T-0226 must verify the pinned export's scene lifecycle, supported orientations,
resize notifications, layout-class updates, physical target sizes and launch screen with
the current SDK. Record owner disposition and any contract change in a separate task/decision.
No native setting, signing, permission or manifest is edited by T-0205. An actual iPad is
unavailable for this check; no native PASS or resolved Q10 is claimed.
