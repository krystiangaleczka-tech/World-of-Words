# S2 independent measurement — T-0053

## Why the tool changed

Chris performed two separate human test attempts. The old tool did not reset its counters between
attempts: the export at 90 FPS contains the same first 53 history entries as the export at 60 FPS,
followed by 29 additional entries. Therefore the old exports cannot establish two independent
60/90 FPS distributions. This is a limitation of the tool, not of the operator's test intent.

Historical logs on t/0029-s2-device-logs are preserved. No fabricated rerun replaces them.

## New device protocol

1. Build the isolated spikes/s2-swipe project using pinned Godot 4.7.2 and the existing Android
   export preset. This task changes no project/export settings or permissions.
2. Put the phone in the desired display-refresh mode and allow its performance to settle.
3. Press START 60 FPS. This assigns a new run ID, applies an engine FPS cap of 60 and resets every
   event, swipe, frame and histogram counter. Only then perform the slow/fast swipe protocol,
   including backtracking and second-finger checks.
4. Press ZAKOŃCZ I ZAPISZ. The frozen run is written to its own user://s2_<id>.json and .txt files,
   printed to the console and copied to the clipboard where the platform supports it.
5. Switch the phone's display-refresh mode as needed, then press START 90 FPS and repeat. A 90 cap
   cannot force a 60 Hz display to render at 90 FPS. Compare target_fps, display_refresh_hz and
   average_render_fps; do not label a below-target run as demonstrated 90 FPS performance.
6. Retain both independently identified reports. Record human swipe/haptic ratings separately;
   timings cannot prove haptics, intended letters, backtrack correctness or second-finger behavior.

Starting a run is disabled while another is active. Stop freezes the snapshot. If either file write
fails, the report remains frozen and new runs stay disabled; retry Stop + save. Filenames are unique
per run, so a later run does not overwrite an earlier one. Losing application focus automatically
aborts any active swipe and stops/saves the run; background gaps are not foreground frame samples.

## What is measured

- event_to_update: from GDScript input dispatch to the next _process endpoint update.
- event_to_post_draw: from the same dispatch to RenderingServer.frame_post_draw for the frame
  carrying that endpoint update. Events arriving after _process wait for the following frame.
- Both counters measure all queued input events, not only the most recent drag timestamp. Events
  coalesced by the OS before dispatch are outside the instrument's visibility.
- average_render_fps: rendered-frame interval count divided by the sum of those intervals across
  the entire foreground run. It is independent of the requested FPS cap and the export-time FPS.
- Each timing includes sample count, mean, true maximum and a 1 ms p95 histogram bin. Bin N means
  [N, N+1) ms; the final 250 bin means >=250 ms. overflow_samples makes percentile saturation visible.
- Events exceeding the requested frame budget, aborted/completed swipe counts, dropped_events and
  unmeasured_events are exported. Fixed 512-event queues avoid input/frame-path allocations. Any
  nonzero drop/pending count means incomplete latency coverage and must be disclosed.

These are engine scheduling/render-boundary proxies, not physical touch-to-photon latency. Input
timestamps exclude sensor/OS delivery time, and frame_post_draw does not timestamp GPU completion
or display scanout. Use an external high-speed-camera or hardware measurement for full end-to-end
latency. A smooth human assessment remains useful alongside these diagnostics.

## Regression checks

tools/tests/test_s2_measurement.py executes the injected-clock GDScript suite under the CI Godot
binary. It verifies independent resets, immutable stopped results, multi-event collection, frame
boundaries, average FPS from intervals, timing percentiles, frame-budget counts, bounded drops,
histogram saturation, aborted swipes and empty runs. No sleeps or physical-device claims are used.

Run directly: godot --headless --path spikes/s2-swipe --script res://tests/test_measurement.gd.
Repository CI tools pytest runs the same suite; a game-only import is not counted as spike testing.

## Device test evidence — T-0053 (split by FPS)

All raw JSON and TXT logs are organized by FPS category under [`spikes/s2-swipe/evidence/`](../../spikes/s2-swipe/evidence/):
- [`60fps/`](../../spikes/s2-swipe/evidence/60fps/)
- [`90fps/`](../../spikes/s2-swipe/evidence/90fps/)
- [`120fps/`](../../spikes/s2-swipe/evidence/120fps/)
- [`adaptive/`](../../spikes/s2-swipe/evidence/adaptive/)

### Mini-log & Porównanie trybów

| Tryb | Urządzenie | Ekran Hz | Średni FPS | Czas klatki (avg) | Opóźnienie event→draw (avg) | Swipy | Status pacingu | Logi |
|---|---|---|---|---|---|---|---|---|
| **60 FPS** | Galaxy A15 | 90.0 Hz | 60.09 FPS | 16.64 ms | 1.89 ms (max 16.5 ms) | 13 | Stabilny 60 FPS | [JSON](../../spikes/s2-swipe/evidence/60fps/s2_25133_7660896_1.json) \| [TXT](../../spikes/s2-swipe/evidence/60fps/s2_25133_7660896_1.txt) |
| **60 FPS** | S26 Ultra | 60.0 Hz | 60.05 FPS | 16.65 ms | 1.50 ms (max 7.94 ms) | 34 | Płynny, 0 over-budget | [JSON](../../spikes/s2-swipe/evidence/60fps/s2_3179_8591962_1.json) \| [TXT](../../spikes/s2-swipe/evidence/60fps/s2_3179_8591962_1.txt) |
| **60 FPS** | S26 Ultra | 120.0 Hz | 60.08 FPS | 16.64 ms | 1.15 ms (max 5.31 ms) | 15 | Płynny (co 2. klatka 120Hz) | [JSON](../../spikes/s2-swipe/evidence/60fps/s2_22586_58481241_3.json) \| [TXT](../../spikes/s2-swipe/evidence/60fps/s2_22586_58481241_3.txt) |
| **90 FPS** | Galaxy A15 | 90.0 Hz | 90.04 FPS | 11.11 ms | 6.16 ms (max 10.8 ms) | 18 | Stabilny 90 FPS | [JSON](../../spikes/s2-swipe/evidence/90fps/s2_25133_31195934_2.json) \| [TXT](../../spikes/s2-swipe/evidence/90fps/s2_25133_31195934_2.txt) |
| **90 FPS** | S26 Ultra | 120.0 Hz | 90.07 FPS | 11.10 ms | 1.27 ms (max 8.77 ms) | 21 | Ukończony (v2 timing) | [JSON](../../spikes/s2-swipe/evidence/90fps/s2_3179_60141550_2.json) \| [TXT](../../spikes/s2-swipe/evidence/90fps/s2_3179_60141550_2.txt) |
| **120 FPS** | S26 Ultra | 120.0 Hz | **120.00 FPS** | **8.33 ms** | **3.95 ms** (max 11.7 ms) | 22 | **Idealny 120 Hz render pacing** | [JSON](../../spikes/s2-swipe/evidence/120fps/s2_3179_89716985_3.json) \| [TXT](../../spikes/s2-swipe/evidence/120fps/s2_3179_89716985_3.txt) |
| **Adaptive** | S26 Ultra | 120.0 Hz | **120.00 FPS** | **8.33 ms** | **4.16 ms** (max 8.85 ms) | 13 | **Natywne 120 Hz, bez ograniczeń** | [JSON](../../spikes/s2-swipe/evidence/adaptive/s2_3179_121067137_4.json) \| [TXT](../../spikes/s2-swipe/evidence/adaptive/s2_3179_121067137_4.txt) |

### Wnioski z testów urządzeń i odświeżania ekranu:
1. **Tryb 120 FPS na ekranie 120 Hz**:
   - Perfekcyjne renderowanie z czasem klatki **8.33 ms** i średnim renderem **120.00 FPS**.
   - Opóźnienie event→draw średnio **3.95 ms** (p95: 4 ms). Pełna responsywność bez żadnych zacięć.
2. **Tryb Adaptive (bez limitu silnika)**:
   - Silnik dynamicznie synchronizuje się z maksymalnym odświeżaniem ekranu urządzenia (na S26 Ultra: **120.0 Hz**).
   - Średni render FPS: **120.00 FPS**, średni frame interval: **8.33 ms**, brak zdarzeń over-budget.
3. **Tryb 60 FPS**:
   - Zachowuje pełną stabilność zarówno na ekranie 60 Hz (16.65 ms), 90 Hz (16.64 ms), jak i 120 Hz (16.64 ms - klatka co drugi cykl odświeżania).
4. **Live HUD w czasie rzeczywistym**:
   - Wyświetla na bieżąco podczas swipe'a: aktualne Hz ekranu, cel FPS, real-time FPS i czas klatki w ms, opóźnienia dotyku oraz liczbę wykonanych swipów.



