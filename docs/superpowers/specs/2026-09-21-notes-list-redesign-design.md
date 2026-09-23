# Przebudowa Notatek do widoku listy — specyfikacja

## Cel

Zastąpić obecny, ciężki wizualnie widok Notatek spokojnym i szybkim modułem typu
„daily notebook”. Głównym widokiem będzie pionowa lista notatek, a kolory będą
wyłącznie subtelnym akcentem. Istniejące dane, foldery, etykiety, załączniki,
kosz, zapis offline, konflikty i synchronizacja Supabase pozostają zachowane.

## Zakres

### Telefon (<600 dp)

- Nagłówek z powitaniem, avatarem i akcją profilu.
- Wyszukiwanie nad filtrami.
- Filtry: Wszystkie, Przypięte, foldery i etykiety; filtry przewijają się
  wyłącznie poziomo w swoim pasku i nie powodują poziomego przewijania ekranu.
- Pionowa lista wierszy notatek. Wiersz zawiera kolorowy pasek 4 dp, tytuł,
  maksymalnie trzy linie podglądu, folder/etykiety, datę lub przypomnienie oraz
  małe wskaźniki checklisty i załączników.
- Dolna nawigacja: Start, Notatki, Zadania, Więcej.
- Pływający przycisk „+” otwiera wybór: notatka, checklista, zdjęcie lub plik.
- Edytor notatki otwiera się jako pełny ekran, bez modalnego okna blokującego
  cały przepływ.

### Tablet i Windows (>=600 dp)

- Stała nawigacja po lewej stronie przy szerokości >=1100 dp; przy mniejszej
  szerokości pozostaje zwijana zgodnie z istniejącą powłoką remasteru.
- Środkowa kolumna zawiera wyszukiwanie, filtry i listę notatek.
- Przy szerokości >=1100 dp prawa kolumna pokazuje wybraną notatkę i jej edycję.
- Przy szerokości 600–1099 dp edytor otwiera się na osobnym ekranie/panelu,
  zachowując filtr, pozycję przewinięcia i wybrany element.
- Główna treść nie ma poziomego overflow przy dużym tekście ani zmniejszonym
  oknie.

## Wizualny system Notatek

- Tło i powierzchnie korzystają z obecnych tokenów jasnego/ciemnego motywu.
- Kolor notatki jest pokazany jako pasek 4 dp i delikatna poświata tła; nie
  zmienia koloru tekstu w sposób obniżający kontrast.
- Promienie i odstępy korzystają z istniejącej skali remasteru.
- Akcje ikonowe mają etykiety dla czytników ekranu, widoczny focus i pole dotyku
  minimum 48x48 dp.
- Animacje ograniczają się do opacity/scale/transform i respektują ustawienie
  ograniczenia animacji systemowych.

## Zachowanie i dane

- Kliknięcie wiersza otwiera notatkę; na desktopie kliknięcie może najpierw
  zaznaczyć wiersz i odświeżyć prawy panel, a przycisk/ponowne kliknięcie otwiera
  pełną edycję.
- Menu „…” oferuje przypięcie, przeniesienie do folderu, zmianę koloru,
  archiwizację i przeniesienie do Kosza. Usunięcie nie kasuje notatki od razu.
- Status zapisu jest zawsze widoczny: „Zapisano lokalnie”, „Czeka na
  synchronizację” albo „Błąd — Ponów”. Zamknięcie edytora nie może zgubić
  lokalnego zapisu.
- `NoteItem`, `NoteFolder`, etykiety, załączniki i identyfikatory pozostają
  kompatybilne wstecz. Nie zmieniamy schematu Supabase w ramach tej przebudowy.
- Zachowane zostają seryjny autosave, kolejka offline, obsługa konfliktów,
  Realtime i dotychczasowa polityka właściciela danych.

## Komponenty i odpowiedzialność

- `RemasterNotesScreen` pozostaje koordynatorem filtrów, zaznaczenia i stanu
  szerokości.
- Nowy komponent wiersza notatki odpowiada wyłącznie za prezentację jednego
  `NoteItem` oraz akcje wiersza.
- Osobne komponenty obsługują pasek wyszukiwania/filtrów i panel szczegółów,
  aby telefon i desktop korzystały z tych samych danych, ale różnych układów.
- `NoteEditorScreen` zachowuje obecne bloki tekstu, checklisty, tabele,
  załączniki, przypomnienia i akcje folderu; zmienia się przede wszystkim jego
  hierarchia i status zapisu.

## Testy akceptacyjne

- Telefon 390x844: lista, wyszukiwanie, filtry, otwarcie i zamknięcie edytora,
  FAB oraz brak poziomego overflow.
- Tablet 768x1024: zwijana nawigacja, lista i pełny edytor/panel.
- Windows 1366x768 i 1440x900: trzy kolumny, zaznaczenie wiersza i edycja w
  prawym panelu.
- Jasny/ciemny motyw, skalowanie tekstu 200%, klawiatura i widoczny focus.
- Zachowanie wybranego filtra, przewinięcia i notatki przy przełączaniu modułów.
- Lokalny zapis, ponowienie synchronizacji, konflikt i przeniesienie do Kosza.
- `flutter analyze`, pełne `flutter test`, build Windows i podpisany APK.

## Poza zakresem

OCR, import/eksport, udostępnianie systemowe, nowe typy załączników i zmiany
schematu synchronizacji nie są częścią tej przebudowy interfejsu.
