# World of Words — architecture & design pass (v1, 2026-10-01)

> **Read-only snapshot (T-0001).** This folder is the design pass as accepted on 2026-10-01 and is not
> edited any more. On any conflict, `docs/PRODUCT.md`, `docs/DESIGN.md`, `tasks/ROADMAP.md` and
> `docs/decisions/` win. Changes to the plan go into those files or into a new decision, never here.
> The `seed/` files are adopted into the repo root by T-0002; until then they are templates only.

Pełna rekomendacja architektury produktu, gry i procesu AI. Materiały wejściowe (cztery pliki researchu) potraktowane jako kontekst do krytyki, nie jako specyfikacja.

## Najważniejsze decyzje w skrócie

1. **Technologia:** Godot 4 + typowany GDScript, **pod warunkiem**, że spike platformowy (reklamy, IAP, analityka, crash na Androidzie i iPhonie) przejdzie w Phase 0. Plan B: Unity 6 LTS. KMP/Compose odpada.
2. **Gra nie zawiera słownika.** Pipeline w Pythonie generuje paczki leveli z gotowymi słowami i pełnymi listami bonusów; walidacja w grze to sprawdzenie w zbiorze.
3. **Wąskim gardłem jesteś Ty, nie tokeny.** Workflow minimalizuje Twoje interwencje: `make check`, allowlista plików w CI, review według ryzyka.
4. **Opus jako druga opinia przy nieodwracalnych decyzjach** (zapis, IAP, schemat contentu, intencje ekonomii) i jako twórca fundamentu wizualnego, a nie główny autor wszystkiego. Sol robi większość planowania i review.
5. **Planowanie falami** (3–6 tasków na świeżym `main`), a nie 70 tasków z góry. Równoległość wyliczana z `area`/`touch`/`depends_on`.
6. **„Uruchom ponownie zamiast rozwiązywać”**: nietrywialny konflikt = ponowne wykonanie małego taska.
7. **Mniej dokumentów:** `AGENTS.md` + 6 dokumentów + katalog decyzji. Dokumenty dla agentów po angielsku.
8. **Uproszczony MVP:** pocztówki zamiast world-buildingu, systemowy backup zamiast cloud save, statyczny JSON zamiast Firebase Remote Config, jeden język contentu naraz.
9. **„Fun gate” na końcu Phase 1**: bez przyjemnego swipe'a nie budujemy reszty.

## Mapa 17 punktów rekomendacji

| # | Punkt | Gdzie |
|---|---|---|
| 1 | Wybór technologii | [02-technologia.md](02-technologia.md) |
| 2 | Architektura projektu | [03-architektura-gry.md](03-architektura-gry.md) §2–3, [04](04-repo-i-dokumenty.md) |
| 3 | Struktura repo | [04-repo-i-dokumenty.md](04-repo-i-dokumenty.md) §1 |
| 4 | Dokumenty source-of-truth | [04-repo-i-dokumenty.md](04-repo-i-dokumenty.md) §2 |
| 5 | Workflow AI | [05-workflow-ai.md](05-workflow-ai.md) §1, §4 |
| 6 | Podział modeli | [05-workflow-ai.md](05-workflow-ai.md) §2 |
| 7 | Reguły eskalacji | [05-workflow-ai.md](05-workflow-ai.md) §3, [seed/AGENTS.md](seed/AGENTS.md) |
| 8 | Standard tasków | [06-standard-taskow.md](06-standard-taskow.md), [seed/tasks/TEMPLATE.md](seed/tasks/TEMPLATE.md) |
| 9 | Workflow branch/PR/merge | [07-git-pr-merge.md](07-git-pr-merge.md) |
| 10 | Strategia równoległego developmentu | [06-standard-taskow.md](06-standard-taskow.md) §6, [07](07-git-pr-merge.md) §4, §8 |
| 11 | Strategia testów | [08-testy.md](08-testy.md) |
| 12 | High-level game architecture | [03-architektura-gry.md](03-architektura-gry.md) |
| 13 | Content pipeline | [09-content-pipeline.md](09-content-pipeline.md) |
| 14 | UI/UX workflow | [10-ui-ux.md](10-ui-ux.md) |
| 15 | Główne ryzyka | [11-ryzyka-i-fazy.md](11-ryzyka-i-fazy.md) §1, [01](01-krytyka-wejscia.md) §3 |
| 16 | Co uprościć | [11-ryzyka-i-fazy.md](11-ryzyka-i-fazy.md) §2 |
| 17 | Co zaprojektować dobrze od początku | [11-ryzyka-i-fazy.md](11-ryzyka-i-fazy.md) §3 |
| — | Phase 0–3 | [11-ryzyka-i-fazy.md](11-ryzyka-i-fazy.md) §4 |
| — | Krytyka materiałów i Twojego podejścia | [01-krytyka-wejscia.md](01-krytyka-wejscia.md) |

## Pliki gotowe do repo (`seed/`, po angielsku)
- `seed/AGENTS.md` → root repo (plus `CLAUDE.md` / `GEMINI.md` z jedną linią „Read AGENTS.md”)
- `seed/tasks/TEMPLATE.md`, `seed/tasks/EPIC_TEMPLATE.md` → `tasks/`
- `seed/.github/pull_request_template.md` → `.github/`

## Jak użyć z Solem
1. Wklej Solowi `README.md` + `05`, `06`, `11` i poproś o listę zadań Phase 0 w formie epików (E00 Foundation, E01 Spikes).
2. Decyzje do podjęcia przez Ciebie przed startem: reguły języka PL (`09` §6), pierwszy język contentu, wynik S5 (czy Sol może pracować bezpośrednio na repo).
3. Po spike'u S1 zapisz `docs/decisions/0001-engine.md`; dopiero wtedy szkielet architektury.
