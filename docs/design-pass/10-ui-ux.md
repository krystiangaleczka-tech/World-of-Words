# 10 — Workflow UI/UX i design system

Cel: spójny wygląd bez projektowania ekran po ekranie, i przekazanie designu tanim modelom w formie, której nie da się źle zinterpretować.

## 1. Kolejność

```
1. Kierunek wizualny (Opus + Ty): moodboard słowny, 2–3 mockupy HTML kluczowego ekranu (level)
2. Tokeny (z wybranego mockupu) → game/ui/tokens.gd
3. Komponenty (z tokenów) + scena galerii → game/ui/components/, game/ui/gallery/
4. Specyfikacje ekranów składane WYŁĄCZNIE z komponentów → taski UI
5. Review na zrzutach z galerii i z urządzenia
```
Żaden ekran produkcyjny nie powstaje przed krokiem 3. W Phase 1 (prototyp) UI jest celowo surowe i nie wymaga design systemu.

## 2. Tokeny

Jedno źródło prawdy w kodzie: `game/ui/tokens.gd` (stałe GDScript, czytelne dla agentów). Theme Godota (`theme.tres`) jest **generowany** z tokenów skryptem narzędziowym, nikt nie edytuje go ręcznie.

| Grupa | Przykłady | Uwagi |
|---|---|---|
| `Palette` | `BG`, `SURFACE`, `PRIMARY`, `ON_PRIMARY`, `SUCCESS`, `BONUS`, `ERROR`, `TILE`, `TILE_SELECTED`, `CELL_EMPTY`, `CELL_FILLED` | nazwy semantyczne, nie „blue_500”; wariant wysokiego kontrastu |
| `Type` | `DISPLAY`, `TITLE`, `BODY`, `LABEL`, `TILE_LETTER`, `CELL_LETTER` | font z pełnym polskim zestawem; rozmiary względne do skali layoutu |
| `Space` | `XS, S, M, L, XL` (skala 4/8) | żadnych liczb w scenach |
| `Radius`, `Elevation` | `S, M, L`; cienie jako tokeny | |
| `Motion` | `INSTANT, FAST, BASE, SLOW`, `Ease.OUT/IN_OUT/SPRING` | reduced motion przemapowuje do `INSTANT` w jednym miejscu |
| `Touch` | `MIN_TARGET` (≥ 44–48 pt) | |
| `Layout` | progi klas: `COMPACT`, `REGULAR`, `TABLET` | |

## 3. Komponenty (katalog startowy)

`PrimaryButton`, `SecondaryButton`, `IconButton`, `CurrencyPill`, `Badge`, `ProgressBar`, `Sheet` (dolny panel zamiast popupów), `Toast`, `Card`, `LetterTile`, `GridCell`, `RewardBurst` (efekt nagrody), `ScreenScaffold` (safe area + top bar + treść).

Każdy komponent:
- ma wszystkie stany (normal, pressed, disabled, loading, highlighted),
- występuje w **scenie galerii** w każdym stanie, w klasach layoutu `COMPACT` / `REGULAR` / `TABLET` i w obu językach (polskie znaki, dłuższe teksty),
- ma krótki wpis w `DESIGN.md#components`: do czego, parametry, czego nie robić.

Nowy komponent = osobny task (`area: ui.components`). Taski ekranów nie tworzą komponentów „przy okazji”.

## 4. Layout, safe areas, urządzenia

- **Tylko pion** na telefonach. Tablet też w pionie na start; sprawdź aktualne wymagania Apple dotyczące orientacji i zmiany rozmiaru okna na iPadzie (iPadOS 26 zmienił zasady wielozadaniowości), zanim zamkniesz tę decyzję.
- Bazowa rozdzielczość projektowa np. 1080×1920, `stretch mode = canvas_items`, `aspect = expand`; treść w `ScreenScaffold`, który stosuje `DisplayServer.get_display_safe_area()`.
- **Ekran levelu jako dwa prostokąty**: obszar siatki (elastyczny) i obszar koła (stała proporcja szerokości). Siatka skaluje się do obszaru, więc każdy rozmiar planszy mieści się bez przewijania.
- Klasy layoutu zamiast pikseli: `COMPACT` (małe telefony, niskie proporcje), `REGULAR`, `TABLET` (koło nie rośnie w nieskończoność; maksymalna szerokość treści, tło wypełnia resztę).
- Urządzenia referencyjne do review: mały Android (np. 5,5" 720p), iPhone z wycięciem/Dynamic Island, iPad.

## 5. Ruch i przejścia
- Przejścia między ekranami: jeden wzorzec (fade + lekki slide, `Motion.BASE`); bez ekranów ładowania między levelami (następny level ładowany w tle w trakcie animacji ukończenia).
- Animacje game feel ekranu levelu (litery lecące do siatki, ukończenie słowa, ukończenie levelu, bonus) są **specyfikowane w jednym dokumencie animacji ekranu levelu** w `DESIGN.md#level-motion` i strojone przez Ciebie na urządzeniu. To jedyne miejsce, gdzie liczby czasu mogą się zmieniać często; dlatego żyją w tokenach/zasobach, nie w kodzie.

## 6. Dostępność (od początku, tanio)
- skalowanie tekstu (przynajmniej 2 kroki), tryb wysokiego kontrastu jako wariant palety,
- informacja nigdy wyłącznie kolorem (bonus vs level: kolor + ikona/tekst),
- reduced motion, wyłączana haptyka, osobne głośności,
- minimalne pola dotyku,
- czytniki ekranu dla nawigacji i przycisków (gra słowna z kołem jest z natury trudna dla niewidomych; nie obiecujemy pełnej obsługi rozgrywki).

## 7. Przekazywanie designu między modelami

To jest najsłabsze ogniwo każdego workflow „AI projektuje, AI implementuje”. Proza („przyjemny, przestronny ekran”) daje losowe wyniki. Proponuję trzy formy, w tej kolejności:

1. **Mockup HTML/CSS z tymi samymi tokenami.** Opus (albo Sol) robi statyczną stronę ekranu, używając zmiennych CSS o nazwach identycznych z `tokens.gd`. Otwierasz ją w telefonie w przeglądarce, iterujecie w minutach, bez Godota. Zaakceptowany mockup to referencja wizualna (zrzut w `docs/design/`).
2. **Specyfikacja ekranu jako drzewo komponentów** (w tasku, sekcja UX):
   ```yaml
   screen: home
   scaffold: { top_bar: [CurrencyPill(coins), Spacer, IconButton(settings)] }
   body:
     - Title(text: location.name, style: Type.TITLE)
     - LocationPostcard(progress: location.stars / location.stars_total)
     - PrimaryButton(text: "play", action: Nav.level(next_slot))
   bottom: [NavTab(daily), NavTab(journey), NavTab(collection)]
   states: { daily_locked: "NavTab(daily) disabled, label 'Level 15'" }
   spacing: Space.L between body items
   ```
   Tani model składa to z istniejących komponentów. Nie wymyśla nic.
3. **Zrzut ekranu z urządzenia w PR** + porównanie z mockupem przy review. Rozbieżności wizualne poprawiasz Ty albo Sol w małym tasku, nie w dyskusji.

Grafika (tła lokacji, pocztówki, ikony): generowana przez model obrazowy wg stałego dokumentu stylu (prompt bazowy, paleta, kompozycja), z Twoją selekcją; ikony z otwartego zestawu (np. Lucide, Material Symbols), żeby nie rysować ich ręcznie. Sprawdź warunki licencyjne narzędzia do generowania grafiki przed użyciem komercyjnym.
