# 08 — Strategia testów

Zasada: **testujemy mocno to, czego błąd kosztuje pieniądze, postęp gracza albo zaufanie; resztę testujemy oczami.** Testy logiki są tanie, bo logika jest w czystych klasach.

## 1. Piramida dla tej gry

```
            ▲  ręcznie na urządzeniu: game feel, reklamy, IAP sandbox, wygląd, wydajność
           ▲▲  integracja headless: boot, przejście wszystkich leveli botem, save roundtrip
        ▲▲▲▲▲  unit (GUT): core/ — tablica, ekonomia, ad policy, streak, migracje, IAP flow
  ▲▲▲▲▲▲▲▲▲▲▲  pipeline (pytest + hypothesis) + walidacja contentu — najszersza podstawa
```

Najszerszą warstwą jest **pipeline i content**, nie kod gry: tam powstaje tysiące artefaktów, których nikt nie obejrzy ręcznie.

## 2. Co czym testować

### Mocne pokrycie (blokujące, unit/property)
| Obszar | Co dokładnie | Dlaczego mocno |
|---|---|---|
| **Pipeline: walidatory i budowa siatki** | niezmienniki jako property-based: każde słowo da się ułożyć z liter; siatka spójna; brak przypadkowych słów na stykach; współrzędne w granicach; determinizm (to samo ziarno = ten sam level) | błąd mnoży się razy tysiące leveli |
| **Walidacja contentu** | każda paczka zgodna ze schematem; brak duplikatów; brak słów z tierem `banned`; wydane sloty niezmienione | gracz zobaczy każdy błąd |
| **Dopasowanie słów (`BoardState`)** | level / bonus / już znalezione / invalid; powtarzające się litery; odkrywanie komórek przecięć; ukończenie levelu | rdzeń gry |
| **Hinty** | która litera/słowo; brak hinta na ukończonym levelu; koszt pobrany dokładnie raz | dotyka ekonomii |
| **Ekonomia** | grant/spend, brak ujemnego salda, dziennik, nagrody z tabel, całkowite kwoty | pieniądze gracza |
| **Zapis i migracje** | roundtrip; każda migracja na złotym pliku; uszkodzony plik → kopia zapasowa; zapis atomowy (symulacja przerwania) | utrata postępu = jedna gwiazdka w sklepie |
| **IAP flow** (z fake store) | idempotencja po `transaction_id`; crash między grantem a finish; restore; pending; anulowanie | prawdziwe pieniądze |
| **Ad policy** | wszystkie warunki z configu; Remove Ads; pierwsze N leveli; odstępy | regulowane configiem, łatwo zepsuć |
| **Daily / streak** | granice dnia, zmiana strefy, DST, przerwa, freeze, cofnięcie zegara (zachowanie zdefiniowane, nie „bezpieczne”) | klasyczne źródło bugów |
| **Rejestry** | każdy `track()` w rejestrze; każdy `Config.get()` w rejestrze; walidacja typów i zakresów configu | tani model wymyśla nazwy |
| **Config zdalny** | nieznane klucze, złe typy, poza zakresem → odrzucenie z zachowaniem domyślnych | zdalny błąd nie może zepsuć gry |

### Integracja (headless Godot, blokujące)
- **Boot smoke:** gra uruchamia się do ekranu głównego bez błędów w logu (z Fake platform).
- **Bot przechodzący content:** dla każdego wydanego slotu ładuje level przez `Content`, podaje wszystkie słowa levelowe jako indeksy kafelków, sprawdza ukończenie. Dowód, że *runtime* (nie tylko pipeline) poprawnie czyta każdy level. Tani, a łapie rozjazd schematu.
- **Save roundtrip przez serwisy:** stan po zagraniu kilku leveli, zapisie i ponownym wczytaniu jest identyczny.

### Ręcznie na urządzeniu (checklista w `TESTING.md`, przed każdym wydaniem i przy taskach `high`)
- game feel: opóźnienie linii za palcem, haptyka, płynność 60/120 Hz, animacje,
- tani Android (jeden konkretny model jako punkt odniesienia) i iPhone z wycięciem; tablet,
- reklamy na testowych jednostkach: zgoda UMP, ATT, rewarded nagradza tylko po obejrzeniu, brak reklamy offline, zachowanie po wyjściu do tła w trakcie reklamy,
- IAP w sandboxie: zakup, anulowanie, restore, zabicie aplikacji w trakcie zakupu,
- przerwania: połączenie, tło, brak sieci, mało miejsca,
- pierwsze 10 minut jako nowy gracz (czysta instalacja).

### Celowo bez testów automatycznych
- układ scen UI, kolory, odstępy (pilnuje tego galeria komponentów i oko),
- kod animacji i efektów,
- audio,
- nawigacja między ekranami poza boot smoke,
- cienkie adaptery SDK (testuje je spike i checklista urządzenia; ich fake'i są testowane pośrednio),
- skrypty narzędziowe (poza `check_scope.py` i `tasks.py`, od których zależy CI).

### Później (Phase 2–3, nieblokujące na start)
- **Zrzuty galerii komponentów** w CI (Godot z renderem pod xvfb) porównywane z referencją, gdy design system się ustabilizuje.
- **Test wydajności**: czas ładowania levelu i czas klatki w scenie levelu na buildzie desktopowym jako proxy.

## 3. Zasady pisania testów (do `AGENTS.md`)
1. Testy przypadków z taska są obowiązkowe; wykonawca może dodać więcej, nie mniej.
2. Test sprawdza zachowanie publicznego API, nie prywatne pola.
3. Żadnych testów, które przechodzą bez implementacji (recenzent sprawdza to pytaniem „co padnie po revercie?”).
4. Czas i losowość zawsze wstrzykiwane; zero `sleep`, zero zależności od zegara.
5. Fixtures w `game/tests/fixtures/` (mała paczka leveli, złote pliki zapisu); nowe fixtures tylko gdy task je wymienia.
