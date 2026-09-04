# Dzień po dniu — responsywny tydzień i bezpośrednie akcje

## Cel

Uczynić zadania szybszymi w obsłudze na komputerze i telefonie oraz dodać lekki widok tygodnia bez zamieniania aplikacji w ciężki kalendarz.

## Zasady wizualne

- Jeden akcent błękitny; gradient tylko na nagłówku aplikacji, karcie „Teraz” i karcie tygodniowego podsumowania.
- Karty zadań są płaskie, o wysokim kontraście i mają oszczędne znaczniki.
- Emoji pozostają wyłącznie małymi etykietami kategorii; kontrolki korzystają z ikon Material o jednolitym stylu.
- Rytm odstępów: 8, 16, 24 i 32 px. Cele dotyku mają co najmniej 48 px.
- Komputer ma hover/focus w 120 ms i stan naciśnięcia w 100 ms; telefon korzysta z tych samych stanów po tapnięciu, bez zależności od hovera.
- Animowane są wyłącznie opacity i transform pojedynczego elementu; listy nie otrzymują ciężkich animacji.

## Bezpośrednie akcje statusu

### Komputer (szerokość >= 720 px)

Każdy wiersz zadania zawiera stale widoczne trzy kompaktowe akcje: „Do zrobienia”, „W trakcie” i „Gotowe”. Aktualny status jest wyróżniony tekstem, ikoną i kolorem. Zmiana wymaga jednego kliknięcia. Menu „…” zachowuje wyłącznie „Przypnij/Odepnij” oraz „Usuń zadanie”; usunięcie nadal potwierdza dialog.

### Telefon (szerokość < 720 px)

Zadanie zawiera jeden pełnoszeroki przycisk bieżącego statusu pod metadanymi. Pojedyncze tapnięcie przechodzi do następnego stanu w kolejności `todo → in_progress → done → todo`. Długie przytrzymanie lub osobna ikona rozwija dostępne trzy statusy. Dzięki temu przycisk jest łatwy do trafienia i nie ściska treści.

## Widok tygodnia

Pojawia się nowy ekran „Tydzień” dostępny z nawigacji desktopowej i kompaktowego menu telefonu.

- Góra pokazuje zakres poniedziałek–niedziela oraz kontrolki poprzedni/następny tydzień.
- Komputer: siedem równych kolumn, po jednej na dzień; zadania z terminem są kartami dnia. Przeciągnięcie karty na inny dzień aktualizuje tylko datę, zachowując godzinę.
- Telefon: siedem przewijanych chipsów dni; wybrany dzień pokazuje jedną listę pod spodem. Przeniesienie zadania odbywa się przez widoczną akcję „Przenieś na dzień”, bez wymagania drag-and-drop.
- Zadania bez terminu nie trafiają automatycznie do kalendarza. Widok zawiera spokojny pusty stan i skrót do szybkiego dodania.

## Dane i synchronizacja

`dueAt` pozostaje źródłem daty tygodniowego kalendarza. Przeniesienie zadania aktualizuje lokalny stan, zapis lokalny oraz istniejącą synchronizację Supabase. Godzina pozostaje bez zmian; jeśli termin był pusty, otrzymuje 09:00 w wybranym dniu.

## Testy akceptacyjne

- Desktop zmienia każdy z trzech statusów jednym kliknięciem.
- Telefon zmienia status pojedynczym przyciskiem, a pełne opcje są dostępne bez gestu hover.
- Tydzień pokazuje zadanie w dniu odpowiadającym `dueAt`.
- Przeniesienie zachowuje godzinę terminu.
- Telefon nie ma poziomego przepełnienia przy szerokości 390 px.
- Analiza Fluttera i wszystkie testy przechodzą bez błędów.
