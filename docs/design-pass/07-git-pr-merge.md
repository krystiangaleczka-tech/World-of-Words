# 07 — Workflow branch / PR / merge

## 1. Przepływ

```
task (status: ready)
 → branch t/0123-wheel-shuffle od świeżego main
 → preflight (czy "Current state" się zgadza; jeśli nie: STOP S1)
 → implementacja + testy z taska
 → make check (pętla do zielonego, max 2 nieudane podejścia → STOP S9)
 → commit(y), status taska: review
 → PR (szablon) → CI
 → review wg ryzyka
 → rebase na main, jeśli main się przesunął → CI
 → squash merge → branch usunięty → status taska: done (w tym samym squashu)
```

## 2. Nazewnictwo

| Element | Format | Przykład |
|---|---|---|
| Task | `T-NNNN` (4 cyfry, rosnąco) | `T-0123` |
| Epik | `ENN` | `E04` |
| Plik taska | `tasks/T-NNNN-slug.md` | `tasks/T-0123-wheel-shuffle.md` |
| Branch | `t/NNNN-slug` | `t/0123-wheel-shuffle` |
| Branch bez taska (tylko Ty/Sol) | `docs/slug`, `plan/E04-wave2`, `hotfix/slug` | |
| Commit | Conventional Commits + ID | `feat(wheel): add shuffle [T-0123]` |
| Tytuł PR | `T-NNNN type(scope): opis` | `T-0123 feat(wheel): add shuffle` |
| Commit po squashu | tytuł PR | |

`scope` = obszar bez prefiksu (`wheel`, `board`, `economy`, `pipeline`). ID w branchu pozwala CI znaleźć task i sprawdzić `touch`.

## 3. Strategia merge'a

- **Tylko squash merge.** 1 task = 1 commit na `main`. Historia liniowa, revert taska = revert jednego commita, `git bisect` po taskach.
- Branch protection na `main`: wymagane checki, wymagane aktualne względem `main` przed merge'em, zakaz force-push, brak bezpośrednich pushy (wyjątek: Ty, dla `tasks/` i `docs/` przy planowaniu fali, jeśli nie chcesz PR dla każdej fali).
- **Merge queue**, jeśli Twój plan GitHuba go oferuje dla tego repo. Jeśli nie: „wymagaj aktualnego brancha” + auto-merge + małe PR-y daje ten sam efekt przy obecnej skali.
- Rebase (nie merge commit) do aktualizacji brancha. Wolno, bo branch należy do jednego wykonawcy.

## 4. Konflikty: „uruchom ponownie zamiast rozwiązywać”

| Sytuacja | Działanie | Kto |
|---|---|---|
| Rebase bez konfliktów | rebase, `make check`, push | wykonawca |
| Konflikt mechaniczny: importy, sąsiednie linie w różnych funkcjach, oba dodania do różnych miejsc | rozwiąż, `make check`, w PR adnotacja „resolved mechanical conflict in X” | wykonawca |
| Konflikt w tej samej funkcji / logice / pliku kontraktu | **porzuć branch, wykonaj task od nowa na świeżym `main`** (nowy branch `t/0123-…-r2`) | wykonawca |
| Ponowne wykonanie niemożliwe, bo `main` zmienił założenia taska | STOP S4 → Sol robi nową rewizję taska | Sol |
| Konflikt między dwoma taskami w tym samym obszarze | błąd planowania: `tasks.py plan` nie powinien ich wypuścić; Sol poprawia `touch`/`area` | Sol |

Dlaczego ponowne wykonanie: tani model rozwiązujący konflikt semantyczny ma tendencję do wybierania „swojej” strony i cichego gubienia zmian drugiej. Ponowna implementacja małego taska kosztuje grosze i daje kod, który od początku widział aktualny `main`.

## 5. Wymagane checki CI (każdy PR)

| Check | Narzędzie | Czas | Blokuje |
|---|---|---|---|
| `scope` | `tools/check_scope.py` (zmienione pliki ⊆ `touch` + własny plik taska) | sekundy | tak |
| `tasks-lint` | `tools/tasks.py lint` | sekundy | tak |
| `format` | `gdformat --check`, `ruff format --check` | sekundy | tak |
| `lint` | `gdlint`, `ruff` | sekundy | tak |
| `godot-import` | Godot headless `--import` + skan logu pod kątem błędów parsowania i zepsutych zasobów | ~1 min | tak |
| `unit` | GUT headless | ~1 min | tak |
| `integration` | GUT: boot smoke + przejście wszystkich wydanych leveli botem (patrz `08`) | kilka min | tak |
| `pipeline` | `pytest` (z `hypothesis`) | ~1 min | tak, gdy zmieniony `pipeline/` |
| `content-validate` | walidator wszystkich paczek w `game/content/` + blokada zmian wydanych slotów | ~1 min | tak |
| `registries` | wszystkie `Analytics.track("…")` i klucze `Config.get(…)` istnieją w rejestrach | sekundy | tak |
| `test-count` | liczba testów nie spada względem `main` | sekundy | tak (wyjątek tylko z etykietą od Ciebie) |
| `android-build` | eksport debug APK | kilka min | tak |
| `ios-build` | eksport + `xcodebuild` na macOS | ~10+ min | **nie** na PR; nocnie i przed wydaniem |

`make check` uruchamia lokalnie wszystko poza buildami. Wykonawca nie otwiera PR bez zielonego `make check`.

## 6. Szablon PR

Gotowy plik: `seed/.github/pull_request_template.md`. Sekcje: Task (ID + rewizja), Summary, Deviations / concerns (domyślnie „None”; cokolwiek innego wymusza review Sola), Escalations, Test evidence (wynik `make check`), Screenshots (UI), Checklist.

## 7. Review według ryzyka

| Ryzyko | Review | Merge |
|---|---|---|
| `low` | CI + krótkie automatyczne review taniego modelu (checklista) + Twój rzut oka | Ty; po okresie zaufania (np. 30 tasków bez regresji) auto-merge dla `test`/`refactor` |
| `medium` | + review Sola na `tools/review_pack.py` | Ty |
| `high` | + review Sola + Twój test na urządzeniu; przy zmianie architektury druga opinia Opusa | Ty |

**Checklista recenzenta AI** (wklejana razem z review pack):
1. Czy zachowanie odpowiada sekcji Behavior punkt po punkcie?
2. Czy każdy test z sekcji Tests istnieje i czy *padłby*, gdyby wycofać implementację?
3. Czy coś wykracza poza Goal (rozszerzenie zakresu)?
4. Pułapki Godot 4, typy, brak magicznych liczb (tokeny / config).
5. Brak nowych singletonów, brak wywołań `platform/` z `features/`.
6. Brak alokacji w ścieżce wejścia (swipe) i w `_process`.
7. Nazwy eventów i kluczy configu zgodne z rejestrami.
8. Sygnały rozłączane, tweeny zabijane, brak wycieków węzłów.

## 8. Praca 5–10 agentów naraz: jak to wygląda w praktyce

1. Sol rozpisał falę 6 tasków w 4 obszarach.
2. `tools/tasks.py plan` zwraca 4 taski gotowe do startu (różne obszary, rozłączne `touch`, zależności spełnione); 2 czekają.
3. 4 agentów startuje, każdy we własnym branchu / sandboxie z obrazem Dockera.
4. PR-y przychodzą w różnych momentach; merge w kolejności z §6 `06`.
5. Po każdym merge'u pozostałe otwarte PR-y robią rebase; konflikt nietrywialny = ponowne wykonanie.
6. Gdy zwolni się obszar, `plan` wypuszcza kolejny task.

Środowisko wykonawcy jest wymienne (agent CLI z tanim modelem, agent w chmurze podpięty pod GitHuba, Codex itp.), o ile: czyta `AGENTS.md`, ma obraz z Godotem headless i potrafi uruchomić `make check`.
