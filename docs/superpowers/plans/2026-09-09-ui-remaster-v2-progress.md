# UI remaster v2 — checkpoint 1

## Zatwierdzony kierunek

Android i Windows, editorial + pastel, Manrope w plikach aplikacji, chłodny błękit,
pełne jasne i ciemne motywy. Start / Zadania / Notatki. Dolna nawigacja poniżej
600 dp, szyna 600–1099 dp, rozszerzony panel od 1100 dp. Nowy interfejs obok starego
aż do dwóch ocen użytkownika. Rebranding później. Kopia tylko kodu.

## Kopia wersji wyjściowej

- Gałąź: `codex/ui-remaster-v2`.
- Checkpoint kodu: `c08450989224c18a01235f60f8dabad6ce709c71`.
- Archiwum poza worktree: `ui-remaster-v2-code-backup.zip` w głównym katalogu projektu.
- Kopia zawiera dotychczasowe zmienione i nowe pliki źródłowe; nie zawiera `.env`,
  buildów, cache ani logów. Konfiguracja `.env.example` jest szablonem.
- Wersja wyjściowa: analizator bez uwag, 100 testów, Windows Release i Android debug APK zbudowane.

## Zrealizowano w checkpoint 1

- Osobny system motywu podglądu, lokalny font Manrope z licencją OFL.
- Wspólna powłoka, dolna nawigacja i szyna/panel; profil, motyw i powrót do starego wyglądu.
- Start korzystający z istniejących danych: powitanie, bieżąca data, karta Teraz,
  plan dnia, licznik ukończonych dzisiaj, do trzech aktywnych notatek.
- Wyszukiwanie zadań/notatek ze Start, kontekstowe dodawanie i zachowany stan zakładek.
- Pusta karta Teraz otwiera dodawanie. Z istniejącą treścią otwiera edytor.
- Ukończenie i cofanie podpięte do istniejącej logiki.
- Ctrl+K przenosi do wyszukiwania Start, Ctrl+N uruchamia kontekstowe dodawanie.
- Podgląd jest domyślnie wyłączony. Lokalna preferencja: `ui_remaster_v2`.
- Włączenie: ikona „Podgląd nowego interfejsu” w prawym górnym rogu starego UI.
- Powrót: „Konto i wygląd” → „Wróć do poprzedniego wyglądu”.
- Podglądy z Fluttera: `build/remaster-previews/`; treść przykładowa wyłącznie w testach.

## Kolejność dalszej pracy po checkpoint 1

1. Ocena wyglądu Start na telefonie/PC i ewentualna korekta wizualna.
2. Nowe wnętrze Zadań: kompaktowe akcje, podwidoki, desktopowy panel szczegółów,
   telefonowy pełny ekran, uproszczony mobilny kalendarz. Obecnie zakładka używa istniejącego widoku.
3. Nowe wnętrze Notatek: adaptacyjna siatka, panel edytora, foldery + etykiety.
   Obecnie zakładka używa istniejącego widoku/edytora. Folderów jeszcze nie dodano.
4. Modele NoteFolder i opcjonalny folderId; lokalny magazyn i migracja Supabase z RLS,
   Realtime i usuwaniem folderu bez usuwania treści. Nie wdrażano migracji w checkpoint 1.
5. Checkpoint 2: ocena pełnych przepływów Zadań/Notatek.
6. Logowanie, ustawienia, przegląd tygodnia, skupienie i wszystkie pozostałe ekrany.
7. Testy migracji, kont, synchronizacji między urządzeniami oraz dostępności całej aplikacji.
8. Po końcowej akceptacji usunięcie starego UI i przełącznika. Na razie muszą pozostać.

## Zakres weryfikacji checkpoint 1

Testy Start: 390×844, 768×1024, 1366×768, 1440×900, 844×390; jasny/ciemny i 100%/200%
tekstu. Osobne testy integracji preferencji, przełączania zakładek, wyszukiwania,
ukończenia i cofania. Testy layoutu nie oznaczają zakończonej oceny wszystkich starych
ekranów. Nie wykonano testu na fizycznym Androidzie ani dwóch sesjach chmurowych.

Końcowa weryfikacja checkpoint 1: `flutter analyze` bez uwag, wszystkie 122 testy
przeszły, Windows Release i Android debug APK zbudowane. Gradle zgłasza istniejące
ostrzeżenie dotyczące przyszłej zgodności `flutter_timezone` z Kotlin Gradle Plugin;
nie blokuje bieżącego buildu. Oba buildy znajdują się w standardowych katalogach `build/`.
