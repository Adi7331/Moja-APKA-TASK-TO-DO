# Stabilizacja zadań + Android

Źródłem wymagań jest zatwierdzony przez użytkownika plan z 20 września 2026.

## Task 1 — Modele i synchronizacja kategorii

1. Dodać `TaskCategory`, opcjonalne `categoryId` do zadań i zgodną wstecz migrację lokalną.
2. Dodać prywatną migrację Supabase z RLS i Realtime.
3. Dodać magazyn/synchronizację kategorii oraz testy modelu i migracji.

## Task 2 — Widoki zadań i edytor

1. Wykluczyć ukończone z Dzisiaj, Skrzynki i Nadchodzących.
2. Dodać zarządzanie kategoriami oraz wybór kategorii w edytorze.
3. Ulepszyć edytor: opis bezpośrednio pod tytułem, 5 linii, „Lista kroków” w Więcej opcji.
4. Dodać polskie lokalizacje Materiala.

## Task 3 — Niezawodny lokalny zapis notatek i zadań

1. Zawsze utrwalać lokalne kopie oraz trwałą kolejkę synchronizacji.
2. Seryjny autosave jednej notatki, wyraźne stany i retry.
3. Usuwanie notatek tylko do Kosza oraz automatyczne czyszczenie po 30 dniach udanej synchronizacji.

## Task 4 — Przypomnienia Androida

1. Dodać ustawienia dziennego planu i zaległych zadań, domyślnie wyłączone.
2. Poprawić zgody, anulowanie starych alarmów, akcje Zrobione/Odłóż i restart urządzenia.
3. Dodać testy harmonogramów i stanu uprawnień.

## Task 5 — Google Calendar

1. Utrwalić token Calendar tylko w bezpiecznym magazynie urządzenia.
2. Obsłużyć powrót z Chrome, odczyt bieżącej sesji i stany połączenia.
3. Zachować wyłącznie minimalne zakresy odczytu oraz per-urządzeniowy wybór kalendarzy.

## Task 6 — Widżety Androida

1. Dodać widżet Dzisiaj z trzema zadaniami i licznikiem.
2. Dodać konfigurowalny widżet Wybrana notatka.
3. Odświeżanie po zmianach, synchronizacji, północy i czyszczenie po wylogowaniu.

## Task 7 — Weryfikacja i przekazanie

1. Flutter analyze, pełne testy, build Windows i podpisany APK.
2. Niezależny przegląd całej gałęzi oraz poprawki krytycznych/ważnych ustaleń.
