# 04 — Struktura repozytorium i dokumenty źródłowe

## 1. Struktura repo

```
/
├── AGENTS.md                 # JEDYNY plik, który każdy agent czyta zawsze (≤ ~200 linii)
├── CLAUDE.md / GEMINI.md     # jedna linia: "Read AGENTS.md"
├── README.md                 # dla ludzi: jak uruchomić
├── Makefile                  # make check | test | lint | fmt | run | content | context T=…
├── docs/
│   ├── PRODUCT.md
│   ├── GAME_DESIGN.md
│   ├── ARCHITECTURE.md
│   ├── CONTENT.md
│   ├── DESIGN.md
│   ├── TESTING.md
│   └── decisions/            # 0001-engine-godot.md, 0002-local-date-for-daily.md …
├── tasks/
│   ├── TEMPLATE.md
│   ├── EPIC_TEMPLATE.md
│   ├── epics/                # E04-hints.md …
│   └── T-0123-wheel-shuffle.md   # płasko; status w front-matter
├── game/                     # projekt Godota (project.godot tutaj, nie w root)
│   ├── core/                 # czysta logika, per domena: board/, economy/, ad_policy/, streak/ …
│   ├── services/             # autoloady (zamknięta lista)
│   ├── platform/             # adaptery: ads/, iap/, analytics/, crash/, consent/, haptics/ + fake/
│   ├── features/             # level/, home/, journey/, daily/, shop/, settings/, debug/
│   ├── ui/                   # theme/, tokens.gd, components/, gallery/
│   ├── data/                 # config/*.json, analytics/*.json, audio/*.json
│   ├── content/              # GENEROWANE przez pipeline: <lang>/manifest.json, packs/*.json
│   ├── assets/               # art/, audio/, fonts/, icons/
│   ├── locale/               # <area>.csv
│   ├── addons/               # gut, pluginy platformowe (zmiana = eskalacja)
│   └── tests/                # unit/ (mirror core/), integration/, fixtures/
├── pipeline/                 # Python: content pipeline
│   ├── src/wordgame_pipeline/
│   ├── config/               # <lang>.yaml, curve.yaml, scoring.yaml
│   ├── overrides/            # <lang>.csv — ręczne decyzje o słowach (najwyższy priorytet)
│   ├── sources/              # skrypty pobierania + sumy kontrolne (surowe dane nie w git)
│   ├── cache/                # cache klasyfikacji LLM (commitowany, patrz 09)
│   └── tests/
├── tools/                    # tasks.py, check_scope.py, context_pack.py, review_pack.py, econ_sim.py
└── .github/
    ├── workflows/            # ci.yml, build-android.yml, build-ios.yml (nocny/release)
    └── pull_request_template.md
```

### Uzasadnienie najważniejszych decyzji
- **Projekt Godota w `game/`, nie w root.** Godot importuje wszystko w katalogu projektu; środowisko Pythona, pipeline i narzędzia nie mają tam czego szukać.
- **`core/` per domena, `features/` per ekran.** Logika jest współdzielona między ekranami (ekonomia używana w sklepie i w levelu), UI nie.
- **Testy w `game/tests/` jako lustro `core/`.** GUT wymaga ich wewnątrz projektu; lustro ułatwia agentom znalezienie właściwego pliku.
- **Rejestry jako katalogi** (`data/config/`, `data/analytics/`, `locale/`, `docs/decisions/`). Pojedynczy plik-lista edytowany przez wiele tasków to najczęstsze źródło konfliktów.
- **Taski płasko w `tasks/`, status w front-matter.** Przenoszenie plików między folderami statusów generuje konflikty rename; tablicę generuje `tools/tasks.py board`.
- **Content generowany jest commitowany.** To dane, które trafiają do gry; muszą być widoczne w review i odtwarzalne. Zmienia je wyłącznie pipeline w taskach typu `content`.
- **Bez Git LFS na start.** Do repo trafiają tylko gotowe, skompresowane assety (WebP, OGG); pliki źródłowe grafiki (PSD itp.) poza repo. Wrócić do tematu, gdy repo przekroczy ~500 MB.

### Pliki-hotspoty (zmieniane tylko przez taski `infra`/`contract`, szeregowo)
`game/project.godot`, `game/export_presets.cfg`, lista autoloadów, `game/services/save.gd` (schemat), schemat `LevelData`, `.github/workflows/*`, `Makefile`, `game/addons/*`.

## 2. Dokumenty: source of truth

Zasada: **każdy fakt ma jeden dom.** Inne miejsca linkują do sekcji (`GAME_DESIGN.md#hints`), nie powtarzają treści. Liczby żyją w `data/config`, nie w dokumentach.

| Dokument | Zawartość | Zastępuje z propozycji | Kto pisze / zmienia |
|---|---|---|---|
| `AGENTS.md` | streszczenie projektu (10 linii), mapa repo, komendy, zasady kodu, pułapki Godot 4, workflow branch/commit/PR, **reguły STOP i eskalacji**, Definition of Done | CODING_RULES, AI_RULES, AI_ESCALATION, część TESTING | Sol, zatwierdza Ty |
| `docs/PRODUCT.md` | wizja, gracz docelowy, filary, wyróżniki, zakres per faza (in/out), non-goals, KPI | PRD, RELEASE_PLAN (część) | Ty + Sol, Opus jako druga opinia |
| `docs/GAME_DESIGN.md` | pętla rdzenia, klasy słów, reguły języka (diakrytyki, fleksja), power-upy, progresja, meta, daily/streak, onboarding, **intencje ekonomii**, zasady monetyzacji, lista produktów IAP | GAME_DESIGN, ECONOMY, MONETIZATION | Ty + Sol; zmiany ekonomii i onboardingu z drugą opinią Opusa |
| `docs/ARCHITECTURE.md` | warstwy, reguły zależności, lista autoloadów, moduły, przepływy (level, IAP, save), formaty danych, adaptery, rejestry, niezmienniki | ARCHITECTURE, DATA_MODEL | Sol; zmiany niezmienników z drugą opinią Opusa |
| `docs/CONTENT.md` | pipeline słownika i leveli, schemat danych levelu, reguły tierów słów, polityka slotów (niezmienność po wydaniu), proces QA contentu | LEVEL_GENERATOR, DICTIONARY_PIPELINE, WORD_ENGINE | Sol |
| `docs/DESIGN.md` | zasady wizualne, odniesienie do tokenów (`tokens.gd`), katalog komponentów, ruch, layout i safe areas, dostępność, **mapa ekranów i przepływy UX**, format specyfikacji ekranu | DESIGN_SYSTEM, UX_FLOWS | Opus + Ty (fundament), potem Sol |
| `docs/TESTING.md` | piramida testów, co testujemy czym, checklista urządzeń, checklista wydania | TESTING, QA_PLAN | Sol |
| `docs/decisions/NNNN-*.md` | decyzje: kontekst, decyzja, alternatywy, „wróć do tematu, jeśli…” | (nowy) | ktokolwiek decyduje, zatwierdza Ty |
| `tasks/TEMPLATE.md`, `EPIC_TEMPLATE.md` | standard tasków | TASK_TEMPLATE | |

**Usunięte bez zamiennika:** `ANALYTICS.md` (rejestr eventów jest w danych, KPI w PRODUCT), `TASKS.md` (taski to pliki, tablica generowana).

### Zasady utrzymania dokumentów
1. **Język:** dokumenty czytane przez agentów (`AGENTS.md`, `ARCHITECTURE.md`, `CONTENT.md`, `TESTING.md`, taski) piszemy **po angielsku**. Tanie modele trzymają się angielskich instrukcji pewniej, a polski tekst kosztuje więcej tokenów w każdym wywołaniu. `PRODUCT.md` i `GAME_DESIGN.md` mogą być po polsku, jeśli tak Ci wygodniej, ale reguły, na które powołują się taski, warto mieć po angielsku.
2. **Wykonawcy nie edytują dokumentów.** Jedyny wyjątek: status we własnym pliku taska. Zmiana dokumentu to osobny PR typu `docs`, robiony przez Sola lub Ciebie.
3. **Stabilne kotwice.** Taski linkują do nagłówków; zmiana nagłówka to zmiana kontraktu.
4. **Limit długości.** `AGENTS.md` ≤ ~200 linii (jest w kontekście każdego wywołania), pozostałe ≤ ~600 linii. Po przekroczeniu dzielimy tematycznie, nie dopisujemy „aneksów”.
5. **Decyzja przed dokumentem.** Zmiana w PRODUCT/GAME_DESIGN/ARCHITECTURE zaczyna się od pliku w `docs/decisions/`, który wyjaśnia dlaczego.
