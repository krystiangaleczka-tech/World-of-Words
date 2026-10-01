# 05 — Workflow AI, podział modeli i reguły eskalacji

## 1. Hierarchia pracy

Proponowane `Vision → Milestone → Epic → Task → PR → Review → Merge` ma dwa zbędne poziomy. Wizja to dokument (`PRODUCT.md`), a Review i Merge to kroki procesu, nie poziomy planowania. Zostaje:

```
Phase  (kamień milowy z kryteriami wyjścia; 4 w całym projekcie do premiery)
  └─ Epic  (system albo funkcja; 3–12 tasków; TU zapadają decyzje)
       └─ Task  (= dokładnie 1 PR; zero decyzji produktowych i architektonicznych)
```

**Najważniejsza zasada podziału:** decyzje żyją w dokumentach i epikach, nigdy w taskach. Task tylko wskazuje decyzję i ją wykonuje. Jeśli przy pisaniu taska trzeba coś zdecydować, to znaczy, że epik jest niedokończony.

### Typy tasków
| Typ | Do czego | Typowy wykonawca |
|---|---|---|
| `contract` | nowe API, schemat danych, sygnatury + stuby + testy kontraktu | Sol (agent) albo silny model |
| `feat` | implementacja zachowania wg kontraktu | tani model |
| `fix` | naprawa z reprodukcją w teście | tani model (prosty) / Sol |
| `refactor` | mechaniczne zmiany bez zmiany zachowania | tani model |
| `test` | dopisanie testów do istniejącego kodu | tani model |
| `content` | uruchomienie pipeline'u, zmiana overrides, eksport paczek | tani model + Twoje review |
| `infra` | CI, Makefile, project.godot, eksport, pluginy | Sol, szeregowo |
| `spike` | ograniczone czasowo rozpoznanie; wynik to raport, nie kod produkcyjny | Sol / Ty |
| `docs` | zmiana dokumentów źródłowych | Sol / Ty |

### Planowanie falami
1. Epik powstaje w całości: cel, decyzje, kontrakty, lista tasków w falach (tylko tytuły i zależności).
2. Szczegółowe taski powstają tylko dla **bieżącej fali** (3–6 tasków), na świeżym `main`, z aktualnym `context_pack`.
3. Po zmergowaniu fali Sol rozpisuje następną. Lista tasków w epiku może się zmienić; to normalne.

## 2. Podział modeli

Zasada: **model dobieramy do kosztu błędu, nie do „prestiżu” zadania.** I drugi filtr: czy decyzję da się łatwo odwrócić.

| Aktywność | Główny | Druga opinia / eskalacja | Ty |
|---|---|---|---|
| Wizja, filary, zakres faz | Ty + Sol | Opus (raz na fazę) | decydujesz |
| Intencje ekonomii, zasady monetyzacji | Sol | **Opus** (nieodwracalne po premierze) | decydujesz |
| Liczby ekonomii, symulator | Sol | — | akceptujesz |
| Onboarding / pierwsze 10 minut | Sol | **Opus** | playtest |
| Fundament design systemu, kierunek wizualny | **Opus** (mockupy HTML, tokeny) | Sol | decydujesz o guście |
| Specyfikacje ekranów z istniejących komponentów | Sol | — | |
| Architektura, niezmienniki, format zapisu, schemat danych | Sol | **Opus** (druga opinia) | akceptujesz |
| Epiki i taski | Sol | — | przeglądasz falę |
| Implementacja `feat`/`test`/`refactor` | tani model | Sol przy STOP | |
| Implementacja `contract`/`infra` | Sol (agent) | — | |
| Code review risk: medium/high | Sol | Opus tylko przy sporze lub architekturze | merge |
| Code review risk: low | automat (CI) + krótkie review taniego modelu | — | rzut oka / próbkowanie |
| Trudny bug (≥2 moduły, 2 nieudane próby) | Sol | Opus | |
| Klasyfikacja słów w pipeline (wsadowo) | tani model przez API | drugi tani model dla rozbieżności | review spornych |
| Analiza telemetrii po soft launchu | Sol | Opus przy decyzjach o kierunku produktu | decydujesz |
| Teksty UI, opisy lokacji, nazwy | Sol | — | akceptujesz |
| Audyt fazy (architektura, UX, ekonomia) | **Opus** (raz na fazę, na zwartej paczce stanu) | — | |

### Gdzie Opus naprawdę daje wartość
1. **Druga opinia przy nieodwracalnym**: format zapisu, polityka slotów contentu, identyfikatory produktów IAP, nazwy eventów analityki (zmiana psuje historię danych), intencje ekonomii.
2. **Wizualny i UX-owy fundament**: tokeny, komponenty, mockupy HTML kluczowych ekranów, onboarding.
3. **Audyt na koniec fazy**: „co tu się psuje” na podstawie zwartej paczki (ARCHITECTURE, lista modułów, metryki CI, otwarte problemy).
4. **Impas**: Sol dwa razy nie rozwiązał problemu albo nie zgadzacie się z Solem w sprawie o wysokiej stawce.

### Czego Opus nie musi robić (Sol wystarczy)
Rozbijanie epików, taski, review rutynowych PR-ów, projekt testów, kod pipeline'u, CI, analityka eventów, remote config, większość bugów, liczby w ekonomii, teksty.

Szacunkowo Opus to kilka sesji na fazę, nie stały element pętli.

### Uwaga o Solu w ChatGPT
- **Jeśli masz dostęp do agenta kodującego z tym modelem** (np. Codex w planie ChatGPT): niech Sol wykonuje taski `contract`, `infra` i złożone `feat` sam, zamiast pisać dla nich ultra-szczegółową specyfikację. Tanie modele zostają dla pracy masowej i mechanicznej.
- **Jeśli masz tylko czat:** każde wywołanie Sola dostaje paczkę z `tools/context_pack.py` (mapa repo, publiczne API, sekcje dokumentów, otwarte taski). Bez tego Sol pisze taski pod nieistniejące repo.
- Wsadowe zadania (klasyfikacja tysięcy słów) nie nadają się do czatu; to robota dla taniego API w skrypcie.

## 3. Reguły eskalacji

Trzy poziomy: **wykonawca (tani model) → Sol → Opus**, plus **Ty** jako właściciel decyzji, których żaden model nie podejmuje.

### 3.1 Wykonawca może sam
- implementować w plikach z listy `touch` taska,
- dodawać prywatne funkcje pomocnicze, nazywać zmienne lokalne, układać kod wewnątrz pliku,
- dopisywać testy wymagane przez task i dodatkowe testy w tych samych plikach,
- poprawiać lint i formatowanie w zmienionych plikach,
- robić rebase bez konfliktów albo z konfliktami czysto mechanicznymi (importy, sąsiednie linie w różnych funkcjach),
- naprawić własny błąd wykryty przez CI.

### 3.2 Wykonawca MUSI się zatrzymać (STOP) i eskalować do Sola, gdy:
| # | Sytuacja |
|---|---|
| S1 | Preflight nie przechodzi: plik, klasa, metoda albo sygnał z sekcji „Current state” nie istnieje albo ma inną sygnaturę. |
| S2 | Potrzebuje zmienić plik spoza `touch` (CI i tak to zablokuje). |
| S3 | Potrzebuje zmienić publiczne API (cokolwiek z `## @api` albo w `core/`), którego task nie opisuje. |
| S4 | Task jest sprzeczny z dokumentem, z kodem albo wewnętrznie. |
| S5 | Test wymagany przez task nie może przejść bez zmiany istniejącego testu, którego task nie wymienia. |
| S6 | Zmiana dotyczy zapisu (schemat, migracje), ekonomii (wartości, reguły), IAP, reklam, zgód, schematu analityki albo walidatorów pipeline'u, a task tego wprost nie zleca. |
| S7 | Potrzebna nowa zależność, plugin, addon albo zmiana `project.godot` / ustawień eksportu. |
| S8 | Testy niezwiązane z taskiem padają na czystym `main` (nie naprawia; raportuje). |
| S9 | Dwie nieudane próby doprowadzenia `make check` do zielonego. |
| S10 | Konflikt przy rebase w logice tej samej funkcji albo w pliku kontraktu. |
| S11 | Cokolwiek związanego z sekretami, kluczami, podpisami, adresami sieciowymi, uprawnieniami aplikacji (manifest, plist). |
| S12 | Musiałby usunąć lub przepisać istniejący kod, którego task nie wymienia. |

**Jak eskaluje:** otwiera draft PR (albo dopisuje do pliku taska) sekcję `Escalation` w stałym formacie: która reguła (S1–S12), co dokładnie znalazł, jakie widzi opcje, co już zrobił. Nie zgaduje. Sol odpowiada **nową rewizją taska**, nie komentarzem w rozmowie, żeby kolejny wykonawca miał komplet.

### 3.3 Sol eskaluje do Opusa (druga opinia), gdy:
- zmienia niezmiennik z `ARCHITECTURE.md` (warstwy, lista autoloadów, reguły zależności),
- zmienia format zapisu w sposób niekompatybilny albo filozofię migracji,
- zmienia schemat danych levelu (wersja główna) albo politykę slotów,
- zmienia intencje ekonomii lub zasady monetyzacji (nie strojenie liczb),
- projektuje albo przebudowuje onboarding lub fundament design systemu,
- dwa razy nie rozwiązał błędu przekrojowego,
- sam ocenia swoją pewność jako niską w sprawie trudnej do odwrócenia.

### 3.4 Tylko Ty decydujesz (żaden model)
- zmiana założeń produktu, zakresu fazy, filarów,
- ceny i lista produktów IAP, identyfikatory produktów w sklepach,
- wszystko z kontami sklepów, podpisami, sekretami, polityką prywatności, zgodami, licencjami,
- wydanie i go/no-go,
- akceptacja game feel i wyglądu na urządzeniu,
- sporne słowa w słowniku (obraźliwe, dwuznaczne, kulturowo wrażliwe),
- usunięcie danych gracza albo zmiana, która może je utracić.

### 3.5 Kiedy agent NIE podejmuje decyzji, nawet jeśli „wie lepiej”
Wykonawca, który uważa task za błędny, **nie poprawia go po swojemu**. Implementuje zgodnie z taskiem, jeśli to możliwe, i opisuje wątpliwość w PR w sekcji „Deviations / concerns”. Jeśli zgodna implementacja jest niemożliwa, to STOP (S4).

## 4. Pętla pracy (stan ustalony, od Phase 1)

```
1. PLAN   Sol: epik → fala tasków (z context_pack)        → Ty: przegląd fali (5 min), commit do tasks/
2. RUN    tools/tasks.py plan → lista tasków gotowych do równoległego startu
          każdy task → osobny agent wykonawczy → branch → make check → PR
3. GATE   CI: lint, testy, scope, rejestry, content, build Android
4. REVIEW wg ryzyka: low = automat + rzut oka; medium = Sol; high = Sol + Ty na urządzeniu (+ Opus przy architekturze)
5. MERGE  squash, w kolejności zależności; reszta torów robi rebase / re-run
6. LEARN  co tydzień: które taski eskalowały i dlaczego → poprawka TEMPLATE / AGENTS.md
```

Krok 6 jest ważny: eskalacje to sygnał o jakości tasków. Jeśli >20% tasków taniego modelu eskaluje, taski są za duże albo za mało konkretne. Jeśli 0% i PR-y wymagają poprawek w review, wykonawca zgaduje zamiast stawać.

### Narzędzia, które to spinają (Phase 0)
| Narzędzie | Co robi |
|---|---|
| `make check` | wszystko, co robi CI, lokalnie, jedną komendą; wykonawca pętli do zielonego |
| `tools/tasks.py lint` | waliduje front-matter tasków, zależności (brak cykli), istnienie obszarów |
| `tools/tasks.py board` | tablica statusów z plików tasków |
| `tools/tasks.py plan` | taski `ready`, których zależności są `done`, a obszar i `touch` nie kolidują z taskami `in_progress` |
| `tools/check_scope.py` | CI: pliki zmienione w PR ⊆ `touch` taska z nazwy brancha |
| `tools/context_pack.py` | paczka kontekstu dla Sola (mapa repo, sygnatury `@api`, wskazane sekcje docs) |
| `tools/review_pack.py T-0123` | task + diff + odpowiednie sekcje docs → jedno wklejenie do review przez Sola |
