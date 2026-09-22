# Notatki — przebudowa według referencji Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zastąpić stary listowy ekran Notatek biblioteką pastelowych kart oraz przebudowanym edytorem, spójnymi na Androidzie i Windowsie.

**Architecture:** Dane, lokalny zapis i synchronizacja pozostają bez zmian. Nowy, czysty model selekcji biblioteki wybiera notatki według widoku, folderu i wyszukiwania. Ekran Notatek składa niezależne komponenty kart, filtrów oraz bocznego panelu desktopowego; edytor zachowuje autosave i bloki, ale dostaje nową kompozycję oraz opcjonalny tryb osadzony.

**Tech Stack:** Flutter/Dart, Material 3, Manrope, flutter_test oraz obecna synchronizacja Supabase.

**Spec:** `docs/superpowers/specs/2026-09-22-notes-reference-rebuild-design.md`

## Global Constraints

- Nie zmieniaj modeli `NoteItem` i `NoteFolder`, tabel Supabase ani mechanizmów synchronizacji.
- Nie dodawaj paczki do masonry; użyj `LayoutBuilder` i kolumn Fluttera.
- Każda karta, również `NoteColorKey.neutral`, dostaje pastelową powierzchnię.
- Pod 600 dp biblioteka jest mobilna, od 1100 dp ma panel folderów i osadzony edytor.
- Przypomnienia, archiwum i kosz pozostają dostępne tylko jako widoki pomocnicze.
- Dotykowe elementy mają 48×48 dp, a ikony etykiety semantyczne.
- Przed przekazaniem uruchom rzeczywisty build Windows oraz podpisany APK Androida; nie publikuj wersji.

## Review Focus

- Długie nazwy folderów i tekst 200% nie powodują overflow telefonu.
- Neutralna notatka ma pastelową, a nie ciemną kartę.
- Widoki Wszystkie, Przypięte, folder, Archiwum i Kosz nie mieszają stanów notatek.
- Zamknięcie panelu edytora Windows zachowuje filtr, wyszukiwanie i pozycję biblioteki.
- Błąd synchronizacji jest widoczny, ale nie blokuje istniejących kart ani ponowienia.

---

## File Structure

- Create: `lib/note_library_state.dart` — filtry, sortowanie oraz liczniki folderów.
- Create: `lib/note_library_cards.dart` — pastelowa karta i responsywny układ kolumn.
- Create: `lib/note_library_chrome.dart` — nagłówek, filtry, menu pomocnicze i panel folderów.
- Modify: `lib/remaster_notes_screen.dart` — responsywne składanie biblioteki oraz panelu edytora.
- Modify: `lib/note_editor_screen.dart` — nowy edytor mobilny i panelowy.
- Modify: `lib/main.dart` — fabryka osadzonego edytora i istniejące callbacki.
- Modify: `lib/remaster_theme.dart` — semantyczna paleta kart.
- Create: `test/note_library_state_test.dart` i `test/note_library_cards_test.dart`.
- Modify: `test/remaster_workspaces_test.dart`, `test/remaster_note_editor_test.dart`, `test/remaster_layout_test.dart`.

### Task 1: Stan i filtrowanie biblioteki

**Files:**
- Create: `lib/note_library_state.dart`
- Create: `test/note_library_state_test.dart`

**Interfaces:**
- Produces `enum NoteLibraryScope { all, pinned, reminders, archive, trash }`.
- Produces `class NoteLibrarySelection { const NoteLibrarySelection({this.scope = NoteLibraryScope.all, this.folderId, this.query = ''}); final NoteLibraryScope scope; final String? folderId; final String query; NoteLibrarySelection copyWith({NoteLibraryScope? scope, Object? folderId = _unchanged, String? query}); }`.
- Produces `selectNotesForLibrary(...)` and `visibleFolderCount(...)`.

- [ ] **Step 1: Write failing state tests.**

```dart
test('all excludes archived and deleted notes while pinned keeps only active pins', () {
  final notes = [
    NoteItem(id: 'active-pin', title: 'Plan', pinned: true),
    NoteItem(id: 'archive-pin', title: 'Stary', pinned: true, archivedAt: DateTime(2026, 9, 1)),
    NoteItem(id: 'trash', title: 'Kosz', deletedAt: DateTime(2026, 9, 1)),
  ];
  expect(selectNotesForLibrary(notes: notes, folders: const [], selection: const NoteLibrarySelection()).map((n) => n.id), ['active-pin']);
  expect(selectNotesForLibrary(notes: notes, folders: const [], selection: const NoteLibrarySelection(scope: NoteLibraryScope.archive)).map((n) => n.id), ['archive-pin']);
  expect(selectNotesForLibrary(notes: notes, folders: const [], selection: const NoteLibrarySelection(scope: NoteLibraryScope.trash)).map((n) => n.id), ['trash']);
});

test('search finds a folder name and folder count excludes archived content', () {
  final folders = [NoteFolder(id: 'work', name: 'Praca')];
  final notes = [
    NoteItem(id: 'active', title: 'Oferta', folderId: 'work'),
    NoteItem(id: 'archived', title: 'Stary', folderId: 'work', archivedAt: DateTime(2026, 9, 1)),
  ];
  expect(selectNotesForLibrary(notes: notes, folders: folders, selection: const NoteLibrarySelection(query: 'praca')).single.id, 'active');
  expect(visibleFolderCount(notes: notes, folderId: 'work'), 1);
});
```

- [ ] **Step 2: Run the tests to confirm failure.**

Run: `flutter test test/note_library_state_test.dart`

Expected: FAIL because the state types do not exist.

- [ ] **Step 3: Implement the pure selection model.**

```dart
enum NoteLibraryScope { all, pinned, reminders, archive, trash }

class NoteLibrarySelection {
  const NoteLibrarySelection({this.scope = NoteLibraryScope.all, this.folderId, this.query = ''});
  final NoteLibraryScope scope;
  final String? folderId;
  final String query;
}
```

Filter status first, then folder and combined title/preview/labels/folder-name search. Sort active pins first, then descending `updatedAt`. `visibleFolderCount` counts only non-archived, non-deleted notes.

- [ ] **Step 4: Run the tests to confirm pass.**

Run: `flutter test test/note_library_state_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/note_library_state.dart test/note_library_state_test.dart
git commit -m "feat: add note library selection state"
```

### Task 2: Pastelowe karty oraz naturalna siatka

**Files:**
- Create: `lib/note_library_cards.dart`
- Modify: `lib/remaster_theme.dart`
- Create: `test/note_library_cards_test.dart`

**Interfaces:**
- Produces `Color noteLibraryCardColor(NoteItem note, int visualIndex)`.
- Produces `NoteLibraryCard(note, visualIndex, onOpen, onMore)`.
- Produces `NoteMasonryGrid(notes, folders, onOpen, onMore, minCardWidth)`.

- [ ] **Step 1: Write failing card tests.**

```dart
testWidgets('neutral note still uses a pastel card and checklist items are visible', (tester) async {
  final note = NoteItem(id: 'shopping', title: 'Zakupy', blocks: [
    NoteBlock.checklist(id: 'list', items: const [
      NoteChecklistItem(id: 'milk', text: 'Mleko'),
      NoteChecklistItem(id: 'bread', text: 'Chleb'),
    ]),
  ]);
  await tester.pumpWidget(app(NoteLibraryCard(note: note, visualIndex: 0, onOpen: () {}, onMore: () {})));
  expect(find.byKey(const ValueKey('note-library-card-shopping')), findsOneWidget);
  expect(find.text('Mleko'), findsOneWidget);
  expect(find.text('Chleb'), findsOneWidget);
});

testWidgets('grid uses two columns on a phone and one with 200 percent text', (tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final grid = NoteMasonryGrid(notes: [NoteItem(id: 'one'), NoteItem(id: 'two')], folders: const [], onOpen: (_) {}, onMore: (_, __) {});
  await tester.pumpWidget(app(grid));
  expect(find.byKey(const ValueKey('note-library-column-0')), findsOneWidget);
  expect(find.byKey(const ValueKey('note-library-column-1')), findsOneWidget);
  await tester.pumpWidget(app(MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(2)), child: grid)));
  expect(find.byKey(const ValueKey('note-library-column-1')), findsNothing);
});
```

- [ ] **Step 2: Run the tests to confirm failure.**

Run: `flutter test test/note_library_cards_test.dart`

Expected: FAIL because the new widgets do not exist.

- [ ] **Step 3: Implement the five-color palette and card content.**

```dart
Color noteLibraryCardColor(NoteItem note, int visualIndex) {
  const palette = [Color(0xffdbeafe), Color(0xffe9ddff), Color(0xffd9f0e5), Color(0xffffefd6), Color(0xffffe0db)];
  final index = note.colorKey == NoteColorKey.neutral ? visualIndex : note.colorKey.index - 1;
  return palette[index % palette.length];
}
```

Each card displays title, three text lines, four checklist items or an image/attachment summary, date and optional pin. Use dark foreground text on all pastel surfaces. Keep `PopupMenuButton` actions but remove old row-style controls.

- [ ] **Step 4: Implement `NoteMasonryGrid`.**

Use `LayoutBuilder`; choose two columns under 600 dp at normal text, one column at 200% text, and three or more columns on desktop. Allocate cards to the currently shortest column using `estimatedNoteHeight(note)`. Use `Row` + `Expanded` + `Column` to let individual cards keep natural height without a third-party dependency.

- [ ] **Step 5: Run card tests.**

Run: `flutter test test/note_library_cards_test.dart`

Expected: PASS without render exceptions or horizontal overflow.

- [ ] **Step 6: Commit.**

```bash
git add lib/note_library_cards.dart lib/remaster_theme.dart test/note_library_cards_test.dart
git commit -m "feat: add pastel note card library"
```

### Task 3: Mobilna biblioteka zgodna z referencją

**Files:**
- Create: `lib/note_library_chrome.dart`
- Modify: `lib/remaster_notes_screen.dart`
- Modify: `test/remaster_workspaces_test.dart`

**Interfaces:**
- Produces `NotesLibraryHeader`, `NotesFilterStrip` and `NotesOverflowMenu`.
- Preserves public `RemasterNotesScreen` callbacks and `PageStorageKey('remaster-notes-scroll')`.

- [ ] **Step 1: Replace legacy layout expectations with a failing reference-layout test.**

```dart
testWidgets('phone library has greeting, one filter strip and cards without legacy sections', (tester) async {
  await tester.pumpWidget(phoneApp(RemasterNotesScreen(
    greetingName: 'Adrian',
    notes: [NoteItem(id: 'plan', title: 'Plan na tydzień')],
    folders: [NoteFolder(id: 'work', name: 'Praca')],
    onNewNote: ({folderId}) {}, onOpenNote: (_) {}, onSave: (_) async {}, onDelete: (_) async {},
  )));
  expect(find.text('Dzień dobry, Adrian!'), findsOneWidget);
  expect(find.byKey(const ValueKey('notes-filter-strip')), findsOneWidget);
  expect(find.byKey(const ValueKey('note-library-card-plan')), findsOneWidget);
  expect(find.text('Przypomnienia'), findsNothing);
  expect(find.text('Archiwum'), findsNothing);
  expect(find.text('Kosz'), findsNothing);
});
```

- [ ] **Step 2: Add a failing menu test.**

```dart
testWidgets('more menu exposes reminders archive and trash', (tester) async {
  await tester.tap(find.byTooltip('Więcej widoków notatek'));
  await tester.pumpAndSettle();
  expect(find.text('Przypomnienia'), findsOneWidget);
  expect(find.text('Archiwum'), findsOneWidget);
  expect(find.text('Kosz'), findsOneWidget);
});
```

- [ ] **Step 3: Run to confirm the old screen fails the new acceptance tests.**

Run: `flutter test test/remaster_workspaces_test.dart`

Expected: FAIL on the missing filter strip and missing card key.

- [ ] **Step 4: Rebuild the mobile composition.**

Replace `_NoteSection`, `NoteListFilters`, `_FolderStrip` and `_NoteCards` in `RemasterNotesScreen` with a single `NoteLibrarySelection`. The order must be: greeting header, search, `NotesFilterStrip`, compact sync status when needed, `NoteMasonryGrid`. The strip contains Wszystkie, Przypięte, and folders only. Przypomnienia, Archiwum and Kosz live inside `NotesOverflowMenu`.

- [ ] **Step 5: Preserve all existing actions.**

Use existing callbacks: `onSave` for pin/archive/restore, `onDelete` for trash, `onPermanentlyDelete` only in trash, `onMoveToFolder` for a chosen folder, and `onSetWidgetNote` for the Android widget. Do not create endpoints or change synchronization.

- [ ] **Step 6: Run mobile tests.**

Run: `flutter test test/remaster_workspaces_test.dart test/note_library_cards_test.dart`

Expected: PASS; 390×844 and 200% text render without overflow.

- [ ] **Step 7: Commit.**

```bash
git add lib/note_library_chrome.dart lib/remaster_notes_screen.dart test/remaster_workspaces_test.dart
git commit -m "feat: rebuild mobile notes library"
```

### Task 4: Desktopowy panel folderów i osadzony edytor

**Files:**
- Modify: `lib/note_library_chrome.dart`
- Modify: `lib/remaster_notes_screen.dart`
- Modify: `lib/note_editor_screen.dart`
- Modify: `lib/main.dart`
- Modify: `test/remaster_workspaces_test.dart`
- Modify: `test/remaster_note_editor_test.dart`

**Interfaces:**
- Produces `NotesDesktopSidebar(folders, notes, selection, onSelectionChanged)`.
- Produces `typedef RemasterNoteEditorBuilder = Widget Function(NoteItem note, VoidCallback onClose);`.
- Produces `NoteEditorScreen.onClose`, used whenever `embedded` is true.

- [ ] **Step 1: Write a failing desktop-context test.**

```dart
testWidgets('desktop shows folders and keeps selection after opening editor', (tester) async {
  tester.view.physicalSize = const Size(1366, 768);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app(RemasterNotesScreen(
    notes: [NoteItem(id: 'work-note', title: 'Oferta', folderId: 'work')],
    folders: [NoteFolder(id: 'work', name: 'Praca')],
    editorBuilder: (_, __) => const SizedBox(),
    onNewNote: ({folderId}) {}, onOpenNote: (_) {}, onSave: (_) async {}, onDelete: (_) async {},
  )));
  await tester.tap(find.text('Praca').last);
  await tester.tap(find.byKey(const ValueKey('note-library-card-work-note')));
  await tester.pump();
  expect(find.byKey(const ValueKey('notes-desktop-sidebar')), findsOneWidget);
  expect(find.byKey(const ValueKey('notes-detail-panel')), findsOneWidget);
  expect(find.text('Praca').last, findsOneWidget);
});
```

- [ ] **Step 2: Write a failing embedded-editor close test.**

```dart
testWidgets('embedded editor closes through callback rather than navigator', (tester) async {
  var closed = false;
  await tester.pumpWidget(MaterialApp(home: NoteEditorScreen(
    embedded: true, remastered: true, onClose: () => closed = true,
    note: NoteItem(id: 'n', title: 'Plan'), onSave: (_) async {}, onDelete: (_) async {},
  )));
  await tester.tap(find.byTooltip('Wróć do notatek'));
  expect(closed, isTrue);
});
```

- [ ] **Step 3: Run to confirm failure.**

Run: `flutter test test/remaster_workspaces_test.dart test/remaster_note_editor_test.dart`

Expected: FAIL because sidebar, `editorBuilder` and `onClose` do not exist.

- [ ] **Step 4: Implement the desktop composition.**

At width `>= 1100`, render `Row(NotesDesktopSidebar, divider, Expanded(library), optional divider, editor panel)`. Sidebar width is 224 dp; editor width is 420 dp. Sidebar shows Wszystkie, folders with `visibleFolderCount`, Przypięte, Archiwum and Kosz. Card click selects a note; close clears only `_selectedNoteId`.

- [ ] **Step 5: Wire the embedded editor in `main.dart`.**

```dart
editorBuilder: (note, onClose) => NoteEditorScreen(
  embedded: true, remastered: true, onClose: onClose, note: note,
  folders: folders, onMoveToFolder: _moveNoteToFolder,
  onSave: _saveNote, onDelete: _deleteNote,
  onCreateTask: (source, title) => _quickAddTask(title, sourceNoteId: source.id),
  onAttach: _attachNoteFile, onDeleteAttachment: _deleteNoteAttachment,
  onOpenAttachment: _openNoteAttachment,
),
```

Pass the same folder callbacks to route-based mobile `NoteEditorScreen`.

- [ ] **Step 6: Run desktop and editor tests.**

Run: `flutter test test/remaster_workspaces_test.dart test/remaster_note_editor_test.dart`

Expected: PASS; phone remains full-screen, desktop retains selected filter and shows a panel.

- [ ] **Step 7: Commit.**

```bash
git add lib/note_library_chrome.dart lib/remaster_notes_screen.dart lib/note_editor_screen.dart lib/main.dart test/remaster_workspaces_test.dart test/remaster_note_editor_test.dart
git commit -m "feat: add desktop notes context and editor panel"
```

### Task 5: Finalna kompozycja edytora i weryfikacja

**Files:**
- Modify: `lib/note_editor_screen.dart`
- Modify: `test/remaster_note_editor_test.dart`
- Modify: `test/remaster_layout_test.dart`
- Modify: `docs/WYDANIA.md`

**Interfaces:**
- Preserves keys `remaster-note-editor`, `note-title-field`, `note-save-status`, `note-save-retry`.
- Consumes `folders`, `onMoveToFolder`, existing attachment callbacks and existing blocks.

- [ ] **Step 1: Write failing visual-structure tests for the editor.**

```dart
testWidgets('remastered editor shows back, save status, pin action and selected folder', (tester) async {
  await tester.pumpWidget(editorApp(NoteEditorScreen(
    remastered: true, note: NoteItem(id: 'week', title: 'Plan', folderId: 'work'),
    folders: [NoteFolder(id: 'work', name: 'Praca')], onMoveToFolder: (_, __) async {},
    onSave: (_) async {}, onDelete: (_) async {},
  )));
  expect(find.byTooltip('Wróć do notatek'), findsOneWidget);
  expect(find.byTooltip('Przypnij notatkę'), findsOneWidget);
  expect(find.text('Praca'), findsOneWidget);
  expect(find.text('Edytujesz notatkę'), findsNothing);
});
```

- [ ] **Step 2: Run to confirm the current editor fails.**

Run: `flutter test test/remaster_note_editor_test.dart`

Expected: FAIL because the current header displays `Edytujesz notatkę` and has no folder chip or pin action.

- [ ] **Step 3: Implement the reference editor composition.**

For `remastered`, render a back action, compact save state, pin action and overflow menu. Under it show folder chip/menu, large title, text, checklist blocks and a `Załączniki` section with `Dodaj`. Move reminder, labels, block insertion and trash into overflow/secondary actions. Keep autosave, retries, attachment behavior and existing block controls.

- [ ] **Step 4: Extend layout coverage.**

In `test/remaster_layout_test.dart`, render `RemasterNotesScreen` with three notes and two folders instead of `Center('Lista notatek')`. Exercise `390×844`, `768×1024`, `1366×768`, `1440×900`, `844×390`, dark/light and text scale `1.0/2.0`; assert `tester.takeException()` is null after opening Notes.

- [ ] **Step 5: Run module tests.**

Run: `flutter test test/note_library_state_test.dart test/note_library_cards_test.dart test/remaster_workspaces_test.dart test/remaster_note_editor_test.dart test/remaster_layout_test.dart`

Expected: PASS.

- [ ] **Step 6: Run final verification and builds.**

Run: `flutter analyze --no-pub`

Expected: exit code 0.

Run: `flutter test`

Expected: exit code 0.

Run: `flutter build windows --release --no-pub --dart-define-from-file=.env`

Expected: `Built build/windows/x64/runner/Release/dzien_po_dniu.exe`.

Run: `flutter build apk --release --no-pub --build-name 1.1.9 --build-number 1001012 --dart-define=APP_VERSION=1.1.9 --dart-define-from-file=.env`

Expected: `Built build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 7: Record the preview and commit.**

Add to `docs/WYDANIA.md`: `Podgląd przebudowy Notatek: Android i Windows otrzymują bibliotekę pastelowych kart, nowy edytor oraz kontekst folderów na desktopie.`

```bash
git add lib/note_editor_screen.dart test/remaster_note_editor_test.dart test/remaster_layout_test.dart docs/WYDANIA.md
git commit -m "feat: finish reference notes experience"
```

## Spec Coverage Review

- Biblioteka mobilna z powitaniem, wyszukiwaniem, filtrami i kartami: Task 3.
- Pastelowe karty, checklisty, załączniki i neutralny kolor: Task 2.
- Przypomnienia, archiwum i kosz jako widoki pomocnicze: Tasks 1 i 3.
- Mobilny i desktopowy edytor: Tasks 4 i 5.
- Foldery i liczniki na Windowsie: Tasks 1 i 4.
- Dane, autosave, kosz, załączniki i synchronizacja: Tasks 1, 3, 4 i 5.
- Duży tekst, responsywność i buildy: Tasks 2 i 5.
