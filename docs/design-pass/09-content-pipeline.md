# 09 — Content pipeline

Najważniejszy zasób projektu po game feelu. Cel: tysiące leveli bez ręcznego tworzenia, z jakością, którą da się zmierzyć, i z odtwarzalnością co do bajta.

## 1. Zasady

1. **Ważność słowa pochodzi wyłącznie z licencjonowanego źródła + Twoich overrides.** LLM nigdy nie decyduje, czy coś jest słowem.
2. **LLM tylko klasyfikuje i opisuje** (obraźliwe, archaiczne, nieznane przeciętnemu dorosłemu, temat), a jego wynik jest cache'owany jako dane.
3. **Deterministycznie:** ziarno levelu = hash(język, wersja pipeline'u, numer kandydata). Ten sam input = ten sam output.
4. **Etapy z artefaktami.** Każdy etap czyta artefakt poprzedniego i zapisuje swój. Można uruchomić od dowolnego etapu.
5. **Wydane sloty są niezmienne** (litery, siatka, słowa levelowe). Lista słów bonusowych może się zmieniać (naprawy słownika nie łamią zapisu gracza).

## 2. Etapy

| # | Etap | Sposób | Weryfikacja automatyczna | Weryfikacja ręczna |
|---|---|---|---|---|
| 1 | **Ingest** źródeł słownika | deterministyczny skrypt (pobranie + suma kontrolna) | suma kontrolna, liczba wpisów | licencja: raz, przy wyborze źródła |
| 2 | **Normalizacja** (Unicode NFC, wielkie litery, alfabet języka, długość 3–N) | deterministyczny | testy reguł per język | — |
| 3 | **Adnotacja**: częstość, lemat, część mowy, forma fleksyjna, nazwa własna, skrót | deterministyczny z danych (korpus częstości, słownik morfologiczny) | pokrycie (ile słów ma częstość) | — |
| 4 | **Klasyfikacja** wrażliwości i znajomości | **AI** (tani model, wsadowo) + cache | dwa przebiegi (dwa modele albo dwa prompty); rozbieżności do kolejki | **tylko** rozbieżności i kandydaci na słowa levelowe z flagą |
| 5 | **Tiery słów**: `level_ok` / `bonus_ok` / `banned` | algorytm z reguł (`pipeline/config/<lang>.yaml`) + overrides | rozkład tierów vs poprzednia wersja (alarm przy dużej zmianie) | `overrides/<lang>.csv` — Twoje decyzje |
| 6 | **Kandydaci na zestawy liter** | algorytm: słowo-ziarno z `level_ok` o długości N → multizbiór liter → wszystkie słowa możliwe do ułożenia (indeks anagramów) | ≥ min słów `level_ok` | — |
| 7 | **Budowa siatki** | algorytm: wybór podzbioru słów + rozmieszczenie krzyżówkowe (zachłannie z nawrotami, wiele ziaren, wybór najlepszego układu) | niezmienniki: spójność, brak przypadkowych słów na stykach, rozmiar, proporcje pod pion | — |
| 8 | **Wynik trudności** | algorytm (cechy × wagi z `scoring.yaml`) | rozkład wyników | kalibracja telemetrią (Phase 3) |
| 9 | **Walidacja twarda** | algorytm | wszystko poniżej w §4; błąd = level odrzucony | — |
| 10 | **Duplikaty i różnorodność** | algorytm: ten sam multizbiór liter; Jaccard zbiorów słów; słowo-ziarno nie częściej niż co K leveli | progi w configu | — |
| 11 | **Sekwencjonowanie** do kampanii | algorytm: dopasowanie puli do krzywej trudności per slot; sloty landmark; ograniczenia onboardingu | odchylenie od krzywej, gładkość | przegląd wykresu krzywej |
| 12 | **QA** | raport (statystyki, histogramy, lista najdziwniejszych słów levelowych) + **AI**: przegląd list słów pod kątem „dziwne dla tego slotu” (tylko flagi) | — | przegranie próbki w trybie debug w grze: 100% pierwszych ~100 leveli i landmarków, ~5% reszty, wszystkie oflagowane |
| 13 | **Eksport** | deterministyczny: paczki JSON + manifest (wersja, hashe) do `game/content/<lang>/` | schemat; plik blokady wydanych slotów | review PR typu `content` |

### Content ręczny
**Pierwsze ~20–30 leveli (onboarding) i landmarki projektujesz ręcznie** w prostym YAML (litery + słowa), a pipeline robi tylko siatkę, walidację i eksport. Onboarding jest za ważny dla generatora.

## 3. Klasyfikacja AI: koszt i kontrola
- Słownik PL po filtrach długości to rząd dziesiątek tysięcy słów. Klasyfikacja wsadowa (np. 200 słów na wywołanie) taniego modelu przez API to setki wywołań: koszt pomijalny w porównaniu z czasem review.
- Cache klucza `(słowo, wersja promptu, model)` w `pipeline/cache/` **commitowany do repo** (to wejście do odtwarzalnego buildu contentu; ponowne uruchomienie nic nie kosztuje).
- Wynik klasyfikacji to *sugestia tieru*. Tier ustalają reguły + overrides.
- Kolejka review: plik CSV z rozbieżnościami; Ty decydujesz i wpis trafia do `overrides/<lang>.csv` z powodem. Overrides mają najwyższy priorytet i są historią decyzji słownikowych.
- AI przydaje się też do: list tematycznych (słowa „morskie” dla lokacji nad morzem), tytułów i opisów lokacji, propozycji słów do kalendarza daily na święta. Zawsze jako wejście przefiltrowane przez słownik.

## 4. Walidacja twarda (blokująca)
- każde słowo levelowe i bonusowe ułożalne z multizbioru liter,
- każde słowo levelowe ma tier `level_ok`, bonusowe `bonus_ok` lub `level_ok`, żadne `banned`,
- lista bonusów = wszystkie słowa `bonus_ok`/`level_ok` ułożalne z liter minus słowa levelowe (kompletność, żeby poprawne słowo nigdy nie było „invalid”),
- siatka spójna, rozmiar ≤ limit (np. 10×10 dla telefonu w pionie), każde słowo dokładnie raz,
- brak przypadkowych ciągów na stykach (litery sąsiadujące bokiem tworzą tylko zamierzone słowa),
- liczba liter i słów w zakresie dla slotu, wynik trudności w oknie celu,
- schemat JSON zgodny, poprawne znaki alfabetu języka,
- brak duplikatu względem całej kampanii i puli daily,
- wydane sloty bez zmian w literach/siatce/słowach levelowych (porównanie z plikiem blokady).

## 5. Schemat levelu (szkic do `CONTENT.md`)

```json
{
  "id": "pl-c-000128",
  "lang": "pl",
  "slot": 128,
  "letters": ["D", "O", "M", "A", "K"],
  "words": [
    {"w": "DOM",  "x": 0, "y": 0, "dir": "h"},
    {"w": "MODA", "x": 2, "y": 0, "dir": "v"}
  ],
  "bonus": ["ODA", "KOD", "DAM"],
  "grid": {"w": 3, "h": 4},
  "difficulty": 18.4,
  "seed": 9137442,
  "pipeline": "0.7.0"
}
```
Paczki po ~100 leveli (`packs/pl-c-0101-0200.json`), manifest z wersją contentu i mapowaniem slot → lokacja → region. Daily jako osobna pula + kalendarz.

## 6. Decyzje językowe do podjęcia w Phase 0 (blokują pipeline)
| Pytanie | Rekomendacja (do Twojej decyzji) |
|---|---|
| Polskie diakrytyki jako osobne litery na kole? | Tak (`Ą`≠`A`); tak gra większość polskich gier słownych i daje to więcej słów |
| Słowa levelowe: tylko formy podstawowe? | Tak, formy podstawowe i bardzo częste formy odmienione |
| Słowa bonusowe: formy odmienione? | Tak, wszystkie poprawne formy z `bonus_ok` (to jest przewaga „uczciwego słownika”) |
| Minimalna długość słowa | 3 |
| Nazwy własne, skróty | Nie |
| Wulgaryzmy w bonusach | Nie akceptujemy, ale też nie karzemy: komunikat jak dla invalid |

## 7. Pętla zwrotna z gry (Phase 3)
```
invalid_word_submitted (agregat) ─► ciągi wysyłane często ─► sprawdzenie w źródle
   ├─ jest w źródle, ale tier banned/odfiltrowany ─► kolejka review ─► override ─► nowe listy bonusów
   └─ nie ma w źródle ─► kandydat do dodania (Twoja decyzja) ─► override
level_complete/hint_used/czas per slot ─► rzeczywista trudność ─► kalibracja wag scoring.yaml
```
Naprawa słownika zmienia tylko listy bonusów w wydanych levelach, więc nie łamie zapisu.

## 8. Źródła danych (do weryfikacji licencji w spike'u S3)
- PL: słownik SJP.pl do gier słownych (dostępny na kilku licencjach do wyboru), PoliMorf/Morfeusz dla morfologii; częstość z korpusu na licencji pozwalającej na użycie danych pochodnych.
- EN: SCOWL / ENABLE (swobodne licencje); unikać list turniejowych na licencjach komercyjnych.
- Częstość: np. `wordfreq` (dane na CC BY-SA, sprawdzić, czy wbudowanie *pochodnych* wyników w grę jest OK) albo własne liczenie na korpusie o jasnej licencji.

## 9. Struktura kodu pipeline'u
```
pipeline/src/wordgame_pipeline/
  ingest.py  normalize.py  annotate.py  classify.py  tiers.py
  candidates.py  grid.py  scoring.py  validate.py  dedupe.py
  sequence.py  qa_report.py  export.py  cli.py   # `wg build --lang pl --from tiers`
```
Jeden moduł na etap, jedna komenda CLI. To naturalne granice obszarów dla równoległych tasków (`pipeline.grid`, `pipeline.scoring`…), a `validate.py` i `export.py` są `risk: high`.
