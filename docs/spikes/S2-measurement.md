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

| Tryb | Urządzenie | Ekran Hz | Średni FPS | Czas klatki (avg) | Opóźnienie event→draw proxy (avg, p95 w koszykach 1 ms) | Swipy | Status pacingu | Logi |
|---|---|---|---|---|---|---|---|---|
| **60 FPS** | Galaxy A15 | 90.0 Hz | 60.09 FPS | 16.64 ms | 1.89 ms (max 16.47 ms, p95 3 ms) | 13 | 0 over-budget, anomalia całego biegu max 43.67 ms* | [JSON](../../spikes/s2-swipe/evidence/60fps/s2_25133_7660896_1.json) \| [TXT](../../spikes/s2-swipe/evidence/60fps/s2_25133_7660896_1.txt) |
| **60 FPS** | S26 Ultra | 60.0 Hz | 60.05 FPS | 16.65 ms | 1.50 ms (max 7.94 ms, p95 3 ms) | 34 | 0 over-budget, interwał max 19.47 ms | [JSON](../../spikes/s2-swipe/evidence/60fps/s2_3179_8591962_1.json) \| [TXT](../../spikes/s2-swipe/evidence/60fps/s2_3179_8591962_1.txt) |
| **60 FPS** | S26 Ultra | 120.0 Hz | 60.08 FPS | 16.64 ms | 1.15 ms (max 5.31 ms, p95 2 ms) | 15 | 0 over-budget, interwał max 21.11 ms | [JSON](../../spikes/s2-swipe/evidence/60fps/s2_22586_58481241_3.json) \| [TXT](../../spikes/s2-swipe/evidence/60fps/s2_22586_58481241_3.txt) |
| **90 FPS** | Galaxy A15 | 90.0 Hz | 90.04 FPS | 11.11 ms | 6.16 ms (max 10.75 ms, p95 10 ms) | 18 | 0 over-budget, interwał max 15.90 ms | [JSON](../../spikes/s2-swipe/evidence/90fps/s2_25133_31195934_2.json) \| [TXT](../../spikes/s2-swipe/evidence/90fps/s2_25133_31195934_2.txt) |
| **90 FPS** | S26 Ultra | 120.0 Hz | 78.01 FPS | 12.82 ms | 5.47 ms (max 17.89 ms, p95 16 ms) | 16 | 340 over-budget, interwał max 21.10 ms (przebieg 1) | [JSON](../../spikes/s2-swipe/evidence/90fps/s2_22586_29115938_2.json) \| [TXT](../../spikes/s2-swipe/evidence/90fps/s2_22586_29115938_2.txt) |
| **90 FPS** | S26 Ultra | 120.0 Hz | 90.07 FPS | 11.10 ms | 1.27 ms (max 8.77 ms, p95 3 ms) | 21 | 0 over-budget, interwał max 12.63 ms (przebieg 2) | [JSON](../../spikes/s2-swipe/evidence/90fps/s2_3179_60141550_2.json) \| [TXT](../../spikes/s2-swipe/evidence/90fps/s2_3179_60141550_2.txt) |
| **120 FPS** | S26 Ultra | 120.0 Hz | **120.00 FPS** | **8.33 ms** | **3.95 ms** (max 11.72 ms, p95 4 ms) | 22 | Średni 120.00 FPS; 14/2461 over-budget, interwał max 12.86 ms | [JSON](../../spikes/s2-swipe/evidence/120fps/s2_3179_89716985_3.json) \| [TXT](../../spikes/s2-swipe/evidence/120fps/s2_3179_89716985_3.txt) |
| **Adaptive** | S26 Ultra | 120.0 Hz | **120.00 FPS** | **8.33 ms** | **4.16 ms** (max 8.85 ms, p95 7 ms) | 13 | Średni 120.00 FPS (Engine.max_fps = 0); over-budget n/a | [JSON](../../spikes/s2-swipe/evidence/adaptive/s2_3179_121067137_4.json) \| [TXT](../../spikes/s2-swipe/evidence/adaptive/s2_3179_121067137_4.txt) |

### Wnioski z testów urządzeń i odświeżania ekranu:
1. **Tryb 120 FPS na ekranie 120 Hz**:
   - Średni render wyniósł **120.00 FPS** przy średnim czasie klatki **8.33 ms** i opóźnieniu event→post_draw średnio **3.95 ms** (p95 w koszyku 4 ms).
   - Nie wykazano jednak idealnie jednolitego pacingu: 14 z 2461 zdarzeń dotykowych przekroczyło budżet 8.33 ms (maksymalne opóźnienie proxy 11.72 ms), a maksymalny callback interval renderingu wyniósł 12.863 ms.
2. **Tryb Adaptive (bez limitu silnika)**:
   - Zdjęcie limitu silnika (`Engine.max_fps = 0`) pozwoliło na osiągnięcie średniego renderu **120.00 FPS** i średniego czasu klatki **8.33 ms**.
   - Tryb ten usuwa jedynie sztuczny cap silnika; nie implementuje ani nie dowodzi aktywnego sterowania odświeżaniem po stronie OS. Wyświetlana w HUD i raportowana wartość `display_refresh_hz` to pojedyncze zapytanie do `DisplayServer` w momencie zatrzymania.
   - *Semantyka starszych raportów*: W surowym pliku [`s2_3179_121067137_4.json`](../../spikes/s2-swipe/evidence/adaptive/s2_3179_121067137_4.json) pole `events_over_target_frame_budget` wynosi 0, ponieważ przy braku limitu silnika porównanie z budżetem było pomijane. Wartość ta oznacza brak zastosowania porównania (unavailable), a nie zero zarejestrowanych przekroczeń. Uaktualnione narzędzie oznacza ten stan jako `target_frame_budget_applicable: false` oraz `events_over_target_frame_budget: -1`.
3. **Wyniki 90 FPS na S26 Ultra (120 Hz)**:
   - W repozytorium zachowano oba wykonane przebiegi jako równorzędne dowody pomiarowe: bieg 78.01 FPS (340 zdarzeń over-budget) oraz bieg 90.07 FPS (0 zdarzeń over-budget), bez arbitralnego przesądzania o pojedynczej przyczynie różnicy.
4. **Tryb 60 FPS i anomalia A15**:
   - Tryb 60 FPS zachowuje stabilność na ekranach 60 Hz, 90 Hz oraz 120 Hz (render co drugi cykl odświeżania).
   - Maksymalny interwał klatki 43.665 ms w teście A15 60 FPS dotyczy całego przebiegu pomiaru i pozostaje nierozstrzygnięty co do tego, czy wystąpił podczas aktywnego swipe'a, czy w bezczynności między gestami.
5. **Charakterystyka metryk**:
   - Wartości p95 podawane są w koszykach histogramu 1 ms (`[N, N+1) ms`).
   - Czasy `event_to_update` oraz `event_to_post_draw` to punkty pomiarowe na granicach silnika (scheduling/render proxies), nie fizyczny czas reakcji touch-to-photon.



