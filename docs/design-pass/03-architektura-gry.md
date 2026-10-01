# 03 — Architektura gry i framework game designu

Cel: granice modułów i zależności, nie implementacja. Zasada nadrzędna: **mało warstw, mało interfejsów, logika w czystych klasach, dane zamiast kodu.**

## 1. Kluczowa decyzja upraszczająca: runtime nie zna słownika

Pipeline (Python, offline) generuje dla każdego levelu komplet danych: litery, siatkę, słowa levelowe **i pełną listę słów bonusowych możliwych do ułożenia z tych liter**. Gra w runtime nie zawiera słownika ani logiki normalizacji. Walidacja słowa to sprawdzenie w dwóch zbiorach.

Co to daje:
- brak rozjazdu reguł między generatorem a grą (jedno źródło: pipeline),
- brak problemu z licencją na dystrybucję całego słownika w aplikacji,
- brak normalizacji Unicode w GDScript (litery to kafelki, nie tekst wpisywany z klawiatury),
- mniejsza i prostsza gra; naprawa słownika = nowa paczka danych, nie nowy kod.

Koszt: kilka MB JSON na tysiące leveli na język (dobrze się kompresuje). Akceptowalny.

## 2. Warstwy

```
┌──────────────────────────────────────────────────────────────┐
│ features/   Sceny i skrypty UI per ekran (level, home,       │
│             journey, daily, shop, settings)                  │
│             Czytają stan, wołają serwisy, odtwarzają animacje│
├──────────────────────────────────────────────────────────────┤
│ ui/         Design system: theme, tokeny, komponenty, galeria│
├──────────────────────────────────────────────────────────────┤
│ services/   Autoloady ze stanem i persystencją (zamknięta    │
│             lista, patrz §3)                                 │
├──────────────────────────────────────────────────────────────┤
│ core/       Czysta logika: RefCounted, bez Node, bez I/O,    │
│             czas i losowość wstrzykiwane. 100% testowalne.   │
├──────────────────────────────────────────────────────────────┤
│ platform/   Adaptery SDK (ads, iap, analytics, crash,        │
│             consent, haptics, review, notifications) + Fake  │
└──────────────────────────────────────────────────────────────┘
data/     rejestry i konfiguracja (JSON), content/  paczki leveli (generowane)
```

**Reguły zależności (sprawdzane w review, później skryptem):**
1. `core/` nie importuje niczego spoza `core/`. Nie używa `Node`, `FileAccess`, `Time`, `randi()`.
2. `services/` używają `core/` i `platform/`. Nie znają scen.
3. `features/` i `ui/` używają `services/` i `core/` (typy danych). Nigdy nie wołają `platform/` bezpośrednio.
4. `platform/` nie zna logiki gry; tłumaczy SDK na proste sygnały i wywołania.
5. Komunikacja w górę przez sygnały. Globalny bus `Events` wyłącznie dla efektów ubocznych (analityka, audio, haptyka), nigdy dla logiki („logika wywołuje, efekty słuchają”).

Jedyne interfejsy w projekcie to adaptery platformowe (bo istnieją realnie co najmniej dwie implementacje: SDK i Fake). Nigdzie indziej nie wprowadzamy abstrakcji „na zapas”.

## 3. Zamknięta lista autoloadów

| Autoload | Odpowiedzialność | Stan trwały |
|---|---|---|
| `Config` | domyślne wartości z `data/config/*.json` + nadpisania zdalne; walidacja typów i zakresów; bucket A/B | cache zdalnego JSON |
| `Save` | jeden plik zapisu, wersjonowanie, migracje, zapis atomowy, kopia zapasowa | tak (właściciel pliku) |
| `Progress` | aktualny slot kampanii, gwiazdki, odblokowania funkcji, lokacje | przez `Save` |
| `Economy` | portfel (monety, power-upy), `grant()`/`spend()` z powodem, dziennik transakcji | przez `Save` |
| `Daily` | kalendarz daily, streak, freeze | przez `Save` |
| `Content` | ładowanie paczek leveli, manifest, dostęp do levelu po slocie i do daily po dacie | nie |
| `Monetization` | polityka reklam (decyzje z `core/ad_policy`), przepływy rewarded i IAP, Remove Ads | przez `Save` (przetworzone transakcje) |
| `Analytics` | `track(name, params)`, walidacja z rejestrem w buildach debug, kolejka | nie |
| `Audio` | odtwarzanie cue'ów z rejestru, głośności | ustawienia przez `Save` |
| `Nav` | maszyna stanów ekranów, przejścia | nie |
| `Events` | sygnały efektów ubocznych | nie |
| `Platform` | kontener adapterów (`Platform.ads`, `.iap`, `.haptics`…); wybiera SDK albo Fake | nie |

Dodanie autoloadu = zmiana architektury = eskalacja do Sola (patrz `05-workflow-ai.md`). Lista żyje w `ARCHITECTURE.md`.

## 4. Moduły i granice

### 4.1 Gameplay levelu (najważniejsza ścieżka)

```
LetterWheel (features/level/wheel)
  │ swipe → sygnał word_attempted(tile_indices: PackedInt32Array)
  ▼
LevelController (features/level) ── woła ──► BoardState (core/board)
  │                                            evaluate(tiles) → AttemptResult
  │                                            { kind: LEVEL | BONUS | ALREADY_FOUND | INVALID,
  │                                              word, cells_to_reveal }
  ▼
Board view animuje odkrycie, HUD aktualizuje licznik bonusów
Events.word_found / bonus_found / invalid_word  → Analytics, Audio, Haptics
BoardState.is_complete() → Progress.complete_level() → Economy.grant(reward) → Nav
```

- **`core/board`**: `LevelData` (dane z paczki, niezmienne), `BoardState` (odkryte słowa i komórki, znalezione bonusy), `HintLogic` (którą literę/słowo odkryć; deterministycznie, z zasadą „najpierw komórki przecięć” albo inną zapisaną w GAME_DESIGN).
- **Litery jako indeksy kafelków, nie znaki.** Swipe zwraca indeksy, więc powtarzające się litery (np. dwa `A`) nie są problemem.
- **`LetterWheel`**: wejście `InputEventScreenTouch/Drag`, promień trafienia większy niż grafika, cofanie przez powrót na poprzednią literę, ignorowanie drugiego palca, linia aktualizowana co klatkę bez alokacji, haptyka przy każdej literze. To jest komponent, w którym rozstrzyga się game feel; wymaga iteracji na urządzeniu.
- **`Board`**: renderuje siatkę z danych (współrzędne z pipeline'u), skaluje do dostępnego prostokąta.
- **Shuffle**: czysta funkcja w `core/` (permutacja z wstrzykniętym RNG, wymóg „inna niż obecna, jeśli to możliwe”).

### 4.2 Progresja i meta

- **Slot kampanii** to stały numer levelu (1, 2, 3…). Gracz ma zapisany najwyższy ukończony slot. Mapowanie slot → lokacja → region pochodzi z `content/` (manifest), nie z kodu.
- **Gwiazdki** zarabiane za level (proste: 1 za ukończenie; ewentualnie więcej za brak hintów, decyzja GAME_DESIGN).
- **Meta MVP**: pocztówka lokacji odsłaniana kawałkami za gwiazdki. Później world-building, jeśli dane pokażą sens.
- **Odblokowania funkcji** (hint od levelu 7, daily od 15…) w `data/config/unlocks.json`.

### 4.3 Ekonomia

- Jedna waluta: **monety**. Power-upy jako przedmioty w ekwipunku (`hint`, `reveal`, `shuffle` darmowy). Gwiazdki to postęp, nie waluta.
- Wszystkie zmiany przechodzą przez `Economy.grant(source, items)` i `Economy.spend(sink, items) -> bool`. Każda transakcja trafia do dziennika (ostatnie N wpisów w zapisie) i do analityki. Kwoty tylko całkowite.
- Ceny, nagrody, tabele nagród w `data/config/economy.json` z identyfikatorami (`reward.level_complete`, `reward.bonus_chest`, `price.hint`).
- `core/economy` zawiera reguły (czy stać, jak policzyć nagrodę); `Economy` (serwis) trzyma stan.

### 4.4 Monetyzacja

**Polityka reklam** to czysta funkcja w `core/ad_policy`:
`should_show_interstitial(state, config, now) -> bool`, gdzie `state` to: level, levele od ostatniej reklamy, czas od ostatniej, czas od startu sesji, Remove Ads, czy właśnie był zakup. W 100% testowalna, sterowana konfiguracją.

**Rewarded**: nagroda przyznawana tylko w callbacku „reward earned”. Brak reklamy (no fill, offline) = jasna informacja i alternatywa, nigdy martwy przycisk.

**IAP: przepływ, który trzeba zaprojektować dobrze od początku**
```
purchase(product_id)
  → sklep zwraca transakcję (id, produkt)
  → jeśli transaction_id ∈ Save.processed_transactions: zakończ transakcję, nic nie przyznawaj
  → Economy.grant(...) albo ustaw entitlement (remove_ads)
  → Save.flush() (zapis atomowy)
  → dopiero teraz finish/consume/acknowledge w sklepie
start gry: pobierz niezakończone transakcje → ten sam przepływ (idempotentny)
restore: odtwarza tylko non-consumables (entitlements)
```
Weryfikacja zakupu lokalna (podpisane transakcje StoreKit 2, sygnatura Play Billing). Bez backendu akceptujemy ryzyko oszustw w grze single-player.

**Zgody**: `Platform.consent` (UMP) uruchamiane przed inicjalizacją reklam; ATT na iOS w kontrolowanym momencie, nie przy pierwszym uruchomieniu.

### 4.5 Daily challenge, streak, czas

- Daily: paczka puli daily w `content/` + kalendarz `data/` (data → id puzzla). Wszyscy gracze mają ten sam puzzle danego dnia.
- **Dzień = data lokalna urządzenia.** Nie walczymy z cofaniem zegara w grze single-player (świadoma decyzja; zapisana w `docs/decisions/`).
- `core/streak`: czysta logika z wstrzykniętą datą; testy na granice dnia, zmianę strefy, DST, przerwy, freeze.
- Zegar wstrzykiwany wszędzie (`Clock` w serwisach, data jako parametr w `core/`).

### 4.6 Zapis (save)

- Jeden plik JSON `user://save.json` z polem `schema_version`.
- Zapis atomowy: zapis do pliku tymczasowego → rename; poprzednia wersja jako `save.bak`. Przy błędzie odczytu: fallback na kopię, a przy jej braku start z czystym stanem i event analityczny `save_corrupted`.
- Migracje jako łańcuch funkcji `migrate_v1_to_v2(dict) -> dict`, każda z **złotym plikiem testowym** (`tests/fixtures/save/v1.json` → oczekiwany v2).
- Zapis przy zdarzeniach znaczących (koniec levelu, transakcja, zmiana ustawień, wyjście do tła), nie co klatkę.
- Struktura sekcjami według serwisów (`progress`, `economy`, `daily`, `monetization`, `settings`, `meta`), żeby przyszły cloud sync mógł scalać sekcje osobno (np. max dla postępu, suma transakcji).
- Plik w lokalizacji objętej systemowym backupem (Android Auto Backup: `allowBackup` i reguły; iOS: katalog objęty backupem iCloud).
- `install_id` (losowy UUID) w zapisie: identyfikator dla analityki i bucketów A/B. Brak kont.

### 4.7 Config i remote config

- `data/config/*.json`: **każda** liczba balansowa ma tu wpis: wartość domyślna, typ, zakres, opis, właściciel (np. `economy`).
- Zdalny JSON (CDN) nadpisuje podzbiór kluczy; nieznane klucze ignorowane i logowane; wartości poza zakresem odrzucane.
- A/B: `bucket = hash(install_id + experiment_id) % 100`; definicja eksperymentu w zdalnym JSON (`experiment_id`, warianty, nadpisania kluczy). Bucket wysyłany jako user property do analityki.
- Rejestr jako **katalog plików**, nie jeden plik: każda funkcja ma swój plik, więc równoległe taski nie konfliktują.

### 4.8 Analityka

- `data/analytics/*.json`: rejestr eventów (nazwa, parametry z typami, opis). Taski mogą używać tylko eventów z rejestru; nowy event = zmiana rejestru w tym samym tasku.
- `Analytics.track()` w buildzie debug waliduje nazwę i parametry z rejestrem i głośno krzyczy przy niezgodności. Test w CI: każde wywołanie `track("...")` w kodzie istnieje w rejestrze.
- Słownikowy event `invalid_word_submitted` (język, slot, ciąg liter) to wejście do pętli poprawy słownika (patrz `09-content-pipeline.md`). Ten ciąg liter nie jest danymi osobowymi, ale zbieramy go zgodnie z polityką prywatności.

### 4.9 Lokalizacja

- Język gry = język contentu = język UI (jedno ustawienie, domyślnie z urządzenia, jeśli wspierany). Upraszcza wszystko.
- Teksty UI: pliki CSV Godota per obszar (`locale/level.csv`, `locale/shop.csv`…), klucze po angielsku.
- Fonty z pełnym pokryciem polskich znaków; test wizualny w galerii komponentów.

### 4.10 Audio, haptyka, efekty

- `data/audio/cues.json`: cue → plik(i), głośność, wariacje wysokości. Kod woła `Audio.play(&"word_valid")`.
- Haptyka przez `Platform.haptics` z nazwanymi wzorcami (`tick`, `success`, `error`); na iOS natywne generatory, jeśli plugin to daje (spike).
- Ustawienia: dźwięk, muzyka, haptyka, ograniczony ruch (reduced motion skraca/wyłącza animacje przez tokeny).

### 4.11 Później (nie w MVP, ale granice już znane)
- **Eventy**: definicja w zdalnym JSON (okno czasowe UTC, paczka contentu, typ celu, ścieżka nagród). Jeden szablon eventu na start (np. „zbierz N żetonów, znajdując słowa”).
- **Osiągnięcia**: lista danych (warunek = licznik + próg), liczniki karmione z `Events`. Integracja z Play Games / Game Center dopiero na życzenie.
- **Cloud save**: adapter `Platform.cloud` + scalanie sekcji zapisu.
- **Powiadomienia lokalne**: przypomnienie o daily, za zgodą, plugin.

## 5. Graf zależności (kolejność budowy)

```
core/board ──► features/level (wheel, board, HUD)
    │
content schema ──► Content ──► Progress ──► Economy ──► Monetization
                                  │            │
Save (+migracje) ◄────────────────┴────────────┘
Config ◄── (wszyscy)        Analytics/Audio ◄── Events (efekty uboczne)
Platform adapters (Fake od dnia 1; SDK po spike'u)
```
Kontrakty do zbudowania najpierw (szeregowo): schemat `LevelData`, `BoardState` API, format zapisu v1, loader rejestrów, lista autoloadów z wersjami Fake. Dopiero po nich zaczyna się praca równoległa.

---

## 6. Framework game designu: system / konfiguracja / content

| Warstwa | Co to jest | Gdzie żyje | Kto zmienia | Wymaga buildu? |
|---|---|---|---|---|
| **System** | reguły: jak działa hint, streak, chest, polityka reklam | kod (`core/`, `services/`) | taski | tak |
| **Konfiguracja** | liczby: ceny, nagrody, progi, częstotliwości, odblokowania | `data/config/*.json` + zdalny JSON | Ty / Sol przez PR albo zdalnie | nie (zdalnie) / tak (domyślne) |
| **Content** | levele, daily, lokacje, kolekcje, teksty | `content/` (z pipeline), `locale/`, `assets/` | pipeline + review | tak (później zdalne paczki) |
| **Krzywa trudności** | cel trudności per slot | `pipeline/config/` | Ty / Sol | nie dotyczy runtime |

Krzywa trudności nie istnieje w runtime: pipeline układa levele w kolejności pasującej do krzywej. Gra tylko gra slot po slocie.

### 6.1 Trudność
- **Wynik trudności** liczony w pipeline z cech levelu (liczba liter, liczba i długość słów, częstość słów, liczba anagramów, topologia siatki, przecięcia). Wagi w konfiguracji pipeline'u.
- **Krzywa celu**: trend bazowy (rosnący per region) + fala (np. piłokształtna o długości 5) + skoki na levelach landmark + „oddech” po landmarku. Parametry w `pipeline/config/curve.yaml`.
- **Kalibracja danymi** (Phase 3): z telemetrii (czas, hinty, porzucenia per level) liczymy rzeczywistą trudność i dopasowujemy wagi cech. Bez tego wynik trudności pozostaje hipotezą.

### 6.2 Ekonomia projektowana w „jednostkach intencji”
Zamiast od razu ustalać „hint = 100 monet”, definiujemy intencję, np.:
- „gracz bez reklam i zakupów może użyć hinta średnio co ~4 levele”,
- „rewarded ad jest wart ~1 hinta”,
- „bonus chest co ~2 sesje”.

Liczby w konfiguracji wynikają z intencji. Prosty symulator `tools/econ_sim.py` przepuszcza archetypy graczy (oszczędny, hintujący, oglądający reklamy) przez 300 leveli i pokazuje saldo w czasie. To tani sposób na wyłapanie zepsutej ekonomii przed graczami. Intencje są decyzją produktową (Ty + Opus jako druga opinia); liczby i symulator robi Sol.

### 6.3 Pętle retencji
| Pętla | Horyzont | Mechanizm |
|---|---|---|
| Rdzeń | minuty | level → natychmiastowy następny level |
| Sesja | sesja | licznik bonusów → skrzynia; postęp pocztówki |
| Dzień | doba | daily puzzle + streak |
| Długoterminowa | tygodnie | podróż po lokacjach, kolekcja pocztówek, kalendarz miesiąca |
| Live (później) | sezon | eventy z ograniczonym czasem |

### 6.4 Monetyzacja jako warstwa na pętlach
- **Interstitial**: tylko według `ad_policy` (brak przed levelem N, minimalny odstęp w levelach i czasie, brak po zakupie, brak przy starcie sesji).
- **Rewarded**: hint, gdy gracz utknął (oferta kontekstowa, nie popup), podwojenie nagrody za level, naprawa streaka.
- **IAP**: Remove Forced Ads, paczki monet, starter pack. Później piggy bank / pass.
- Zasada produktowa do zapisania w GAME_DESIGN: monetyzacja nigdy nie blokuje postępu w kampanii.

**Uczciwie o ryzyku:** „mniej reklam niż konkurencja” to hipoteza produktowa, nie fakt biznesowy. Polska ma niski eCPM. Polityka reklam musi być w konfiguracji od pierwszego dnia, żeby ją testować na danych.
