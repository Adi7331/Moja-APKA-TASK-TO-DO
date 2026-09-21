# Notes List Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current Notes card grid with a responsive, list-first notebook while preserving all existing note data, folders, attachments, offline persistence, conflict handling, and Supabase synchronization.

**Architecture:** Keep `RemasterNotesScreen` as the owner of query, section, folder, label, selection, and scroll state. Split presentation into focused list-row, filter-bar, and desktop-detail components; keep `NoteEditorScreen` and the existing callbacks as the data boundary. Use width-based layout switching: full-screen editor below 600 dp, adaptive single-column layout from 600–1099 dp, and list plus detail panel from 1100 dp.

**Tech Stack:** Flutter/Dart, Material 3, existing `NoteItem`/`NoteFolder` models, existing local store/outbox and Supabase services, `flutter_test` widget tests.

**Spec:** `docs/superpowers/specs/2026-09-21-notes-list-redesign-design.md`

## Global Constraints

- The primary Notes presentation is a vertical list; colors are only subtle accents.
- Existing `NoteItem`, `NoteFolder`, labels, attachments, trash, offline queue, conflicts, Realtime, and Supabase owner policies remain compatible.
- The main content must not horizontally overflow at 390x844, 768x1024, 1366x768, 1440x900, or 200% text scale.
- Icon controls expose semantics, visible keyboard focus, and a minimum 48x48 dp touch target.
- Desktop uses a right detail panel at widths >=1100 dp; narrower layouts open the editor as a separate full-height surface.
- No Supabase schema or sync protocol changes are part of this UI plan.

## Review Focus

- Long Polish titles, labels, and folder names: the row truncates predictably without changing its height into an overflow.
- Empty, loading, error, and offline states: the screen explains what happened and keeps the local note visible.
- 200% text scale and narrow phone width: controls wrap or scroll inside their own regions, never the page.
- Desktop selection versus opening: selecting a row updates the detail panel; opening the same note still reaches the full editor.
- Notes with checklists, tables, attachments, reminders, archived/deleted flags, and conflicts: each retains a visible, understandable status.

## File Map

- Modify `lib/remaster_notes_screen.dart`: state coordination, list-first composition, responsive layout, and wiring of existing callbacks.
- Create `lib/note_list_row.dart`: one accessible, reusable list row for a `NoteItem`.
- Create `lib/note_list_filters.dart`: search field, section chips, folder/label filters, and composer actions.
- Modify `lib/note_editor_screen.dart`: preserve the current editor capabilities while making the title/body hierarchy and save state fit the new surface.
- Modify `test/notes_screen_test.dart`: list-first behavior, filtering, actions, and regression coverage.
- Modify `test/remaster_layout_test.dart`: width and text-scale layout assertions.
- Modify `test/remaster_note_editor_test.dart`: editor entry, status, and retained blocks/attachments.
- Create `test/note_list_row_test.dart`: isolated row semantics, truncation, and status indicators.

### Task 1: Extract and test the accessible note row

**Files:**
- Create: `lib/note_list_row.dart`
- Create: `test/note_list_row_test.dart`
- Modify: `lib/remaster_notes_screen.dart:876-1254` (replace the current card rendering after the new row exists)

**Interfaces:**
- Consumes: `NoteItem note`, optional `NoteFolder folder`, `bool selected`, `VoidCallback onTap`, `VoidCallback onOpen`, `Future<void> Function(NoteItem) onSave`, `Future<void> Function(NoteItem) onDelete`, optional `Future<void> Function(NoteItem, String?) onMoveToFolder`.
- Produces: `class NoteListRow extends StatelessWidget` with a stable `ValueKey('note-row-${note.id}')` and one semantic button/container for the primary row action.

- [ ] **Step 1: Write failing row tests**

```dart
testWidgets('renders title, preview, folder and attachment status', (tester) async {
  final note = NoteItem(
    id: 'n1',
    title: 'Plan tygodnia',
    folderId: 'f1',
    blocks: const [NoteBlock.text(id: 'b1', text: 'Najważniejsze rzeczy do zrobienia')],
    attachments: [NoteAttachment(id: 'a1', fileName: 'plan.pdf', mimeType: 'application/pdf', byteSize: 100)],
  );
  await tester.pumpWidget(buildRow(note));
  expect(find.text('Plan tygodnia'), findsOneWidget);
  expect(find.textContaining('Najważniejsze rzeczy'), findsOneWidget);
  expect(find.text('Praca'), findsOneWidget);
  expect(find.byTooltip('Załączniki: 1'), findsOneWidget);
});

testWidgets('long text truncates without horizontal overflow', (tester) async {
  await tester.pumpWidget(buildRow(longNote()));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `flutter test --no-pub test/note_list_row_test.dart`

Expected: FAIL because `NoteListRow` and the row test harness do not exist.

- [ ] **Step 3: Implement the minimal row**

Implement `NoteListRow` with a `Material` surface, a 4 dp leading accent from the existing `NoteColorKey`, title and preview using `maxLines`/ellipsis, folder and label metadata, date/reminder text, checklist progress, attachment count, conflict/offline status, and a trailing `PopupMenuButton` with semantic tooltip. Use `Semantics(button: true, label: ...)` and `ConstrainedBox(minHeight: 72)` so the whole row remains keyboard- and touch-accessible.

- [ ] **Step 4: Replace the current card body with list rows**

Change `_NoteCards` so it emits a `SliverList` of `NoteListRow` widgets, retaining pinned/remaining section headers, selection, open-on-tap behavior, folder move, delete, permanent delete, and widget-note callbacks. Do not alter filtering or persistence callbacks.

- [ ] **Step 5: Run focused tests**

Run: `flutter test --no-pub test/note_list_row_test.dart test/notes_screen_test.dart`

Expected: PASS, with existing card-specific assertions updated to assert the list row semantics instead.

- [ ] **Step 6: Commit**

```powershell
git add lib/note_list_row.dart lib/remaster_notes_screen.dart test/note_list_row_test.dart test/notes_screen_test.dart
git commit -m "feat: add accessible notes list rows"
```

### Task 2: Build the list-first search, filters, and composer

**Files:**
- Create: `lib/note_list_filters.dart`
- Modify: `lib/remaster_notes_screen.dart:169-357, 626-875`
- Modify: `test/notes_screen_test.dart`

**Interfaces:**
- Consumes: `_NoteSection`, `List<NoteFolder>`, `List<String> labels`, current query/folder/label values, and the existing `NewRemasterNote`/folder callbacks.
- Produces: `NoteListFilters` with `ValueChanged<String> onQueryChanged`, `ValueChanged<_NoteSection> onSectionChanged`, `ValueChanged<String?> onFolderChanged`, `ValueChanged<String?> onLabelChanged`, and the existing creation callbacks.

- [ ] **Step 1: Add failing filter/composer tests**

```dart
testWidgets('search and folder filters keep the list first', (tester) async {
  await tester.pumpWidget(buildNotes(notes: [note('Praca'), note('Dom')]));
  await tester.enterText(find.byType(TextField).first, 'Praca');
  await tester.pump();
  expect(find.byKey(const ValueKey('note-row-praca')), findsOneWidget);
  expect(find.byKey(const ValueKey('note-row-dom')), findsNothing);
});

testWidgets('composer exposes note, checklist, image and file actions', (tester) async {
  await tester.pumpWidget(buildNotes());
  expect(find.byTooltip('Nowa notatka'), findsOneWidget);
  expect(find.byTooltip('Nowa checklista'), findsOneWidget);
  expect(find.byTooltip('Dodaj zdjęcie'), findsOneWidget);
  expect(find.byTooltip('Dodaj plik'), findsOneWidget);
});
```

- [ ] **Step 2: Run the tests and verify the new expectations fail**

Run: `flutter test --no-pub test/notes_screen_test.dart`

Expected: FAIL for the new `note-row-*` keys and tooltip expectations.

- [ ] **Step 3: Implement `NoteListFilters`**

Move the existing search, section chips, folder strip, label strip, and composer into `NoteListFilters`. Keep the filter chips in a horizontally scrollable `SingleChildScrollView` constrained to its own height; keep the page itself vertical. Give all icon actions Polish tooltips and preserve the selected folder when creating a note.

- [ ] **Step 4: Wire filters into `RemasterNotesScreen`**

Replace the current `_Composer`, `_FolderStrip`, `_LabelStrip`, and header composition with `NoteListFilters`. Keep `_query`, `_section`, `_folderId`, `_label`, and `PageStorageKey('remaster-notes-scroll')` in the parent so switching modules does not reset state.

- [ ] **Step 5: Run tests and commit**

Run: `flutter test --no-pub test/notes_screen_test.dart test/note_list_row_test.dart`

Expected: PASS with note creation actions and all four note sections still reachable.

```powershell
git add lib/note_list_filters.dart lib/remaster_notes_screen.dart test/notes_screen_test.dart
git commit -m "feat: add list-first notes filters"
```

### Task 3: Implement responsive list/detail behavior

**Files:**
- Modify: `lib/remaster_notes_screen.dart:58-167, 1257-1312`
- Modify: `test/remaster_layout_test.dart`
- Modify: `test/notes_screen_test.dart`

**Interfaces:**
- Consumes: `List<NoteItem> notes`, current `_selectedNoteId`, `ValueChanged<NoteItem> onOpenNote`, and the shared list/filter components from Tasks 1–2.
- Produces: responsive behavior where `maxWidth >= 1100` renders list + detail, `600 <= maxWidth < 1100` renders the list with a separate editor route/surface, and `<600` renders a full-screen editor surface.

- [ ] **Step 1: Add failing width tests**

```dart
testWidgets('desktop shows a detail panel after selecting a note', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1366, 768));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(buildNotes(notes: [note('Plan')]));
  await tester.tap(find.byKey(const ValueKey('note-row-n1')));
  await tester.pump();
  expect(find.byKey(const ValueKey('notes-detail-panel')), findsOneWidget);
});

testWidgets('phone does not render a desktop detail panel', (tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(buildNotes(notes: [note('Plan')]));
  expect(find.byKey(const ValueKey('notes-detail-panel')), findsNothing);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run the layout tests and verify failure**

Run: `flutter test --no-pub test/remaster_layout_test.dart test/notes_screen_test.dart`

Expected: FAIL because the current detail surface has no stable key and the list still uses card layout.

- [ ] **Step 3: Implement width-based composition**

Give the desktop detail `SizedBox` the key `notes-detail-panel`, preserve the existing `_NotePreview` content, and make the outer composition use a `Row` only at >=1100 dp. At smaller widths, open `NoteEditorScreen` using the existing `onOpenNote` callback and return to the list without clearing `_selectedNoteId`, filters, or scroll position.

- [ ] **Step 4: Add desktop keyboard/focus behavior**

Wrap each row in a focusable control with visible focus decoration. Ensure `Esc` closes the editor surface where the parent owns the route, and `Ctrl+K` focuses the existing search controller without changing the persisted data flow.

- [ ] **Step 5: Run tests and commit**

Run: `flutter test --no-pub test/remaster_layout_test.dart test/notes_screen_test.dart`

Expected: PASS at 390, 768, 1366, and 1440 width fixtures with no overflow exceptions.

```powershell
git add lib/remaster_notes_screen.dart test/remaster_layout_test.dart test/notes_screen_test.dart
git commit -m "feat: make notes list responsive across widths"
```

### Task 4: Align the editor with the new writing surface

**Files:**
- Modify: `lib/note_editor_screen.dart:11-400`
- Modify: `test/remaster_note_editor_test.dart`

**Interfaces:**
- Consumes: the existing `NoteEditorScreen` constructor, `NoteItem` blocks, attachments, folder/color/reminder callbacks, and save/delete callbacks.
- Produces: the same public editor API with a clearer title/body hierarchy and an explicit save/sync status slot.

- [ ] **Step 1: Add failing editor expectations**

```dart
testWidgets('editor shows writing body before secondary options', (tester) async {
  await tester.pumpWidget(buildEditor(noteWithTitleAndBody()));
  final titleY = tester.getTopLeft(find.text('Plan tygodnia')).dy;
  final bodyY = tester.getTopLeft(find.textContaining('Najważniejsze')).dy;
  expect(bodyY, greaterThan(titleY));
  expect(find.text('Lista kroków'), findsOneWidget);
});

testWidgets('editor exposes a visible local save status', (tester) async {
  await tester.pumpWidget(buildEditor(noteWithTitleAndBody()));
  expect(find.byKey(const ValueKey('note-save-status')), findsOneWidget);
});
```

- [ ] **Step 2: Run the editor tests and verify failure**

Run: `flutter test --no-pub test/remaster_note_editor_test.dart`

Expected: FAIL for the new save-status key and reordered body/secondary options.

- [ ] **Step 3: Reorder the editor without changing its data contract**

Place the title, folder/color/reminder summary, and a minimum five-line body area at the top. Move checklist/table/attachment management into the existing secondary options surface, rename visible copy from “Małe kroki” to “Lista kroków”, and leave all block serialization and callbacks unchanged.

- [ ] **Step 4: Add save-status presentation**

Render `note-save-status` from the existing local/sync state passed by the host. The editor must continue to save locally before awaiting remote synchronization; a failed remote save keeps the editor open and offers a retry action.

- [ ] **Step 5: Run editor and regression tests, then commit**

Run: `flutter test --no-pub test/remaster_note_editor_test.dart test/notes_screen_test.dart test/note_sync_outbox_test.dart`

Expected: PASS with blocks, attachments, reminders, local queue, and retry behavior intact.

```powershell
git add lib/note_editor_screen.dart test/remaster_note_editor_test.dart
git commit -m "feat: refine notes writing surface"
```

### Task 5: Accessibility, visual regression, and full verification

**Files:**
- Modify: `test/remaster_layout_test.dart`
- Modify: `test/notes_screen_test.dart`
- Modify: `test/remaster_note_editor_test.dart`
- Modify: `README.md` or `docs/WYDANIA.md` only if the final release notes need the new Notes layout documented.

- [ ] **Step 1: Add the review-focus tests**

Add tests for 200% text scale, a 390 dp surface, long folder names, empty state, archived/trash sections, pinned ordering, checklist progress, attachment count, conflict indicator, and offline/error save status. Each test must assert `tester.takeException()` is null and inspect a stable semantic label or key.

- [ ] **Step 2: Run focused accessibility and layout tests**

Run: `flutter test --no-pub test/note_list_row_test.dart test/notes_screen_test.dart test/remaster_layout_test.dart test/remaster_note_editor_test.dart`

Expected: PASS with no overflow or semantics exceptions.

- [ ] **Step 3: Run static analysis**

Run: `flutter analyze --no-pub`

Expected: no analyzer errors or warnings introduced by the Notes redesign.

- [ ] **Step 4: Run the complete test suite**

Run: `flutter test --no-pub --concurrency=1`

Expected: all tests pass locally; if a hosted runner reports renderer-specific differences, record the exact failing test before changing CI behavior.

- [ ] **Step 5: Build both release targets**

Run: `flutter build windows --release --dart-define-from-file=.env`

Expected: Windows release build completes successfully.

Run: `flutter build apk --release --dart-define-from-file=.env`

Expected: signed/release APK build completes successfully using the existing release configuration.

- [ ] **Step 6: Commit verification documentation**

```powershell
git add test docs
git commit -m "test: verify responsive notes redesign"
```

