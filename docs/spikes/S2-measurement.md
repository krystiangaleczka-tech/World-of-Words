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

## Device test evidence (Galaxy A15) — T-0053

Device: Samsung Galaxy A15 5G `SM-A156B`, Android 16 / API 36, GPU ARM Mali-G57 MC2, Godot 4.7.2.stable.
Display detected refresh rate: `90.0 Hz` (`display_refresh_hz`).
Evidence files:
- Run 1 (60 FPS): [JSON](../../spikes/s2-swipe/evidence/s2_25133_7660896_1.json) | [TXT](../../spikes/s2-swipe/evidence/s2_25133_7660896_1.txt)
- Run 2 (90 FPS): [JSON](../../spikes/s2-swipe/evidence/s2_25133_31195934_2.json) | [TXT](../../spikes/s2-swipe/evidence/s2_25133_31195934_2.txt)

### Summary of independent runs
- **Run 1 (target 60 FPS)**:
  - Cel: 60 FPS cap, czas trwania: 19.2 s, ukończonych swipów: 13, anulowanych: 0.
  - Średni render FPS: **60.09 FPS** (interwały klatek: średnia 16.64 ms, max 43.67 ms, p95 19 ms).
  - `event_to_update`: średnia **0.39 ms**, max 14.28 ms, p95 2 ms (753 próbki).
  - `event_to_post_draw`: średnia **1.89 ms**, max 16.47 ms, p95 3 ms.
  - Zdarzenia ponad budżet klatki: 0, utracone/niezmierzone: 0.
- **Run 2 (target 90 FPS)**:
  - Cel: 90 FPS cap, czas trwania: 30.5 s, ukończonych swipów: 18, anulowanych: 0.
  - Średni render FPS: **90.04 FPS** (interwały klatek: średnia 11.11 ms, max 15.90 ms, p95 11 ms).
  - `event_to_update`: średnia **0.27 ms**, max 3.50 ms, p95 2 ms (1818 próbek).
  - `event_to_post_draw`: średnia **6.16 ms**, max 10.75 ms, p95 10 ms.
  - Zdarzenia ponad budżet klatki: 0, utracone/niezmierzone: 0.

### Obserwacje i mini-log: detekcja częstotliwości odświeżania ekranu (Hz)
- **Wskaźnik Hz wyświetlacza w UI**:
  Aktualne przyciski w narzędziu testują wyłącznie sztywne limity `60 FPS` oraz `90 FPS`.
  Podczas testów zauważono, że w interfejsie diagnostycznym powinna być widoczna wyraźna cecha/wskaźnik informujący o tym, ile Hz ma aktualnie wyświetlacz telefonu (`DisplayServer.screen_get_refresh_rate()`).
- **Urządzenia o innych częstotliwościach i tryby adaptacyjne (dowód z testu S26 Ultra 120 Hz)**:
  Wielu użytkowników korzysta z ekranów 120 Hz, trybów adaptacyjnych (VRR/LTPO dynamicznie zmieniających odświeżanie w zależności od interakcji) lub innych nietypowych częstotliwości.
  Ograniczenie przycisków tylko do 60/90 FPS na ekranie 120 Hz (jak wykazano w Run 2 na S26 Ultra poniżej) prowadzi do desynchronizacji klatek (średnio 78 FPS zamiast 90 i aż 340 zdarzeń ponad budżet), ponieważ 90 FPS nie dzieli równo cyklu 120 Hz (8.33 ms). Natomiast 60 FPS wyświetla się idealnie co drugą klatkę (16.67 ms).
  Rekomendacja: narzędzie diagnostyczne powinno dynamicznie wyświetlać bieżący tryb odświeżania ekranu i umożliwiać test dopasowany do możliwości urządzenia (np. tryb natywny ekranu / 120 Hz).

## Device test evidence (S26 Ultra / SM-S948B 120Hz) — T-0053

Device: Samsung Galaxy S26 Ultra `SM-S948B`, Android 16 / API 36, GPU Qualcomm Adreno 840, Godot 4.7.2.stable.
Display detected refresh rate: `120.0 Hz` / `60.0 Hz` (`display_refresh_hz`).
Evidence files:
- Run 1 (60 FPS cap, 60Hz mode): [JSON](../../spikes/s2-swipe/evidence/s2_22586_9098423_1.json) | [TXT](../../spikes/s2-swipe/evidence/s2_22586_9098423_1.txt)
- Run 2 (90 FPS cap, 120Hz mode): [JSON](../../spikes/s2-swipe/evidence/s2_22586_29115938_2.json) | [TXT](../../spikes/s2-swipe/evidence/s2_22586_29115938_2.txt)
- Run 3 (60 FPS cap, 120Hz mode): [JSON](../../spikes/s2-swipe/evidence/s2_22586_58481241_3.json) | [TXT](../../spikes/s2-swipe/evidence/s2_22586_58481241_3.txt)

### Summary of S26 Ultra runs
- **Run 1 (target 60 FPS on 60 Hz display)**:
  - Cel: 60 FPS cap, ekran w trybie 60 Hz (`display_refresh_hz: 60.0`), czas trwania: 18.8 s, ukończonych swipów: 6.
  - Średni render FPS: **60.00 FPS** (interwały klatek: średnia 16.67 ms, max 19.47 ms, p95 17 ms).
  - `event_to_update`: średnia **0.27 ms**, max 6.16 ms, p95 1 ms (480 próbek).
  - `event_to_post_draw`: średnia **16.16 ms**, max 18.12 ms, p95 16 ms.
  - Zdarzenia ponad budżet klatki: 35.
- **Run 2 (target 90 FPS on 120 Hz display)**:
  - Cel: 90 FPS cap, ekran w trybie 120 Hz (`display_refresh_hz: 120.0`), czas trwania: 28.3 s, ukończonych swipów: 16.
  - Średni render FPS: **78.01 FPS** (niedopasowanie 90 FPS do cyklu odświeżania 120 Hz powoduje frame dropy i nieregularne tempo klatek; interwały: średnia 12.82 ms, max 21.10 ms, p95 17 ms).
  - `event_to_update`: średnia **0.17 ms**, max 4.98 ms, p95 1 ms (1086 próbek).
  - `event_to_post_draw`: średnia **5.47 ms**, max 17.89 ms, p95 16 ms.
  - Zdarzenia ponad budżet klatki: **340** — bezpośredni dowód na problem sztywnego capu 90 FPS na ekranie 120 Hz!
- **Run 3 (target 60 FPS on 120 Hz display)**:
  - Cel: 60 FPS cap, ekran w trybie 120 Hz (`display_refresh_hz: 120.0`), czas trwania: 25.4 s, ukończonych swipów: 15.
  - Średni render FPS: **60.08 FPS** (60 FPS równo dzieli 120 Hz co drugą klatkę; interwały: średnia 16.64 ms, max 21.11 ms, p95 18 ms).
  - `event_to_update`: średnia **0.28 ms**, max 4.55 ms, p95 2 ms (1020 próbek).
  - `event_to_post_draw`: średnia **1.15 ms**, max 5.31 ms, p95 2 ms.
  - Zdarzenia ponad budżet klatki: 0.

## Iteracja v2 narzędzia S2 (120 FPS, Adaptive, Live HUD w trakcie swipe)
Na podstawie testów i obserwacji z urządzeń dodano w aplikacji:
1. **Przycisk `START 120 FPS`** (`Engine.max_fps = 120`) do natywnego testu ekranów 120 Hz.
2. **Przycisk `START ADAPTIVE`** (`Engine.max_fps = 0` / bez sztucznego limitu w silniku, zależne od systemu i adaptacyjnego odświeżania ekranu).
3. **Live HUD podczas swipe**:
   - Bezpośrednio nad kołem na bieżąco wyświetlane są: aktualne Hz ekranu (`DisplayServer.screen_get_refresh_rate()`), cel testu, aktualny FPS i czas klatki w ms, opóźnienia `event→draw` oraz `event→update`, a także licznik swipów.


