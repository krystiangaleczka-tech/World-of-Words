# 11 — Ryzyka, uproszczenia, fundamenty i plan faz

## 1. Główne ryzyka

| # | Ryzyko | Prawdop. | Skutek | Mitygacja |
|---|---|---|---|---|
| R1 | Integracje reklam/IAP/analityki w Godocie na iOS niestabilne | średnie | wysoki | spike S1 z kryterium porażki przed kodem produkcyjnym; adaptery z fake'ami; Unity jako plan B |
| R2 | Słownik PL niskiej jakości („dziwne słowa”) | wysokie bez kuracji | wysoki (główny wyróżnik) | tiery, klasyfikacja AI + Twoje review rozbieżności, pierwsze 100 leveli przegrane ręcznie, pętla invalid words |
| R3 | Generator robi poprawne, ale nudne levele | średnie | wysoki | metryki różnorodności, ręczne landmarki i onboarding, kalibracja telemetrią |
| R4 | Ty jako wąskie gardło review | wysokie | średni | review według ryzyka, `make check`, scope w CI, auto-merge low po okresie zaufania, limit torów |
| R5 | Taski Sola rozjeżdżają się z repo | wysokie bez narzędzi | średni | `context_pack`, sekcja Current state, preflight, fale |
| R6 | Ciche błędy tanich modeli (osłabione testy, scope creep) | średnie | średni | allowlista, licznik testów, checklista „co padnie po revercie” |
| R7 | Game feel przeciętny | średnie | bardzo wysoki | spike S2, bramka „fun gate” w Phase 1, iteracja na urządzeniu przez Ciebie |
| R8 | Scope creep meta-systemów | wysokie | wysoki | MVP z pocztówkami zamiast world-buildingu, eventy dopiero po danych retencji |
| R9 | Ekonomia/monetyzacja „uczciwa”, ale niedochodowa | średnie | wysoki | wszystko w configu, A/B przez buckety, decyzje na danych z soft launchu |
| R10 | Koszt i spójność grafiki | średnie | średni | jedna ilustracja na lokację, dokument stylu, selekcja przez Ciebie |
| R11 | Procesy sklepów (closed testing Play, review Apple, zgody) blokują kalendarz | wysokie | średni | założyć konta i zacząć closed test wcześnie (Phase 2), checklista zgodności |
| R12 | Utrata postępu gracza (zapis, zakupy) | niskie przy dobrym projekcie | bardzo wysoki | zapis atomowy, migracje ze złotymi plikami, idempotentne IAP, systemowy backup |
| R13 | Licencje (słownik, częstość, grafika AI, fonty) | średnie | wysoki | spike S3, decyzje w `docs/decisions/` |
| R14 | Nazwa za blisko „Words of Wonders” | średnie | średni | sprawdzenie znaków towarowych przed wyborem nazwy sklepowej |
| R15 | Modele mylą Godot 3/4 | wysokie | niski (łapie CI) | typowanie, ostrzeżenia jako błędy, lista pułapek w `AGENTS.md` |

## 2. Co warto uprościć (względem materiałów wejściowych)

| Zamiast | Robimy | Dlaczego |
|---|---|---|
| Słownik w runtime + walidacja w grze | paczki z gotowymi listami słów i bonusów | jedna logika (pipeline), brak normalizacji w grze |
| World-building ze zmieniającą się sceną | pocztówka lokacji odsłaniana za gwiazdki | 1/10 kosztu grafiki, ta sama pętla |
| Cloud save w MVP | zapis lokalny + systemowy backup; format gotowy do sync | zero backendu |
| Firebase Remote Config | statyczny JSON na CDN + buckety | brak SDK, prosty test |
| PL + EN od startu | pipeline wielojęzyczny, content: najpierw PL, EN gdy PL działa | jeden słownik do kuracji naraz |
| 15 dokumentów | `AGENTS.md` + 6 dokumentów + decyzje | brak sprzeczności |
| 50–70 tasków z góry | epiki + fale po 3–6 tasków | taski nie starzeją się |
| Deklarowane listy równoległości | wyliczane z `area`/`touch`/`depends_on` | brak ręcznej pracy, brak przeterminowania |
| Rozwiązywanie konfliktów przez tani model | ponowne wykonanie taska | brak cichych błędów merge |
| Opus jako główny projektant wielu obszarów | Opus jako druga opinia przy nieodwracalnym + fundament wizualny | niższy koszt, lepsza kontrola błędów |
| Wiele walut | monety + gwiazdki (postęp) | prostsza ekonomia |
| Orientacja dowolna / landscape | tylko pion | połowa pracy layoutu |
| iOS build na każdym PR | iOS nocnie i przed wydaniem | koszt minut macOS |
| Ochrona przed cofaniem zegara | brak (świadoma decyzja) | gra single-player |
| Walidacja zakupów na serwerze | lokalna weryfikacja podpisów | brak backendu, akceptowalne ryzyko |

## 3. Co trzeba zaprojektować dobrze od początku (drogie do zmiany później)

1. **Format zapisu**: wersjonowanie, migracje, zapis atomowy, sekcje pod przyszły sync, `install_id`.
2. **Przepływ IAP**: idempotencja po `transaction_id`, kolejność grant → zapis → finish, restore.
3. **Schemat danych levelu i polityka slotów**: niezmienne sloty po wydaniu, zmienne listy bonusów, wersja schematu.
4. **Granice warstw i zamknięta lista autoloadów**: najtańsze na początku, najdroższe do odkręcenia.
5. **Rejestry jako dane** (config, analityka, audio, lokalizacja per obszar).
6. **Nazwy eventów analitycznych**: zmiana nazwy zrywa ciągłość danych.
7. **Identyfikatory produktów IAP**: w sklepach nie da się ich ponownie użyć po usunięciu.
8. **Decyzje językowe** (diakrytyki, fleksja): zmieniają cały pipeline.
9. **Wstrzykiwanie czasu i losowości**: dopisywanie później oznacza przepisanie testów.
10. **Tokeny i komponenty przed ekranami produkcyjnymi.**
11. **Workflow i narzędzia** (`make check`, scope, `tasks.py`, `context_pack`): bez nich równoległa praca agentów się nie skaluje.
12. **Zgody (UMP/ATT) i prywatność**: wpływają na inicjalizację SDK i kolejność ekranów startowych.

---

## 4. Plan faz

Fazy są definiowane przez kryteria wyjścia, nie przez kalendarz.

### Phase 0 — Foundation
Cel: wszystko, co musi istnieć, zanim agenci zaczną seryjnie dowozić taski. **Praca szeregowa**, wykonywana przez Ciebie i Sola (agenta), z jedną sesją Opusa.

**A. Decyzje i dokumenty**
- [ ] `docs/decisions/0001-engine.md` (Godot warunkowo, po S1), `0002-content-in-packs`, `0003-local-date`, `0004-language-rules-pl`
- [ ] `PRODUCT.md` v1: filary, gracz docelowy, zakres faz, non-goals
- [ ] `GAME_DESIGN.md` v0: pętla rdzenia, klasy słów, reguły języka PL, power-upy, intencje ekonomii (szkic)
- [ ] `ARCHITECTURE.md` v1 (na bazie `03`), w tym lista obszarów i hotspotów
- [ ] `CONTENT.md` v0 (na bazie `09`), `TESTING.md` v1 (na bazie `08`), `DESIGN.md` v0 (tylko zasady)
- [ ] `AGENTS.md`, `tasks/TEMPLATE.md`, `EPIC_TEMPLATE.md`, szablon PR (z `seed/`)
- [ ] Opus: druga opinia na ARCHITECTURE + PRODUCT (jedna sesja)

**B. Spike'i (ograniczone czasowo, wynik = raport + decyzja)**
- [ ] **S1 platformowy** (patrz `02`): Android + iPhone, reklamy + UMP + ATT, IAP + restore, analityka, crash, haptyka. Kryterium porażki zdefiniowane z góry.
- [ ] **S2 swipe**: wyrzucany prototyp koła liter na urządzeniu; ocena opóźnienia i haptyki przez Ciebie.
- [ ] **S3 słownik**: źródła PL i ich licencje, liczba słów 3–7 liter, dostępność częstości i morfologii, próba klasyfikacji 200 słów tanim modelem (jakość + koszt).
- [ ] **S4 generator**: prototyp w Pythonie generujący 50 leveli z małej listy, render ASCII siatek, ocena jakości.
- [ ] **S5 Sol jako agent**: czy Twój plan ChatGPT pozwala Solowi pracować bezpośrednio na repo (np. Codex) i z jakimi limitami. Wynik zmienia podział `executor`.

**C. Repo i narzędzia**
- [ ] repo ze strukturą z `04`, przypięta wersja Godota, GUT, gdtoolkit, `uv` + pytest
- [ ] `Makefile`: `check`, `test`, `lint`, `fmt`, `run`, `context`, `review`
- [ ] `tools/tasks.py` (`lint`, `board`, `plan`), `tools/check_scope.py`, `tools/context_pack.py`, `tools/review_pack.py`
- [ ] CI z checkami z `07` §5 (bez iOS), branch protection, squash only
- [ ] obraz Docker / devcontainer z Godotem headless dla agentów w chmurze
- [ ] konta: Google Play Console i Apple Developer założone (weryfikacja tożsamości bywa powolna)

**D. Szkielet architektury (kontrakty, szeregowo, wykonawca: Sol)**
- [ ] katalogi warstw, autoloady jako stuby, `Platform` z fake'ami
- [ ] `Save` v1: schemat, zapis atomowy, kopia, framework migracji, złoty plik v1, testy
- [ ] loader rejestrów (`Config`, `Analytics`) z walidacją, testami i checkiem `registries` w CI
- [ ] schemat `LevelData` (JSON Schema) + loader `Content` + paczka-fixture + test bota
- [ ] `Nav`: Boot → Home (pusty) → Level (pusty) → Home; boot smoke test

**E. Próba generalna workflow**
- [ ] 3–4 małe taski (np. fake haptyki, ekran debug, test configu) wykonane przez tani model **równolegle**, przez pełny proces. Mierzymy: eskalacje, czerwone CI, czas Twojego review. Poprawiamy szablon i `AGENTS.md`.

**Kryteria wyjścia:** S1 przeszedł (albo zmieniono silnik); `make check` zielone w CI; tani model zrealizował ≥3 taski bez Twoich ręcznych poprawek kodu; dokumenty v1 zmergowane; decyzje językowe zapisane.

### Phase 1 — Core Prototype („czy to jest przyjemne?”)
Cel: minimalna grywalna pętla na telefonie. Surowy wygląd, perfekcyjny swipe.

**W zakresie:** koło liter (swipe, linia, cofanie, haptyka), siatka z danych, dopasowanie słów (level / bonus / już znalezione / invalid) z feedbackiem, ukończenie levelu i natychmiastowy następny, shuffle, hint (litera, darmowy), zapis postępu (slot), ekran debug (skok do levelu, podgląd odpowiedzi), placeholderowe SFX, **30–50 leveli PL** z pipeline v0 (z S4) + ~10 ręcznych, build Android z CI (APK lub internal testing), iOS opcjonalnie.

**Poza zakresem:** ekonomia, reklamy, IAP, mapa, daily, design system, analityka (obserwujesz ludzi osobiście).

**Tory równoległe:** `level.wheel` | `level.board` + `core/board` | `pipeline` | `features.debug`.

**Kryteria wyjścia („fun gate”):** 5 osób spoza projektu gra ≥20 minut bez instrukcji; swipe bez odczuwalnego opóźnienia na referencyjnym tanim Androidzie; **Twoja decyzja: idziemy dalej / poprawiamy rdzeń / kończymy.** Jeśli rdzeń nie jest przyjemny, nic z Phase 2 tego nie naprawi.

### Phase 2 — Vertical Slice (docelowa jakość, mały zakres)
Cel: pierwsze 30 minut gry wyglądają i działają jak gotowy produkt na Androidzie i iOS.

**W zakresie:**
- kierunek wizualny (Opus + Ty), tokeny, komponenty, galeria,
- pełny game feel ekranu levelu (animacje z `DESIGN.md#level-motion`, audio, haptyka),
- ekran główny, podróż dla 1 regionu (3–4 lokacje), pocztówki za gwiazdki,
- ekonomia v1 (monety, hint/reveal, nagrody, bonus chest) + `econ_sim.py`,
- onboarding pierwszych 15 leveli (ręczne levele, odblokowania z configu), druga opinia Opusa,
- ustawienia (dźwięk, haptyka, reduced motion, język),
- analityka z rejestrem i lejkiem onboardingu, remote config + buckety,
- reklamy (rewarded + interstitial wg `ad_policy`) + UMP + ATT, IAP: Remove Ads + 1 paczka monet + restore,
- lokalizacja UI PL + EN (content EN opcjonalnie),
- 150–200 leveli PL z pipeline'u w jakości produkcyjnej (tiery, klasyfikacja, review),
- start closed testing w Google Play (wymóg testerów i czasu), TestFlight.

**Kryteria wyjścia:** checklista urządzeń z `TESTING.md` przechodzi na 3 urządzeniach referencyjnych; IAP i reklamy działają w sandboxie; Opus robi audyt slice'a (UX, ekonomia, architektura) i nie ma krytycznych uwag; Twoja ocena „to wygląda jak gra, którą sam bym ściągnął”.

### Phase 3 — Production
Cel: maszyna do seryjnej produkcji contentu i funkcji, potem soft launch i pętla na danych.

**System produkcji:**
- pipeline w pełnej wersji: wszystkie etapy z `09`, raport QA, tryb przeglądu leveli w grze, plik blokady wydanych slotów,
- 1000+ leveli PL, potem EN (osobna kuracja, native speaker),
- pipeline grafiki lokacji (dokument stylu, selekcja),
- release pipeline: podpisane AAB do Play internal track, iOS do TestFlight z CI (macOS),
- stały rytm pracy (poniżej).

**Funkcje (kolejno, każda jako epik):** daily challenge + kalendarz miesiąca, streak + freeze, kolejne regiony, kolekcja pocztówek, landmarki, A/B na bucketach, powiadomienia lokalne (opcjonalnie), jeden szablon eventu, cloud save (gdy dane pokażą potrzebę).

**Soft launch:** po daily + streak + ~500 leveli. Rynek do Twojej decyzji (PL jako tani rynek testowy we własnym języku vs anglojęzyczny rynek tier-2 dla danych bliższych docelowym). Najpierw D1 i onboarding, potem skala contentu (zgodnie z materiałami wejściowymi; to dobra zasada).

**Rytm stanu ustalonego (propozycja):**
| Kiedy | Co | Kto |
|---|---|---|
| początek tygodnia | metryki + otwarte problemy → epiki/fale | Sol (+ Ty decydujesz) |
| codziennie | `tasks.py plan` → agenci → review → merge | agenci, Sol, Ty |
| koniec tygodnia | build na urządzenia, checklista, wydanie wewnętrzne | Ty |
| co tydzień | przegląd eskalacji → poprawki szablonu/`AGENTS.md` | Sol |
| raz na fazę / miesiąc | audyt architektury, UX, ekonomii na zwartej paczce stanu | Opus |
