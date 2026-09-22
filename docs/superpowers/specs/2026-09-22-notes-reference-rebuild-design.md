# Notatki — przebudowa według zaakceptowanej referencji

## Cel

Moduł Notatek ma wyglądać i zachowywać się jak spójny, ciemny organizer z pastelowymi kartami — zgodnie z referencją przekazaną 22 września 2026 r. Referencja jest kierunkiem układu i hierarchii, nie materiałem do kopiowania 1:1 ani źródłem cudzych grafik.

Efekt ma być widoczny zarówno na Androidzie, jak i Windowsie. Istniejące dane, synchronizacja Supabase, foldery, przypięcia, archiwum, kosz, checklisty i załączniki pozostają zachowane.

## Zasada projektowa

Nie rozwijamy starego ekranu listowego. Powstaje osobna warstwa prezentacji notatek, z trzema responsywnymi kompozycjami:

1. biblioteka notatek na telefonie;
2. pełnoekranowy edytor notatki na telefonie;
3. biblioteka i edytor na pulpicie.

Warstwa danych `NoteItem`, `NoteFolder`, lokalny zapis, kolejka synchronizacji i istniejące akcje notatek nie są migrowane ani zastępowane.

## Android: biblioteka notatek

### Hierarchia

- Górna część: `Dzień dobry, {imię}` oraz jeden krótki podtytuł. Avatar użytkownika jest po prawej.
- Następnie pojedyncza, zaokrąglona wyszukiwarka.
- Pod wyszukiwarką znajduje się przewijalny poziomo rząd filtrów: `Wszystkie`, `Przypięte`, a dalej wybrane foldery. Aktywny filtr ma niebieskie wypełnienie.
- Główna zawartość to dwukolumnowa, przewijana pionowo siatka kart. Karty mają naturalną wysokość zależną od treści, lecz żadna karta nie może zasłaniać kolejnej.
- Dolna nawigacja pozostaje z trzema głównymi przestrzeniami: Start, Zadania, Notatki. Główny przycisk dodania notatki pozostaje centralną akcją ekranu.

### Karty

- Każda karta otrzymuje pastelową powierzchnię z ustalonej palety: błękit, lawenda, mięta, piasek, jasny koral. Brak ręcznie wybranego koloru nie oznacza ciemnej karty — wybierany jest kolor domyślny z palety.
- Karta pokazuje: tytuł, krótki fragment, maksymalnie kilka pozycji checklisty lub podgląd obrazu, datę oraz ikonę przypięcia, jeśli dotyczy.
- Dotknięcie karty otwiera edytor. Menu karty zawiera działania pomocnicze: przypięcie, przeniesienie, archiwum, kosz i ustawienie widżetu.
- Karta ma zachować czytelność w dark mode: ciemny tekst na pastelowym tle, niezależnie od koloru otoczenia aplikacji.

### Drugorzędne widoki

- `Przypomnienia`, `Archiwum` i `Kosz` nie są już czterema dużymi zakładkami nad treścią. Są dostępne z menu `więcej` na ekranie Notatek.
- Foldery nie zajmują osobnej dużej ramki. Są filtrami oraz pozycjami w tym samym menu pomocniczym.
- Stan synchronizacji jest małym komunikatem technicznym pod wyszukiwarką, tylko kiedy synchronizacja wymaga uwagi; nie dominuje nad biblioteką.

## Android: edytor

- Edytor otwiera się jako pełny ekran, bez dolnej nawigacji.
- Pasek: strzałka wstecz, stan zapisu, przypięcie oraz menu więcej.
- Treść: duży tytuł, kompaktowy wybór folderu, tekst i bloki checklisty. Zawartość jest czytelna w jednej kolumnie.
- Sekcja załączników jest na dole: pliki i obrazy w małych kartach z akcją dodania.
- Powrót nie gubi lokalnie zapisanej treści. Istniejący serializowany autosave zostaje wykorzystany.

## Windows: biblioteka

- Stały lewy panel jest dwuetapowy: główna nawigacja aplikacji oraz kontekst Notatek z folderami i licznikami. Pokaże: Wszystkie, foldery użytkownika, Przypięte, Archiwum i Kosz.
- W części głównej u góry jest wyszukiwarka, poniżej tytuł `Notatki`, potem kompaktowy rząd filtrów folderów oraz przełącznik `siatka / lista`; domyślny jest widok siatki.
- Notatki są gridem pastelowych kart: dwa słupki przy mniejszym oknie desktopowym, trzy lub więcej przy szerokim. Karty mają stały, spokojny rytm odstępów.
- Otwieranie notatki nie może ukryć biblioteki nieodwracalnie: szerokie okna dostają prawy panel edytora, a węższe otwierają pełny widok z powrotem do zachowanego miejsca siatki.

## Responsywność i dostępność

- Telefon: mniej niż 600 dp — dwa słupki kart, jeśli szerokość i powiększenie tekstu na to pozwalają; przy dużym tekście jeden słupek.
- Tablet: 600–1099 dp — adaptacyjna siatka oraz zwijana nawigacja.
- Desktop: od 1100 dp — stały panel kontekstowy folderów i siatka co najmniej trzech kolumn, zależnie od dostępnej szerokości.
- Pola dotykowe mają minimum 48×48 dp. Karty, filtry oraz akcje otrzymują semantyczne etykiety i widoczny focus na Windowsie.
- Nie używamy emoji jako kontrolek. Wszystkie kontrolki używają ikon Material o jednym stylu.

## Dane i zachowanie

- Nie zmieniamy modeli danych ani schematu Supabase.
- Filtr `Przypięte` działa na istniejącym polu `pinned`.
- Brak folderu oznacza filtr `Wszystkie`, nie ukrywa notatki.
- Archiwum i kosz korzystają z istniejących pól, bez fizycznego usuwania danych.
- Zachowujemy obecny lokalny-first zapis i ponowienie synchronizacji.

## Kryteria odbioru

1. Na Androidzie pierwsza strona Notatek wizualnie ma: powitanie, wyszukiwarkę, jeden rząd filtrów i dwukolumnowe pastelowe karty — bez starego bloku folderów i czterech zakładek.
2. Na Windowsie foldery są w lewym kontekście Notatek, a główna część zawiera widoczną siatkę pastelowych kart.
3. Otwarcie notatki pokazuje przebudowany pełnoekranowy/panelowy edytor, a nie stary formularz.
4. Istniejące notatki, foldery, załączniki, kosz, archiwum i synchronizacja nadal działają.
5. Oba warianty są sprawdzone na rzeczywistym buildzie Android i Windows przed przekazaniem użytkownikowi.

## Poza zakresem tej przebudowy

- Rebranding nazwy i logo.
- Kopiowanie ilustracji, avatara, zdjęć lub konkretnych zasobów z referencji.
- Zmiana backendu, migracje Supabase lub kasowanie starych notatek.
