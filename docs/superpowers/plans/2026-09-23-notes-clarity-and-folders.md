# Notatki — czytelne kolory, foldery i zapis — plan wdrożenia

> **Dla agentów wykonujących:** użyj `superpowers:executing-plans`, realizuj zadania po kolei. Każdy krok ma checkbox do śledzenia.

**Cel:** Uczytelnić karty Notatek, dodać zsynchronizowane emoji do folderów, pokazywać godzinę aktualizacji, utrzymać prawidłową kolejność i dać wyraźny przycisk `Gotowe` na Androidzie i Windowsie.

**Architektura:** Zachowujemy lokalny model notatek i kolejkę synchronizacji. `NoteFolder` dostanie opcjonalne emoji i migrację SQL; biblioteka użyje koloru z modelu oraz jednego sortowania, a edytor będzie kończył pracę przez istniejącą serialną kolejkę autosave.

**Tech Stack:** Flutter/Dart, Material 3, `flutter_test`, istniejące `intl` 0.20.3 i `characters` 1.4.1, Supabase SQL.

**Spec:** `docs/superpowers/specs/2026-09-23-notes-clarity-and-folders-design.md`

## Global Constraints

- Zachowaj lokalny zapis, autosave, kolejkę synchronizacji, konfliktowanie, kosz i przypięcia istniejących notatek.
- Neutralna karta ma korzystać z semantycznej powierzchni motywu; nie wybieraj jej koloru według pozycji na ekranie.
- Przypięte notatki są pierwsze, potem notatki sortowane malejąco według `updatedAt`.
- Usunięcie folderu przenosi jego notatki do `Bez folderu`, bez usuwania notatek.
- Emoji folderu jest opcjonalna, pojedyncza i ma działać także przy starszych lokalnych danych bez tego pola.
- `Gotowe` zamyka edytor wyłącznie po udanym lokalnym zapisie.
- Kontrast tekstu na karcie wynosi co najmniej 4.5:1; przyciski dotykowe mają minimum 48×48 dp.
- Nie dodawaj zmian z istniejących modyfikacji `lib/note_list_filters.dart` ani `lib/note_list_row.dart`, jeśli nie są niezbędne temu planowi.

## Review Focus

- Stare foldery bez `emoji` muszą ładować się bez zmian; test w Task 1 odczytuje stary JSON i payload z pustym emoji.
- Brak kolumny `emoji` w Supabase nie może po cichu usunąć folderu ani zgubić jego lokalnej zmiany; test w Task 1 sprawdza mapowanie payloadu, a w Task 5 procedurę i zachowanie kolejki.
- Puste pole emoji jest normalizowane do `null`; ciągi złożone z więcej niż jednego znaku grapheme nie są akceptowane. Test w Task 2 sprawdza walidację formularza.
- Usunięcie folderu zachowuje identyfikatory i treści notatek oraz czyści wyłącznie `folderId`; test w Task 2 przypina ten warunek.
- Gdy notatki mają różne wysokości, najniższa kolumna nie może przestawić wizualnej kolejności; test w Task 3 porównuje identyfikatory kart kolumna po kolumnie.
- Jeśli `onSave` rzuci wyjątek podczas `Gotowe`, panel/ekran musi pozostać otwarty; test w Task 4 sprawdza stan i ponowienie.

---

### Task 1: Opcjonalna emoji folderu i migracja kompatybilna wstecz

**Pliki:**
- Zmień: `lib/note_folder.dart`
- Zmień: `lib/note_sync_service.dart`
- Zmień: `supabase/note_folders.sql`
- Test: `test/note_folder_test.dart`
- Test: `test/note_folder_sync_outbox_test.dart`

**Interfejsy:**
- `NoteFolder({required String id, required String name, String? emoji, ...})`
- `NoteFolder.copyWith({Object? emoji = unchanged, ...})` musi pozwolić odróżnić „zostaw obecną emoji” od „wyczyść emoji”.
- `NoteFolder.fromStorage`, `toStorage`, `toSupabasePayload` zachowują `emoji`.
- `NoteFolder.fromSupabaseRow(Map<String, dynamic> row)` mapuje nazwę/kolor/daty/emoji, a brak `emoji` daje `null`.
- `NoteSyncService.loadFolders` używa `NoteFolder.fromSupabaseRow`; starszy rekord z wartością `null` działa.

Test modelu ma używać starego pliku bez pola i nowego payloadu:

```dart
final legacy = NoteFolder.fromStorage({'id': 'old', 'name': 'Praca'});
expect(legacy.emoji, isNull);
expect(NoteFolder.fromSupabaseRow({'id': 'old', 'name': 'Praca'}).emoji, isNull);

final current = NoteFolder(id: 'car', name: 'Samochód', emoji: '🚗');
expect(current.toStorage()['emoji'], '🚗');
expect(current.toSupabasePayload('owner')['emoji'], '🚗');
expect(NoteFolder.fromSupabaseRow({...current.toSupabasePayload('owner'), 'user_id': 'owner'}).emoji, '🚗');
expect(current.copyWith(emoji: null).emoji, isNull);
```

- [ ] **Krok 1: Dodaj testy czerwone dla lokalnego i cloud mapowania.** W `test/note_folder_test.dart` sprawdź literalnie, że JSON i wiersz Supabase z `emoji: '🚗'` odtwarzają emoji, a stare dane bez pola odtwarzają `null`. Sprawdź `toStorage()` i `toSupabasePayload('owner')`. W `test/note_folder_sync_outbox_test.dart` sprawdź, że oczekujący upsert folderu zachowuje emoji po serializacji i odczycie.
- [ ] **Krok 2: Uruchom tylko te testy i potwierdź oczekiwaną porażkę.** Uruchom `flutter test --no-pub test/note_folder_test.dart`; brak pola/API ma być powodem czerwonego wyniku.
- [ ] **Krok 3: Dodaj nullable `emoji` do `NoteFolder`.** Rozszerz konstruktor, JSON mapowanie i Supabase payload. Dodaj sentinel do `copyWith`, aby można było wykonać `copyWith(emoji: null)` bez utraty istniejącej wartości. Nie zmieniaj identyfikatora, koloru ani znaczników czasu folderu.
- [ ] **Krok 4: Rozszerz odczyt i import synchronizacji.** Dodaj `NoteFolder.fromSupabaseRow(Map<String, dynamic>)` i użyj go w `NoteSyncService.loadFolders()`. `importLocalFolders()` kopiuje emoji do nowego obiektu `NoteFolder`, tak jak obecnie kopiuje nazwę, kolor i daty.
- [ ] **Krok 5: Dodaj idempotentną migrację Supabase.** W `supabase/note_folders.sql` dodaj `ALTER TABLE public.note_folders ADD COLUMN IF NOT EXISTS emoji text CHECK (emoji IS NULL OR char_length(emoji) BETWEEN 1 AND 16);`. Nie zmieniaj RLS, Realtime ani FK folder-notatka.
- [ ] **Krok 6: Uruchom test modelu i kolejki folderów.** Oczekiwane: stare dane bez `emoji` nadal się ładują, nowe dane przechodzą JSON i payload, a operacja folderu nadal serializuje się w `test/note_folder_sync_outbox_test.dart`.
- [ ] **Krok 7: Zapisz niezależny commit.** `git add lib/note_folder.dart lib/note_sync_service.dart supabase/note_folders.sql test/note_folder_test.dart` i commit `feat: add optional note folder emoji`.

### Task 2: Formularz i pełne zarządzanie folderami

**Pliki:**
- Zmień: `lib/remaster_notes_screen.dart`
- Zmień: `lib/note_library_chrome.dart`
- Zmień: `lib/note_folder.dart` (dodaj `NoteFolderDraft`, jeśli interfejs uprości przepływ formularza)
- Utwórz: `lib/note_folder_operations.dart` (czysta operacja odpinająca zachowane notatki od usuwanego folderu)
- Zmień: `lib/main.dart`
- Zmień: `lib/note_editor_screen.dart`
- Test: `test/remaster_folder_dialog_test.dart`
- Test: `test/note_folder_operations_test.dart`
- Test: `test/remaster_note_editor_test.dart`
- Zmień: `pubspec.yaml`, `pubspec.lock` (dodaj `characters: ^1.4.1`, obecnie zablokowane transitive na 1.4.1)

**Interfejsy:**
- `NoteFolderDraft({required String name, required NoteColorKey colorKey, String? emoji})` jest formularzowym wynikiem; `main.dart` nadaje nowy identyfikator i tworzy właściwy `NoteFolder`.
- `SaveRemasterFolder = Future<void> Function(NoteFolderDraft draft)`.
- Zmiana folderu wysyła pełny `NoteFolder.copyWith(...)` z zachowanym ID.
- `NoteFolderChip`/sidebar/filter pokazują `emoji + spacja + name`, gdy emoji istnieje, oraz dotychczasową nazwę w przeciwnym razie.
- `List<NoteItem> notesMovedOutOfFolder({required List<NoteItem> notes, required String folderId, required DateTime updatedAt})` zwraca tylko notatki zmienione; ich treść/ID zostają, `folderId` jest `null`, a `updatedAt` odpowiada argumentowi.

Implementacja helpera ma mapować wyłącznie pasujące notatki:

```dart
List<NoteItem> notesMovedOutOfFolder({
  required List<NoteItem> notes,
  required String folderId,
  required DateTime updatedAt,
}) => notes
    .where((note) => note.folderId == folderId)
    .map((note) => note.copyWith(folderId: null, updatedAt: updatedAt))
    .toList();
```

Wynik formularza ma jawnie normalizować puste emoji i odrzucać wiele grapheme:

```dart
String? normalizeFolderEmoji(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.characters.length != 1 || trimmed.runes.length > 16) {
    throw const FormatException('Wpisz jedną emoji.');
  }
  return trimmed;
}
```

- [ ] **Krok 1: Dodaj testy zachowania przed formularzem.** Widget test tworzy folder o nazwie `Samochód`, kolorze `blue` i emoji `🚗`; następny test edytuje ten sam folder na `Auto` / `🏠` i sprawdza, że ID pozostaje `car`; trzeci potwierdza, że wyczyszczenie pola zapisuje `null`. Test walidacyjny wpisuje dwa znaki grapheme i sprawdza, że formularz nie zamyka się i pokazuje błąd. W `test/note_folder_operations_test.dart` sprawdź, że usunięcie folderu zachowuje ID/treść notatki i ustawia tylko `folderId: null`.
- [ ] **Krok 2: Uruchom `flutter test --no-pub test/remaster_folder_dialog_test.dart` i potwierdź czerwony wynik.** Awaria powinna wskazywać brak pól formularza lub callbacku emoji.
- [ ] **Krok 3: Zmień formularz `Nowy folder` i `Zarządzaj folderami`.** Jeden `StatefulWidget` zwraca `NoteFolderDraft` z nazwą, pickerem istniejących kolorów i polem emoji. Sprawdzaj nazwę po `trim()` w zakresie 1–80 znaków oraz czy ten użytkownik nie ma już folderu o identycznej nazwie. Zależność `characters` dostarcza `Characters(emoji).length`: pusty input normalizuj do `null`, dopuszczaj jeden znak grapheme z maksymalnie 16 wartościami `runes`, odrzucaj pozostałe.
- [ ] **Krok 4: Uzupełnij akcje folderu.** Każdy folder w panelu zarządzania pokazuje nazwę z emoji oraz akcje `Edytuj` i `Usuń`. `Edytuj` aktualizuje nazwę, kolor i emoji. `Usuń` wymaga potwierdzenia; `_deleteFolder` korzysta z przetestowanego `notesMovedOutOfFolder`, zapisuje zmienione notatki lokalnie i dodaje je do synchronizacji.
- [ ] **Krok 5: Przekaż emoji do lokalnego i chmurowego zapisu.** Zmień callback tworzenia w `RemasterNotesScreen` i `_createFolder` w `main.dart`, tworząc `NoteFolder` z draftu. Rename przekazuje zmieniony folder przez istniejący zapis/outbox.
- [ ] **Krok 6: Pokaż emoji przy nazwie.** Chip filtra, pozycja w `NotesDesktopSidebar` i wybór folderu w `NoteEditorScreen._pickFolder` pokazują emoji; accessibility label zawiera pełną nazwę folderu.
- [ ] **Krok 7: Uruchom testy folderów i edytora.** Sprawdź tworzenie, edycję, wyczyszczenie emoji, anulowanie usunięcia i przeniesienie notatki do „Bez folderu”.
- [ ] **Krok 8: Zapisz commit.** Uwzględnij zmienione widgety oraz testy; commit `feat: manage note folder appearance`.

### Task 3: Czytelne kolory, znacznik czasu i kolejność w siatce

**Pliki:**
- Zmień: `lib/remaster_theme.dart`
- Zmień: `lib/note_library_cards.dart`
- Zmień: `lib/note_library_state.dart`
- Zmień: `lib/note_editor_screen.dart` (swatche wyboru koloru mają odpowiadać kartom)
- Zmień: `pubspec.yaml`, `pubspec.lock`, `lib/main.dart` (dodaj `intl: ^0.20.3`, obecna blokada wynosi `0.20.3` i zainicjalizuj polskie formatowanie przed `runApp`)
- Test: `test/note_library_cards_test.dart`
- Test: `test/note_library_state_test.dart`
- Test: `test/remaster_note_editor_test.dart` (kolory w selektorze)

**Interfejsy:**
- `Color noteLibraryCardColor(NoteItem note, ColorScheme scheme)` zwraca motywową powierzchnię dla `neutral` albo niezmienny pastel dla wybranego `colorKey`.
- Neutralna karta używa `scheme.onSurface` i `scheme.onSurfaceVariant`; pastelowa używa atramentowego tekstu o kontraście co najmniej 4.5:1.
- `String formatNoteUpdatedAt(DateTime updatedAt)` daje `dd.MM.yyyy · HH:mm` w lokalnym czasie urządzenia.
- `selectNotesForLibrary(...)` zachowuje kolejność przypięte, potem `updatedAt` malejąco; układ kart rozdziela uporządkowaną listę round-robin, bez wyboru najniższej kolumny.

Test kontrastu liczy stosunek względnej luminancji:

```dart
double contrastRatio(Color a, Color b) {
  final lighter = math.max(a.computeLuminance(), b.computeLuminance());
  final darker = math.min(a.computeLuminance(), b.computeLuminance());
  return (lighter + .05) / (darker + .05);
}
```

Każdy kolor prezentowany z tekstem jest testowany z oczekiwanym tłem; wynik ma być co najmniej `4.5`.

Rozdział do kolumn wykorzystuje stabilny indeks wejściowy:

```dart
for (var i = 0; i < notes.length; i++) {
  buckets[i % columns].add(_IndexedNote(notes[i], i));
}
```

- [ ] **Krok 1: Dodaj czerwone testy stanu.** W `test/note_library_state_test.dart` przygotuj trzy nieprzypięte notatki z aktualizacjami 10:00, 13:00 i 11:00 oraz starszą przypiętą 08:00. Oczekiwane ID: przypięta, 13:00, 11:00, 10:00.
- [ ] **Krok 2: Dodaj czerwone testy kart.** Neutralna karta w dark theme musi mieć `surfaceContainerHigh` i jasny tekst; notatki tego samego koloru muszą mieć ten sam pastel niezależnie od indeksu. Dla daty `2026-09-22 14:35` oczekuj `22.09.2026 · 14:35` w strefie testu.
- [ ] **Krok 3: Uruchom oba testy i sprawdź, że czerwienią się na dotychczasowym losowym kolorze neutralnym, braku godziny i układzie shortest-column.**
- [ ] **Krok 4: Dodaj `intl` jako bezpośrednią zależność.** Użyj zablokowanej wersji `0.20.3`, nie aktualizuj pakietów niezwiązanych z zadaniem. W `main()` zainicjalizuj `initializeDateFormatting('pl_PL')` przed `runApp`; testy wywołują tę samą inicjalizację i korzystają z `DateFormat('dd.MM.yyyy · HH:mm', 'pl_PL')` po konwersji daty na lokalną strefę.
- [ ] **Krok 5: Uczyń powierzchnie kart stałymi i odróżnialnymi.** Neutral: `scheme.surfaceContainerHigh` z obramowaniem `scheme.outlineVariant`; pastel mapuj bezpośrednio na konkretny `NoteColorKey`, a nie indeks. Ustaw oddzielne stałe atramentu/muted dla neutralnych i pastelowych kart. Użyj tych samych stałych w `_ColorButton`, żeby preview wyboru i zapisana karta wyglądały tak samo również w dark mode.
- [ ] **Krok 6: Zmień układ kolumn na stabilny.** Dodawaj notatkę o indeksie `i` do `buckets[i % columns]`. Zachowaj istniejący algorytm doboru liczby kolumn. Kolejność wizualna w kolejnych wierszach to lewa kolumna, potem prawa; wysokość karty nie zmienia jej kolejności w swojej kolumnie. Dla równych `updatedAt` sortuj po stabilnym ID rosnąco.
- [ ] **Krok 7: Uruchom testy stanu i kart, w tym 390×844 oraz tekst 200%.** Upewnij się, że aktywne karty mają datę i godzinę, a overflow nadal nie występuje.
- [ ] **Krok 8: Zapisz commit.** `feat: improve note card contrast and timestamps`.

### Task 4: Widoczne `Gotowe` i zamykanie po zapisie

**Pliki:**
- Zmień: `lib/note_editor_screen.dart`
- Test: `test/remaster_note_editor_test.dart`

**Interfejsy:**
- Dodaj `Future<void> _finishEditing()` jako akcję główną edytora. Wykorzystuje `_save()`; po sukcesie zachowuje `_close()`-owe zachowanie route/embedded, a po błędzie zostawia ekran otwarty.
- Zachowaj `note-close-button` jako nawigacyjne `Wróć`; dodaj `ValueKey('note-done-button')` i widoczny tekst `Gotowe` dla remastered UI.
- W trakcie zapisu blokuj wielokrotne kliknięcie i pokaż `Zapisywanie…`; po niepowodzeniu pokaż `note-save-retry`.

Akcja kończąca edycję ma zachować ekran przy błędzie:

```dart
Future<void> _finishEditing() async {
  if (!await _save() || !mounted) return;
  if (widget.embedded) {
    widget.onClose?.call();
  } else {
    Navigator.of(context).pop(_note);
  }
}
```

- [ ] **Krok 1: Dodaj testy przed zmianą headera.** Sprawdź, że `Gotowe` zapisuje najnowszy tytuł/tekst i zamyka route oraz że `Gotowe` w embedded editor wywołuje `onClose` po zapisie.
- [ ] **Krok 2: Dodaj test błędu.** `onSave` rzuca raz: kliknięcie `Gotowe` ma zostawić edytor widoczny i wyświetlić błąd; kliknięcie `Ponów` i potem `Gotowe` ma zamknąć edytor.
- [ ] **Krok 3: Uruchom `flutter test --no-pub test/remaster_note_editor_test.dart`; potwierdź, że testy braku `Gotowe` i bieżącego zachowania nie przechodzą.**
- [ ] **Krok 4: Dodaj funkcję zakończenia do edytora.** Zatrzymaj timer autosave, wywołaj `_save()`, a po `true` zamknij route wynikiem `_note` albo wywołaj `widget.onClose` dla embedded editor. Po `false` niczego nie zamykaj.
- [ ] **Krok 5: Dodaj widoczny tekstowy przycisk `Gotowe` do remastered headera.** Użyj `FilledButton.tonalIcon` zarówno w edytorze pełnoekranowym, jak i w panelu Windows. Przy wąskim widoku/200% tekście pozwól headerowi przejść do dwóch wierszy albo przenieś status zapisu pod pasek; nie ukrywaj tekstu `Gotowe` za samą ikoną. Przycisk ma minimum 48 dp wysokości. Klasyczny ekran pozostaje bez zmian.
- [ ] **Krok 6: Uruchom komplet testów `test/remaster_note_editor_test.dart` i `test/remaster_workspaces_test.dart`.** Potwierdź również niezależną akcję powrotu i niezmienione działanie autosave.
- [ ] **Krok 7: Zapisz commit.** `feat: add explicit done action to note editor`.

### Task 5: Migracja, integracja i końcowe sprawdzenie

**Pliki:**
- Zmień: `README.md`
- Zmień: `docs/WYDANIA.md`
- Weryfikuj: `supabase/note_folders.sql`
- Weryfikuj: `test/note_folder_test.dart`, `test/note_folder_sync_outbox_test.dart`, `test/note_library_cards_test.dart`, `test/note_library_state_test.dart`, `test/remaster_folder_dialog_test.dart`, `test/remaster_note_editor_test.dart`, `test/remaster_layout_test.dart`

**Interfejsy:**
- Instrukcja Supabase powie wprost uruchomić rozszerzony `supabase/note_folders.sql`, jeśli konto korzysta z synchronizowanych folderów.
- Wydanie wymieni kontrolki folderu i `Gotowe`; nie zmieniaj numeru wersji automatycznie.

Polecenia końcowej weryfikacji wykonywane z katalogu projektu:

```powershell
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
flutter build windows --release --no-pub --dart-define-from-file=.env
flutter build apk --release --no-pub --dart-define-from-file=.env
```

- [ ] **Krok 1: Zaktualizuj instrukcję migracji.** Dodaj do README informację, że rozszerzona kolumna `emoji` jest opcjonalna, skrypt idempotentny i bezpieczny do ponownego uruchomienia; RLS i Realtime nie wymagają zmian.
- [ ] **Krok 2: Dodaj krótką notkę wydania.** Opisz czytelniejsze kolory, datę z godziną, sortowanie oraz edycję nazwy/koloru/emoji folderu i przycisk `Gotowe`.
- [ ] **Krok 3: Sprawdź integrację offline.** Uruchom testy folder outbox i `NoteSyncService`; potwierdź, że błąd cloud zapisu pozostawia zmianę lokalną w kolejce. Nie drukuj tokenów ani zawartości `.env`.
- [ ] **Krok 4: Uruchom pełny zestaw weryfikacji.** `flutter analyze --no-pub`; `flutter test --no-pub --concurrency=1`; `flutter build windows --release --no-pub --dart-define-from-file=.env`; `flutter build apk --release --no-pub --dart-define-from-file=.env` z istniejącym kluczem podpisującym.
- [ ] **Krok 5: Sprawdź UI przy 390×844, 768×1024, 1366×768 i 200% skalowania.** W testach/uruchomionej aplikacji sprawdź dark mode: grafitowa neutralna karta ma czytelną krawędź, pastelowe karty są wyraźne, chipy emoji nie obcinają nazw, a panel folderów mieści liczniki.
- [ ] **Krok 6: Sprawdź migrację SQL pod kątem bezpieczeństwa.** Potwierdź `IF NOT EXISTS`, nullable pole, limit długości i brak zmian w politykach RLS/FK/Realtime.
- [ ] **Krok 7: Zapisz commit dokumentacji i podsumowania.** `docs: document note folder emoji migration`.
- [ ] **Krok 8: Przekaż użytkownikowi plik migracji do uruchomienia w Supabase SQL Editor przed oczekiwaniem synchronizacji emoji na innych urządzeniach.** Po wdrożeniu lokalne zmiany mogą pozostać w kolejce; wykonaj ponowną synchronizację.
