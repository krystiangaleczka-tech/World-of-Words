# 06 — Standard tasków i równoległość

Pusty szablon gotowy do repo: `seed/tasks/TEMPLATE.md`. Szablon epiku: `seed/tasks/EPIC_TEMPLATE.md`. Ten plik wyjaśnia, *dlaczego* tak, i pokazuje kompletny przykład.

## 1. Zasady projektowe

1. **Task = 1 PR = 1 obszar.** Docelowo < ~300 zmienionych linii i ≤ ~5 plików produkcyjnych (testy się nie liczą). Większy = podziel.
2. **Kontrakt, nie kod.** Task podaje sygnatury, dane, zachowanie i przypadki testowe z konkretnymi wartościami. Nie dyktuje kodu linia po linii (to robi z taniego modelu maszynistkę i sprawia, że task pęka przy pierwszej różnicy w repo).
3. **Testy jako wykonywalne kryteria akceptacji.** Najskuteczniejszy sposób ograniczenia decyzji taniego modelu to lista przypadków testowych z wejściem i oczekiwanym wyjściem.
4. **Allowlista zamiast listy zakazów.** `touch:` mówi, co wolno zmienić; CI odrzuca resztę. Listy „nie ruszaj X” są zawsze niepełne.
5. **Cytuj, nie tylko linkuj.** 2–3 reguły, które naprawdę mają znaczenie, wklej do taska dosłownie. Tani model często nie doczyta linku.
6. **Sekcja tylko, jeśli niesie informację.** Puste sekcje usuwamy. Ogólne rzeczy (Definition of Done, zasady kodu) są w `AGENTS.md`, nie w każdym tasku.
7. **Równoległość jest wyliczana, nie deklarowana.** Ręczne listy „można równolegle z T-0044, konfliktuje z T-0043” rosną kwadratowo i starzeją się po pierwszym merge'u. Wystarczą `depends_on`, `area` i `touch`; resztę liczy `tools/tasks.py plan`.

## 2. Front-matter (część maszynowa)

```yaml
---
id: T-0123
title: Letter wheel shuffle
epic: E04
type: feat            # contract | feat | fix | refactor | test | content | infra | spike | docs
area: level.wheel     # dokładnie jeden obszar z listy w ARCHITECTURE.md#areas
risk: low             # low | medium | high  → ścieżka review
executor: cheap       # cheap | sol | human
status: ready         # draft | ready | in_progress | review | blocked | done
depends_on: [T-0118]
touch:                # allowlista globów; CI egzekwuje
  - game/features/level/wheel/**
  - game/core/board/shuffle.gd
  - game/tests/unit/board/test_shuffle.gd
  - game/data/analytics/level.json
revision: 1           # zwiększa Sol przy każdej zmianie po eskalacji
---
```

**Zasady ryzyka** (Sol ustawia przy pisaniu):
- `high`: dotyka zapisu, ekonomii, IAP, reklam, zgód, walidatorów pipeline'u, kontraktów, `project.godot`, albo eksportu contentu do wydanych slotów,
- `medium`: nowa logika w `core/`, zmiana zachowania widocznego dla gracza, nowy event analityki,
- `low`: UI w istniejących komponentach, testy, refaktor mechaniczny, poprawki.

## 3. Sekcje treści i po co są

| Sekcja | Kiedy | Po co |
|---|---|---|
| **Goal** | zawsze | 1–3 zdania: co gracz/system będzie robić po zmianie. Pozwala wykonawcy odrzucić interpretacje sprzeczne z celem. |
| **Context** | zawsze | Max 5 odnośników do sekcji docs + dosłowny cytat 1–3 kluczowych reguł. |
| **Current state** | zawsze | Istniejące pliki, klasy, sygnatury i sygnały, z których task korzysta. Generowane z `context_pack`. Podstawa preflightu; główny bezpiecznik przeciw halucynacjom. |
| **Specification → Behavior** | zawsze | Numerowane, testowalne stwierdzenia. |
| **Specification → Interface** | gdy powstaje/zmienia się API | Dokładne sygnatury, sygnały, kształty danych. |
| **Specification → States** | gdy jest stan | Tabela stan × zdarzenie → stan. Zamiast prozy. |
| **Specification → Edge cases** | prawie zawsze | Tabela przypadek → oczekiwane zachowanie (w tym błędy). |
| **Specification → UX** | tylko UI | Komponenty i tokeny (`Motion.FAST`, `Space.M`), stany wizualne, odnośnik do mockupu/zrzutu. Żadnych „ładnie” ani „150–220 ms”. |
| **Specification → Analytics** | gdy są eventy | Nazwy i parametry z rejestru albo dokładny nowy wpis do rejestru. |
| **Out of scope** | zawsze | Kuszące rzeczy, których NIE robić (np. „nie zmieniaj kosztu hinta”). |
| **Tests** | zawsze (poza `docs`/`spike`) | Nazwa testu + given/when/then z konkretnymi wartościami + plik. |
| **Acceptance** | zawsze | Tylko specyficzne dla taska: wymagane testy przechodzą, kroki ręcznej weryfikacji dla review UI. `make check` jest w DoD globalnie. |
| **Implementation notes** | opcjonalnie | Sugerowane podejście, pułapki („`await`, nie `yield`”). Bez dyktowania. |
| **Rollback** | tylko `risk: high` | Gdy revert squasha nie wystarczy: migracja zapisu, wydany content, identyfikatory sklepowe, flaga w configu. |
| **Escalation log** | wypełniane w trakcie | Pytania wykonawcy i odpowiedzi Sola z numerem rewizji. |

**Celowo pominięte** z Twojej listy: osobne „Definition of Done” (globalne w `AGENTS.md`), „safe parallel tasks” i „likely conflicts” (wyliczane), „files forbidden” (zastąpione allowlistą), „dependencies” w treści (są w front-matter), „rollback” dla każdego taska (squash revert wystarcza dla 90% przypadków).

## 4. Przykład: poprawiony TASK042 (shuffle)

Taski piszemy po angielsku (patrz `04-repo-i-dokumenty.md`).

````markdown
---
id: T-0123
title: Letter wheel shuffle
epic: E04
type: feat
area: level.wheel
risk: low
executor: cheap
status: ready
depends_on: [T-0118]
touch:
  - game/core/board/shuffle.gd
  - game/tests/unit/board/test_shuffle.gd
  - game/features/level/wheel/letter_wheel.gd
  - game/features/level/hud/shuffle_button.gd
  - game/data/analytics/level.json
revision: 1
---

## Goal
The player can tap Shuffle to rearrange the letters on the wheel, so they can see
the same letters in a new layout. It is free and never changes the level state.

## Context
- GAME_DESIGN.md#power-ups — "Shuffle is free and unlimited."
- DESIGN.md#motion — wheel rearrangement uses `Motion.FAST` with `Ease.OUT`.
- ARCHITECTURE.md#layers — "core/ never uses Node, randi() or Time; RNG is injected."

## Current state
- `game/features/level/wheel/letter_wheel.gd`
  - `class_name LetterWheel extends Control`
  - `func set_tiles(letters: PackedStringArray) -> void`
  - `var is_dragging: bool` (true between touch down and touch up)
  - `signal word_attempted(tile_indices: PackedInt32Array)`
  - tile i is drawn at `_slot_position(i)`; tile order is `_order: PackedInt32Array`
- `game/features/level/hud/shuffle_button.gd` exists, button is wired to nothing.
- `game/core/board/` has no shuffle code yet.

## Specification
### Behavior
1. Tapping Shuffle permutes which tile sits in which wheel slot.
2. The multiset of letters is unchanged; tile indices passed in `word_attempted`
   still refer to the original tiles (shuffle changes positions only).
3. If at least two tiles have different letters, the new visible letter sequence
   differs from the current one.
4. While `is_dragging` is true, Shuffle does nothing.
5. Shuffle does not touch Economy, Progress or BoardState.
6. Each successful shuffle emits analytics event `shuffle_used`.

### Interface
```gdscript
# game/core/board/shuffle.gd
class_name Shuffle extends RefCounted
## @api
static func permute(order: PackedInt32Array, letters: PackedStringArray,
		rng: RandomNumberGenerator) -> PackedInt32Array
```
`LetterWheel.shuffle(rng: RandomNumberGenerator) -> bool` — returns false when ignored (dragging).

### Edge cases
| Case | Expected |
|---|---|
| All letters identical (e.g. A,A,A) | returns a permutation; no infinite loop; no "must differ" requirement |
| 2 tiles, different letters | result is always the swapped order |
| Rapid repeated taps | each tap starts from the current (possibly mid-animation) target order; animation retargets, no queue |
| Tap during drag | ignored, returns false, no event |

### UX
- Tiles tween from old slot to new slot: `Motion.FAST`, `Ease.OUT`, all tiles in parallel.
- Haptic `Platform.haptics.play(&"tick")` once per shuffle.
- Button uses existing `IconButton` component with icon `icons/shuffle` (already in assets).

### Analytics
Add to `game/data/analytics/level.json`:
`shuffle_used { slot: int, letters_count: int }`

## Out of scope
- No cost, no limit, no cooldown.
- Do not change the wheel layout math (`_slot_position`).
- Do not add sound (separate task T-0131).

## Tests
File: `game/tests/unit/board/test_shuffle.gd`
- `test_preserves_tiles`: order [0,1,2,3], letters [D,O,M,A], seed 1 → result is a permutation of [0,1,2,3].
- `test_differs_when_possible`: letters [D,O,M,A], seeds 1..50 → letters read in new order ≠ letters in old order for every seed.
- `test_identical_letters_terminates`: letters [A,A,A], seed 7 → returns 3-element permutation.
- `test_two_tiles_swap`: order [0,1], letters [O,D] → [1,0].
- `test_deterministic`: same seed → same result.

## Acceptance
- All tests above exist and pass.
- Manual (reviewer, in editor): open debug level 3, press Shuffle 10× quickly → no stuck tiles;
  start a swipe and tap Shuffle with another finger → nothing happens.

## Implementation notes
- Godot 4: tween with `create_tween().set_parallel()`; kill the previous tween before starting a new one.
- To guarantee "differs", retry with the same RNG up to 10 times, then rotate by one.
````

Zwróć uwagę: wykonawca nie musi podjąć ani jednej decyzji produktowej, ale układ kodu wewnątrz plików nadal należy do niego.

## 5. Epik (szkielet)

Epik to miejsce na decyzje. Pełny szablon w `seed/tasks/EPIC_TEMPLATE.md`. Sekcje: Goal, Player-facing outcome, Decisions (z odnośnikami do `docs/decisions/`), Contracts (API i dane, które powstaną najpierw), Waves (tytuły tasków z zależnościami), Open questions (muszą być puste przed rozpisaniem fali, której dotyczą), Exit criteria.

## 6. Strategia równoległego developmentu

Zamiast deklarować w każdym tasku, z czym może iść równolegle, system opiera się na siedmiu regułach:

1. **Kontrakt najpierw.** Jeśli tasky B, C, D korzystają z nowego API, najpierw merge'ujemy mały task `contract` z sygnaturami, stubami i testami kontraktu. Potem B, C, D idą równolegle.
2. **Jeden aktywny task na obszar.** Obszary (`level.wheel`, `level.board`, `economy`, `pipeline.grid`, `ui.components`…) to zamknięta lista w `ARCHITECTURE.md#areas`, mapowana na ścieżki. Dwa taski w tym samym obszarze nie biegną naraz.
3. **Rozłączne `touch`.** `tasks.py plan` nie wypuści dwóch tasków, których globy `touch` się przecinają.
4. **Rejestry jako katalogi.** Config, analityka, lokalizacja, decyzje: plik per obszar. Brak plików-list edytowanych przez wszystkich.
5. **Hotspoty szeregowo.** Pliki z listy hotspotów (patrz `04`) zmieniają wyłącznie taski `infra`/`contract`, nigdy dwa naraz.
6. **Krótkie życie branchy.** Task, który nie zmergował się w ciągu ~1 dnia od startu, jest do przeglądu (za duży albo zablokowany).
7. **„Uruchom ponownie zamiast rozwiązywać”.** Taski są małe, a wykonawcy tani, więc przy nietrywialnym konflikcie wyrzucamy branch i wykonujemy task od nowa na świeżym `main` (patrz `07`).

**Kolejność merge'a** wynika z `depends_on` (topologicznie), a przy remisie: `contract` → `infra` → `risk: high` → reszta. Wysokie ryzyko wcześniej, bo jego regresje chcemy zobaczyć, zanim nałożą się na nie inne zmiany.

**Ile torów naraz:** Phase 0: 1 (szeregowo). Phase 1: 2–3. Phase 2: 3–4. Phase 3: 4–6. Górny limit wyznacza Twoja przepustowość review, nie liczba agentów.
