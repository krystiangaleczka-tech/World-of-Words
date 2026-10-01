# 01 — Krytyka materiałów wejściowych i Twojego podejścia

Materiał wejściowy: `project-word-research_1.md`, `project_word_research_2.md`, `project_word_game_research_3.md`, `ai_workflow_words_game.md`.

Trzy pliki researchowe pokrywają się w ok. 70% (ten sam konkurencyjny teardown, ta sama wizja, ten sam MVP). Dają dobry obraz *produktu*, ale prawie nic nie mówią o tym, *jak* go zbudować. Plik o workflow AI mówi o procesie, ale zakłada, że największym problemem jest koszt tokenów. Uważam, że to błędne założenie (patrz §3).

---

## 1. Co jest dobre i zostaje

| Pomysł | Dlaczego zostaje |
|---|---|
| Słownik jako przewaga, nie generowany przez LLM | To prawda i to jest najtrudniejsza część produktu. LLM nie może być źródłem prawdy o tym, co jest słowem. |
| Trzy klasy słów (level / bonus / invalid) | Proste, a usuwa największy pain point rynku („moje poprawne słowo nie zostało uznane”). |
| Generator zamiast ręcznych leveli | Konieczność przy tysiącach poziomów. |
| Trudność falująca, a nie liniowa | Dobry instynkt. Zostaje jako framework krzywej trudności. |
| Offline-first, brak LLM w runtime | Zero kosztu per użytkownik, deterministyczność. Bez dyskusji. |
| Pierwsze minuty bez popupów i reklam | Tani w realizacji i mocny wyróżnik. |
| Remote config dla częstotliwości reklam | Tak, ale prościej niż Firebase (patrz 03). |
| „Najpierw 500 dobrych leveli, potem skala” | Tak. Pipeline jakości przed ilością. |
| Milestone 0 „czy swipe jest przyjemny?” z dokumentu 3 | Najlepsza pojedyncza decyzja we wszystkich czterech plikach. Przejmuję ją jako bramkę „fun gate” w Phase 1. |
| Zasada: tani model nie podejmuje decyzji | Słuszna, ale wymaga mechanizmów wymuszania (CI), a nie tylko reguł tekstowych. |
| „AI #1 implementuje, AI #2 recenzuje” | Tak, i to najlepiej z *innej rodziny modeli* (patrz §3.6). |

## 2. Co jest słabe, ryzykowne albo niepotrzebne

### 2.1 Sprzeczny stack
Pliki 1–3 rekomendują **Unity 6 + C#**, plik o workflow rekomenduje **Godot 4 + GDScript**. Żaden nie porównuje ich pod kątem pracy agentów, CI i integracji platformowych. Rozstrzygam to w `02-technologia.md`.

### 2.2 MVP jest za duże
„MVP w 5–8 tygodni” zawiera: dwa słowniki, generator, 500 leveli, mapę z 3 regionami, world-building, daily, streak, rewarded i interstitial, Remove Ads, analytics, cloud save, Android, iOS i iPad. To nie jest MVP, to wersja 1.0. Każda z tych pozycji ma ukryty koszt, którego dokumenty nie widzą:

- **World-building** (scena się zmienia: kawiarnia, drzewa, fontanna) to *koszt artystyczny* razy liczba lokacji. Przy 3 regionach × 4 miejscach × 3 etapach to 36 wariantów ilustracji w spójnym stylu. Żaden dokument nie wspomina o pipeline grafiki. **Uproszczenie:** w MVP jedna ilustracja na lokację, odsłaniana kawałkami (pocztówka-układanka) za gwiazdki. Ta sama pętla motywacyjna przy ~1/10 kosztu grafiki.
- **Cloud save** wymaga backendu albo integracji Play Games / iCloud na dwóch platformach. **Uproszczenie:** w MVP zapis lokalny trzymany w miejscu objętym systemowym backupem (Android Auto Backup, backup iCloud urządzenia). To pokrywa główny przypadek „zmieniłem telefon” za darmo. Prawdziwa synchronizacja dopiero, gdy dane pokażą potrzebę. Format zapisu od pierwszego dnia projektuję tak, żeby sync dało się dodać.
- **Dwa języki od startu** oznaczają dwa słowniki, dwie kuracje i dwóch native speakerów do review. Architektura ma wspierać wiele języków od początku, ale content drugiego języka to osobna decyzja.

### 2.3 Brakujące tematy (realne ryzyka, których dokumenty nie widzą)

| Brak | Dlaczego to ważne |
|---|---|
| **Zgody GDPR (UMP/CMP) i ATT** | Polska to UE. AdMob w EOG wymaga certyfikowanego CMP (Google UMP). iOS wymaga ATT dla IDFA. Bez tego reklamy nie ruszą zgodnie z zasadami. |
| **Wymóg testów zamkniętych w Google Play** | Nowe osobiste konta deweloperskie muszą przeprowadzić closed test (ostatnio 12 testerów przez 14 dni, sprawdź aktualne zasady) przed dostępem do produkcji. To blokuje kalendarz soft launchu. |
| **Licencje słowników i danych częstości** | Np. dane `wordfreq` są na CC BY-SA. Słownik SJP.pl ma kilka licencji do wyboru. Trzeba to sprawdzić przed zbudowaniem pipeline, nie po. |
| **Polska fleksja i diakrytyki** | Czy `Ą`, `Ł` są osobnymi literami na kole? Czy `DOMY` jest słowem levelowym, bonusowym, czy niczym? To decyzje produktowe, które zmieniają cały pipeline. Muszą zapaść w Phase 0. |
| **Idempotentność zakupów** | Crash między zakupem a zapisem waluty = utracone pieniądze gracza albo podwójne przyznanie. Dokumenty wspominają tylko „restore purchases”. |
| **Pipeline grafiki** | Tła lokacji, ikony, scena world-building. Nikt tego nie planuje, a to może być największy koszt produkcji po słowniku. |
| **Nazwa** | „World of Words” jest bardzo blisko „Words of Wonders”. Przed premierą sprawdzić ryzyko pomylenia znaków towarowych w sklepach. |
| **Kalibracja trudności danymi** | Difficulty score bez pętli zwrotnej z telemetrii to zgadywanie. |

### 2.4 „TASKS.md z 50–70 taskami”
Pliki 1 i 2 sugerują wygenerowanie od razu 50–70 tasków w jednym pliku. Odrzucam oba elementy:
- jeden plik edytowany przez każdy PR to gwarantowany konflikt przy równoległej pracy,
- 70 tasków napisanych z góry zestarzeje się po pierwszych 10 merge'ach (zmienią się nazwy, API, struktura).

Zamiast tego: planowanie falami (patrz `05-workflow-ai.md`).

### 2.5 Harmonogramy tygodniowe
„Tydzień 6: ads + IAP + save + analytics” to optymizm. Integracje platformowe na dwóch systemach, konta w sklepach, sandboxy, zgody i testy na urządzeniach są najmniej przewidywalną częścią mobilnego projektu i *nie przyspieszają od AI*. Fazy w `11-ryzyka-i-fazy.md` definiuję przez kryteria wyjścia, nie przez tygodnie.

### 2.6 Za dużo dokumentów
Pliki proponują łącznie ok. 15 różnych dokumentów (PRD, GAME_DESIGN, ECONOMY, MONETIZATION, UX_FLOWS, DATA_MODEL, LEVEL_GENERATOR, DICTIONARY_PIPELINE, ANALYTICS_PLAN, RELEASE_PLAN…). Ekonomia, monetyzacja i game design to jeden system; rozdzielenie ich na trzy dokumenty gwarantuje sprzeczności. Konsoliduję to do 6 dokumentów + `AGENTS.md` (patrz `04-repo-i-dokumenty.md`).

### 2.7 Przykładowy TASK042 (shuffle)
Dobry kierunek, ale pokazuje typowe dziury:
- `DO NOT MODIFY: WordValidator, LevelRepository…` to lista zabronionych *nazw*. Lista zakazów jest z natury niepełna i nie da się jej sprawdzić automatycznie. Lepsza jest **lista dozwolonych ścieżek** egzekwowana w CI.
- „150–220 ms” to decyzja zostawiona wykonawcy. Powinno być `Motion.FAST` z tokenów.
- Testy opisane prozą („verify the same letters remain”) zamiast konkretnych przypadków z wartościami wejścia i wyjścia.
- Brak sekcji „stan obecny”: jakie klasy i sygnatury już istnieją. To jest główne źródło halucynacji tanich modeli.
- `res://ui/icons/shuffle.svg` jako plik do stworzenia: tani model nie narysuje dobrej ikony. Asset musi być dostarczony albo wzięty z zestawu ikon.
- Brak edge case'u „shuffle dał ten sam układ” i „wszystkie litery identyczne”.

Poprawiona wersja tego taska jest w `06-standard-taskow.md` jako wzorzec.

---

## 3. Krytyka Twojego modelu pracy „Opus planuje → Sol taskuje → Flash implementuje”

Model jest rozsądny jako punkt wyjścia, ale ma sześć słabych punktów. Niektóre są poważne.

### 3.1 Optymalizujesz złą zmienną
Koszt tokenów tanich modeli wykonawczych przy tym projekcie to grosze na task. Koszt Sola w ChatGPT jest praktycznie stały. **Najdroższym i najrzadszym zasobem jest Twoja uwaga**: review, merge, testy na urządzeniu, decyzje produktowe, wklejanie kontekstu między narzędziami. Przy 5–10 równoległych agentach to Ty jesteś wąskim gardłem, nie modele.

Wniosek: workflow projektuję tak, żeby minimalizować *liczbę Twoich interwencji na zmergowany task*, a dopiero potem koszt API. Konkretnie: automatyczne sprawdzanie zakresu zmian, `make check` jako jedna komenda prawdy, review różnicowane po ryzyku, auto-merge dla niskiego ryzyka po okresie zaufania.

### 3.2 Podatek od specyfikacji
Żeby tani model wykonał task „przy minimalnej liczbie decyzji”, task musi zawierać prawie cały projekt rozwiązania. Napisanie takiej specyfikacji to często 50–80% wysiłku samej implementacji. Dla zadań typu „zmień 40 linii w jednym pliku” bywa taniej, żeby **Sol od razu napisał kod**.

**Ważne:** jeśli Twój plan ChatGPT daje dostęp do agenta kodującego (np. Codex) z tym modelem i limitem praktycznie stałym, to Sol może implementować sporą część tasków sam, a tanie modele zostają dla pracy mechanicznej i masowej. Sprawdź to w Phase 0; to może zmienić podział pracy bardziej niż cokolwiek innego w tym dokumencie. Workflow, który proponuję, działa w obu wariantach, bo task nie zakłada, kto go wykona (pole `executor`).

### 3.3 Sol w ChatGPT nie widzi repo
Taski pisane z pamięci rozmowy zamiast z aktualnego stanu repo będą miały złe ścieżki, nieistniejące metody, nieaktualne sygnatury. Tani model albo zhalucynuje brakujący kod, albo zbuduje go od zera obok istniejącego.

**Rozwiązanie:** skrypt `tools/context_pack.py`, który generuje paczkę kontekstu (mapa repo, publiczne API, odpowiednie sekcje dokumentów) do wklejenia albo załączenia w ChatGPT. Każdy task ma sekcję „Current state” z sygnaturami, a wykonawca zaczyna od *preflight*: sprawdza, czy to, co task opisuje, istnieje. Jeśli nie, staje.

### 3.4 Taski hurtowo = taski nieaktualne
Fala 10 tasków napisanych naraz zestarzeje się, gdy pierwsze 3 zostaną zmergowane. **Rozwiązanie:** epik planowany w całości (decyzje, kontrakty), taski rozpisywane falami po 3–6, każda fala na świeżym stanie `main`.

### 3.5 Gdzie tani model popełni drogie błędy
Nie w złożonej logice (tam zwykle polegnie widocznie i testy to złapią), tylko w cichych błędach:

| Błąd | Mechanizm ochronny |
|---|---|
| Osłabia albo usuwa test, żeby przeszedł | Testy spoza listy dozwolonych plików są nietykalne (CI); liczba testów nie może spaść |
| „Przy okazji” refaktoruje sąsiedni kod | Allowlista ścieżek w CI |
| Używa API Godot 3 (`yield`, `export var`, `KinematicBody2D`) | Typowany GDScript z ostrzeżeniami jako błędami, lista pułapek w `AGENTS.md` |
| Edytuje ręcznie `.tscn` i psuje identyfikatory zasobów | Małe sceny, import headless w CI wykrywa zepsute sceny |
| Rozwiązuje konflikt, wyrzucając zmiany drugiej strony | Zasada „nie rozwiązuj, uruchom ponownie” (patrz `07-git-pr-merge.md`) |
| Zmienia format zapisu bez migracji | Złote pliki zapisu w testach; zmiana schematu = task wysokiego ryzyka |
| Losowość bez ziarna w generatorze | Testy determinizmu w pipeline |
| Czas lokalny vs UTC w daily/streak | Zegar wstrzykiwany, testy granic dnia |
| Wymyśla nazwy eventów analitycznych | Rejestr eventów + test zgodności |
| Dodaje zależność albo plugin | Zmiana `addons/` poza allowlistą blokowana |

### 3.6 Review przez AI ma ślepe plamki
Model recenzujący własny kod, albo kod modelu z tej samej rodziny, ma skorelowane błędy. Dlatego wartość Opusa w Twoim zestawie to nie tyle „lepsza jakość”, ile **niezależna druga opinia z innej rodziny modeli**. Proponuję używać Opusa głównie jako recenzenta decyzji Sola w nieodwracalnych sprawach, a nie jako głównego autora (patrz `05-workflow-ai.md`).

Rzeczy, których żadne AI w tym procesie nie zauważy, bo wymagają urządzenia albo człowieka:
- opóźnienie swipe'a i jakość haptyki,
- czy polskie słowo jest „dziwne”, archaiczne albo ma niefortunne drugie znaczenie,
- czy ekonomia „czuje się” uczciwie po 200 levelach,
- wygląd na małym Androidzie i iPhonie z wycięciem,
- zachowanie SDK reklam (fill rate, crashe, ANR-y),
- dark patterns i zgodność z politykami sklepów.

### 3.7 Gdzie powstanie największy dług techniczny
1. **Sceny UI** budowane ekran po ekranie z ręcznie ustawionymi kolorami i odstępami. Lekarstwo: tokeny i biblioteka komponentów przed pierwszym ekranem produkcyjnym (Phase 2).
2. **Singletony-bogowie** (`Game.gd` na 2000 linii) i sygnałowe spaghetti przez globalny event bus. Lekarstwo: zamknięta lista autoloadów, logika w czystych klasach, event bus tylko dla efektów ubocznych.
3. **Pipeline contentu jako zbiór jednorazowych skryptów.** Lekarstwo: etapy z wersjonowanymi artefaktami i testami od początku.
4. **Płytkie testy pisane przez tanie modele** (testują mocki, nie zachowanie). Lekarstwo: przypadki testowe definiuje Sol w tasku, wykonawca je tylko implementuje.
5. **Rozjazd dokumentacji z kodem.** Lekarstwo: mało dokumentów, rejestry jako dane, a nie jako tekst.

### 3.8 Co nie nadaje się do pracy równoległej
- szkielet architektury i kontrakty (zapis, schemat danych leveli, lista serwisów),
- dopracowanie game feel ekranu levelu (iteracja człowiek + urządzenie),
- fundament design systemu,
- integracje reklam i IAP (sekwencyjne, z testami na urządzeniu),
- ręczne pierwsze 20–30 leveli i onboarding,
- konfiguracja sklepów i podpisywania.

Realnie: **2–3 równoległe tory w Phase 1, 4–6 w Phase 3.** 10 agentów naraz ma sens dopiero przy masowej pracy z niezależnymi obszarami (content, testy, lokalizacja, osobne ekrany), i nadal ogranicza to Twoja przepustowość review.

### 3.9 Co wymaga człowieka (Ciebie albo kogoś zatrudnionego)
- review słownika przez native speakera (PL: Ty; EN: ktoś inny),
- akceptacja game feel na urządzeniu,
- kierunek artystyczny i selekcja grafik,
- playtesty pierwszych 10 minut z prawdziwymi ludźmi (choćby 5 znajomych),
- konta sklepów, podpisy, polityka prywatności, zgody, ceny,
- decyzja go/no-go przy każdym wydaniu.
