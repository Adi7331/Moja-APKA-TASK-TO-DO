# Notatki — czytelne karty, foldery i jednoznaczny zapis

## Cel

Poprawiamy bibliotekę Notatek na Androidzie i Windowsie tak, by kolory kart
nie zlewały się z ciemnym interfejsem, foldery dało się w pełni zarządzać, a
utworzenie notatki miało widoczne zakończenie akcji. Zmiana pozostaje
kompatybilna z istniejącą synchronizacją, lokalnym zapisem, koszem i
przypięciami.

## Ustalenia

- Kolor notatki jest wyborem użytkownika, a nie automatycznie rotowanym
  tłem zależnym od pozycji w siatce.
- Karta bez wybranego koloru ma grafitową powierzchnię odróżnialną od tła.
  Kolorowe karty otrzymują pięć bardziej rozdzielonych, pastelowych
  powierzchni: błękit, lawendę, miętę, piasek i koral. Tekst i ikony muszą
  zachować kontrast co najmniej 4.5:1.
- Folder ma nazwę, kolor i opcjonalną jedną emoji jako treść użytkownika
  (np. `🚗`). Emoji nie jest kontrolką interfejsu. Jest zapisywana lokalnie i
  synchronizowana między urządzeniami.
- Każda karta pokazuje lokalną datę oraz godzinę ostatniej aktualizacji w
  formacie `22.09.2026 · 14:35`.
- Biblioteka zawsze sortuje aktywne notatki: najpierw przypięte, następnie
  malejąco po `updatedAt`. Rozdział do kolumn siatki zachowuje kolejność
  czytania od lewej do prawej, zamiast dobierać kartę do najniższej kolumny.
- Edytor zachowuje autosave, ale zawiera także widoczny przycisk `Gotowe`.
  Ten przycisk wymusza zapis i wraca do biblioteki tylko po udanym zapisie
  lokalnym. Ikona wstecz ma znaczenie wyłącznie nawigacyjne (`Wróć`).

## Karty notatek

### Powierzchnie

`NoteColorKey.neutral` nie będzie już przyjmował kolejnego koloru z palety.
Zamiast tego karta korzysta z semantycznego `surfaceContainerHigh` motywu.
Wybrany kolor odpowiada zawsze temu samemu odcieniowi. Na dark mode karta
ma czytelną krawędź oraz łagodne podniesienie względem tła, a nie dodatkowy
ciemny, zbliżony prostokąt.

Kolor i przypięcie nie są jedyną informacją o stanie: karta nadal pokazuje
ikonę pinezki, a dostępne działania są podpisane semantycznie.

### Kolejność i czas

Funkcja wyboru danych pozostaje jedynym miejscem sortowania. Siatka ma nie
zmieniać tej kolejności w trakcie układania kolumn. Data i godzina korzystają
z `DateFormat` dla `pl_PL`, aby format nie zależał od ręcznego składania
tekstu ani ustawień urządzenia.

## Foldery

### Zarządzanie

Menu `Więcej` na ekranie Notatek prowadzi do `Nowy folder` i `Zarządzaj
folderami`. Przy tworzeniu i edycji otwierany jest jeden formularz:

- nazwa (wymagana, 1–80 znaków),
- wybór koloru,
- pole emoji (opcjonalne; jedna emoji albo puste).

Lista zarządzania folderami ma dla każdego folderu menu z akcjami `Edytuj`
i `Usuń`. Edycja zachowuje identyfikator folderu. Usunięcie wymaga
potwierdzenia, a notatki z folderu zostają lokalnie i w chmurze przypisane do
`Bez folderu`.

Filtry, kontekstowy panel Windows oraz chip w edytorze pokazują emoji przed
nazwą tylko wtedy, gdy użytkownik ją ustawił.

### Dane i synchronizacja

`NoteFolder` dostaje opcjonalne `emoji`. Brak pola w starym lokalnym pliku
oznacza `null`; nie może przerwać odczytu istniejących folderów. Payload
Supabase zawiera `emoji`, a odczyt używa `null`, gdy kolumna nie istnieje lub
jest pusta.

Plik `supabase/note_folders.sql` zostanie rozszerzony o idempotentne:

```sql
alter table public.note_folders
  add column if not exists emoji text
  check (emoji is null or char_length(emoji) between 1 and 16);
```

Nie zmienia to RLS, Realtime ani tabeli `notes`. Po wdrożeniu migracji na
Supabase wszystkie urządzenia odczytują i zapisują emoji; przed migracją
aplikacja nadal zachowuje lokalny folder i kolejkę synchronizacji zgodnie z
obecnym zachowaniem przy niedostępnej tabeli/kolumnie.

## Edytor

W górnym pasku edytora znajduje się tekstowy przycisk `Gotowe`, zawsze
widoczny na telefonie i w panelu Windows. Po naciśnięciu:

1. zatrzymuje oczekujący autosave;
2. zapisuje bieżący draft przez istniejącą seryjną kolejkę;
3. zamyka edytor tylko po sukcesie;
4. przy błędzie zostawia edytor otwarty i pokazuje jasny stan z akcją
   ponowienia.

Nie dodajemy osobnego przycisku „Utwórz”: nowa notatka jest tworzona od razu
lokalnie, a `Gotowe` potwierdza jej treść i zakończenie edycji bez ryzyka
utraty danych.

## Testy akceptacyjne

1. Neutralna karta nie rotuje po pastelach; ręcznie wybrany kolor zawsze
   daje ten sam odcień i czytelny tekst.
2. Karty pokazują datę i godzinę po polsku.
3. Przypięte notatki są pierwsze, a reszta malejąco według aktualizacji;
   pierwsza notatka nie trafia do niższej pozycji przez układ kolumn.
4. Folder z emoji przechodzi lokalną serializację, payload synchronizacji i
   odczyt z Supabase; stary zapis bez emoji dalej się ładuje.
5. Utworzenie, edycja koloru/emoji/nazwy oraz usunięcie folderu działają na
   telefonie bez overflow; usunięcie zachowuje notatki.
6. `Gotowe` zapisuje i zamyka edytor, a nieudany zapis nie zamyka go.
7. Testy widgetów obejmują `390×844`, 200% tekstu i Windows; brak poziomego
   overflow.
8. Końcowo: `flutter analyze`, pełne `flutter test`, build Windows oraz APK
   Androida.

## Poza zakresem

- Nowe typy folderów lub foldery zagnieżdżone.
- Wiele emoji, własne obrazki folderów albo wspólne foldery między kontami.
- Zmiana schematu `NoteItem`, zawartości notatek lub zasad kosza.
