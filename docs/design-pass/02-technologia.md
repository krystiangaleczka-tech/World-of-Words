# 02 — Wybór technologii

Porównanie dotyczy tylko tego projektu: gra 2D, w dużej mierze UI (koło liter, siatka, menu, sklep, mapa), mocny nacisk na game feel, reklamy + IAP + analytics na Androidzie i iOS, praca głównie przez agentów AI, jedna osoba zarządzająca.

## 1. Porównanie

Skala: ++ bardzo dobrze, + dobrze, 0 neutralnie, − słabo, −− bardzo słabo.

| Kryterium | Godot 4 + GDScript | Unity 6 + C# | Kotlin/Compose Multiplatform |
|---|---|---|---|
| **Praca agentów AI: format plików** | ++ wszystko tekstowe: `.gd`, `.tscn`, `.tres`, czytelne diffy | −− sceny i prefaby to YAML z GUID-ami i plikami `.meta`; agenci nie edytują ich niezawodnie, konflikty w scenach są koszmarem | ++ czysty kod, UI w kodzie |
| **Praca agentów AI: znajomość języka** | − mniejszy korpus treningowy, modele mylą API Godot 3 i 4 | ++ C# i Unity bardzo dobrze znane | ++ Kotlin bardzo dobrze znany; Compose MP na iOS mniej |
| **Ilość boilerplate'u** | ++ GDScript zwięzły, mało ceremonii | 0 MonoBehaviour, serializacja, asmdefy | − expect/actual, wrappery na Swift SDK |
| **Game feel, animacje, particles, shadery** | + Tweeny, AnimationPlayer, particles, shadery 2D | ++ najmocniejszy ekosystem (DOTween, VFX) | − animacje UI świetne, ale particles i efekty trzeba pisać ręcznie na Canvasie |
| **Android** | + eksport bez licencji, z Linuksa | + dojrzały | ++ natywny |
| **iOS** | 0 eksport do projektu Xcode, działa; pluginy iOS to najsłabszy punkt | + dojrzały | − Kotlin/Native, interop ze Swift SDK, wolne buildy |
| **Reklamy (AdMob + mediacja, UMP)** | − pluginy społeczności (np. Poing Godot AdMob); trzeba zweryfikować stan na dziś | ++ oficjalne SDK (LevelPlay, AdMob Unity plugin) | 0 Android natywnie ++, iOS przez wrappery − |
| **IAP** | − Android: oficjalny plugin Play Billing; iOS: pluginy o zmiennej kondycji | ++ Unity IAP obsługuje obie platformy | 0 Android ++, iOS StoreKit przez wrapper − |
| **Analytics / crash** | − Firebase przez pluginy albo analityka przez HTTP; Sentry ma SDK dla Godota (sprawdzić iOS) | ++ Firebase, wszyscy dostawcy | + Android ++, iOS przez GitLive/wrappery |
| **CI/CD** | ++ headless Godot na Linuksie, bez licencji, szybki | − aktywacja licencji w CI (GameCI), cache `Library/`, długie buildy | + Gradle na Linuksie, iOS wymaga macOS |
| **Testy** | + GUT / gdUnit4 headless; czysta logika testuje się szybko | + Unity Test Framework, ale wolny start edytora | ++ testy JVM w milisekundach |
| **Wielkość projektu i repo** | ++ małe repo, brak `Library/` | − ciężki folder projektu, długi import | + |
| **Rozmiar aplikacji** | 0 porównywalny z Unity (kilkanaście–kilkadziesiąt MB) | 0 | + najmniejszy |
| **Szybkość iteracji** | ++ edytor startuje w sekundy, uruchomienie sceny natychmiast | − domain reload, import, długie buildy | + Android szybko, iOS wolno |
| **Ryzyko platformowe** | − pluginy reklam/IAP/analityki, wsparcie iOS | + niskie dla SDK; ryzyko polityk licencyjnych firmy (historia z 2023) | − Compose iOS młodszy, interop |
| **Koszt utrzymania** | + darmowy, MIT, brak licencji | 0 darmowy do progu przychodu, ale ciężkie aktualizacje | 0 dwie platformy pod spodem |

## 2. Wnioski z porównania

**KMP/Compose** odpada. Dla gry-UI byłby zaskakująco dobry na Androidzie, ale iOS (reklamy, StoreKit, Firebase przez wrappery Kotlin/Native) i brak narzędzi do game feel (particles, shadery, timeline animacji) to dwa największe obszary ryzyka tego projektu jednocześnie.

**Unity** wygrywa na integracjach platformowych i znajomości języka przez modele. Przegrywa tam, gdzie ten projekt jest najbardziej wrażliwy: agenci AI nie umieją niezawodnie edytować scen i prefabów, konflikty w scenach przy pracy równoległej są realne, CI wymaga licencji i jest wolne, iteracja jest wolniejsza. Projekt prowadzony przez flotę agentów na małych PR-ach to dokładnie ten scenariusz, w którym te wady bolą najbardziej.

**Godot** wygrywa na wszystkim, co dotyczy przepływu pracy agentów (pliki tekstowe, zwięzły kod, darmowe szybkie CI, mały projekt, szybka iteracja) i daje wystarczający game feel dla gry 2D. Ma dwie realne słabości:
1. **integracje platformowe** (reklamy, IAP na iOS, analityka, crash reporting),
2. **słabsza znajomość Godot 4 przez modele** (mylenie z Godot 3).

Druga słabość jest do opanowania: typowany GDScript z ostrzeżeniami jako błędami, lista pułapek w `AGENTS.md`, lint i import headless w CI. Pierwsza wymaga dowodu, nie wiary.

## 3. Decyzja

**Godot 4 (przypięta konkretna wersja 4.x.y, najnowsza stabilna w momencie Phase 0) + typowany GDScript**, z warunkiem:

> **Spike platformowy w Phase 0 musi przejść, zanim powstanie kod produkcyjny.**
> Na prawdziwym urządzeniu Android i iPhone: rewarded ad + interstitial (testowe jednostki AdMob) z formularzem zgody UMP, zakup non-consumable + consumable + restore w sandboxie (Play Billing i StoreKit), event analityczny widoczny w panelu, raport crasha widoczny w panelu, haptyka na iOS.
>
> **Kryterium porażki:** jeśli którakolwiek z integracji reklam lub IAP na iOS wymaga pisania własnego natywnego pluginu od zera albo nie działa stabilnie, wracamy do decyzji i rozważamy Unity 6 LTS. Prawie wszystko inne z tego dokumentu (pipeline contentu w Pythonie, format danych, workflow, dokumenty, testy logiki) przeżyje taką zmianę.

Dlaczego nie C# w Godocie: wsparcie .NET na mobile w Godot 4 jest mniej dojrzałe (iOS długo jako eksperymentalny), a połowę zalet Godota (zwięzłość, szybkość iteracji, brak kompilacji) się traci.

### Konsekwencje decyzji dla architektury
- **Każda usługa platformowa za cienkim adapterem z wersją fake.** Gra działa w edytorze i testach bez żadnego SDK. Jeśli plugin okaże się zły, wymieniamy jeden plik.
- **Logika gry w czystych klasach GDScript (`RefCounted`)**, niezależnych od drzewa scen. Testuje się headless w sekundach i da się ją przepisać 1:1 na C#, gdyby trzeba było zmienić silnik.
- **Pipeline contentu w Pythonie, poza Godotem.** Runtime dostaje gotowe dane (patrz `09-content-pipeline.md`).
- **Remote config jako statyczny JSON z CDN zamiast Firebase Remote Config.** Jeden plugin mniej, działa identycznie wszędzie, łatwy do testowania (patrz `03-architektura-gry.md`).
- **Analityka przez fasadę z adapterem.** Dostawcę wybiera spike: Firebase przez plugin, jeśli działa stabilnie na obu platformach; w przeciwnym razie PostHog lub podobny przez zwykłe HTTP (zero natywnego kodu). Jeśli planujesz płatne kampanie UA w Google Ads, Firebase jest praktycznie potrzebny do mierzenia konwersji w aplikacji; to argument za nim.

## 4. Pozostały stack

| Obszar | Wybór | Uzasadnienie |
|---|---|---|
| Silnik | Godot 4.x.y (przypięta) | j.w. |
| Język gry | GDScript, typowany, `untyped_declaration` jako błąd | mniej halucynacji, czytelniejsze błędy dla tanich modeli |
| Lint / format | `gdtoolkit` (`gdlint`, `gdformat`) | jedna komenda, deterministyczny styl |
| Testy gry | GUT (headless) | prosty, dojrzały, działa z CLI; gdUnit4 jako równorzędna alternatywa, wybrać jedną |
| Pipeline contentu | Python 3.12+, `uv`, `pytest`, `hypothesis` | najlepsze narzędzia do danych, modele znają go najlepiej |
| Dane leveli | JSON + JSON Schema | neutralne językowo, diffowalne, walidowane po obu stronach |
| Reklamy | AdMob + mediacja (później), UMP do zgód | standard rynku, wymóg EOG |
| IAP | Play Billing (oficjalny plugin Godot) + StoreKit (plugin, weryfikacja w spike) | |
| Crash | wg spike'a (Firebase Crashlytics albo Sentry) | |
| Remote config | statyczny JSON na CDN (np. GitHub Pages, Cloudflare R2) + domyślne wartości w buildzie | brak SDK, A/B przez hash identyfikatora instalacji |
| Backend | **brak** do czasu udowodnionej potrzeby | |
| CI | GitHub Actions; Linux dla wszystkiego, macOS tylko dla buildów iOS (nocne / release, bo minuty macOS są drogie w prywatnym repo) | |
| Dystrybucja | fastlane albo równoważne do Play internal track i TestFlight (Phase 3) | |
| Środowisko agentów | obraz Docker / devcontainer z Godot headless, GUT, gdtoolkit, Python | agenci w chmurze mogą uruchamiać `make check` |
