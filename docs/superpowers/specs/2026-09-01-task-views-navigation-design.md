# Klikane widoki zadań i nawigacja

## Cel

Zamienić wizualne pozycje menu w działającą nawigację, aby użytkownik mógł przełączać się między zadaniami na dziś, skrzynką, nadchodzącymi terminami i ukończonymi zadaniami bez utraty bieżących danych.

## Widoki

- `Dzisiaj`: obecny plan dnia. Zawiera zadania bez terminu, z terminem dzisiaj oraz bieżące zadania zgodne z wybranym filtrem statusu.
- `Skrzynka`: wyłącznie aktywne zadania z kategorią `Skrzynka` i bez terminu. Jest miejscem dla rzeczy zapisanych „na później”.
- `Nadchodzące`: aktywne zadania z terminem po końcu bieżącego dnia; lista jest sortowana rosnąco po terminie.
- `Ukończone`: wyłącznie zadania o statusie `done`, od najnowszego terminu do najstarszego; zadania bez terminu występują na końcu.

Każdy widok używa tych samych kart zadań, menu statusu, checklisty i otwierania edytora. Nie powstają kopie danych ani dodatkowe tabele Supabase.

## Nawigacja

- Windows: kliknięcie pozycji lewego paska zmienia aktywny widok, tytuł oraz dane listy. Aktywna pozycja ma subtelne zaznaczenie.
- Telefon: przycisk trzech kropek w nagłówku otwiera menu z tymi samymi czterema widokami. Aktywny widok jest oznaczony znacznikiem wyboru.
- Przełączenie widoku nie zmienia zadania ani filtru tekstowego; wyszukiwanie działa w obrębie bieżącego widoku.
- Przycisk szybkiego dodawania jest dostępny w każdym widoku.

## Architektura

`MyApp` przechowuje prywatny stan `TaskView` jako enum: `today`, `inbox`, `upcoming`, `completed`. Ten stan oraz callback `onViewChanged(TaskView)` są przekazywane do `TodayScreen`, który zostanie przemianowany na neutralny `TaskListScreen` albo otrzyma obsługę widoków bez zmiany publicznych danych zadań.

Jedna czysta funkcja wybierająca zadania przyjmuje listę `TaskItem`, `TaskView` oraz aktualny czas i zwraca listę dla widoku. Jest testowana bez Fluttera. Widżet dostaje już przefiltrowane listy i jedynie je prezentuje.

## Stany puste

- Skrzynka: „Skrzynka jest pusta. Zapisz tu rzecz, o której chcesz pamiętać.”
- Nadchodzące: „Nie masz zaplanowanych przyszłych terminów.”
- Ukończone: „Nie ma jeszcze ukończonych zadań.”

Każdy stan pusty pozostawia dostępny przycisk szybkiego dodawania.

## Błędy i testy

- Przełączanie widoku jest wyłącznie lokalne i nie wymaga internetu, więc nie generuje błędów synchronizacji.
- Testy jednostkowe sprawdzają przypisanie zadania bez terminu, zadania na dziś, przyszłego terminu i zadania ukończonego do odpowiednich widoków.
- Testy widgetów sprawdzają kliknięcie pozycji menu desktopowego i telefonu, zmianę nagłówka oraz zachowanie listy po przełączeniu.
- Po wdrożeniu przechodzą `flutter analyze` oraz `flutter test`.

## Poza zakresem

- Ten etap nie dodaje ustawień motywu ani Google OAuth.
- Nie zmienia schematu Supabase, formatu lokalnego zapisu, powiadomień ani logiki cykliczności zadań.
