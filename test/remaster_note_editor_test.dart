import 'dart:async';

import 'package:dzien_po_dniu/note_editor_screen.dart';
import 'package:dzien_po_dniu/note_folder.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/remaster_notes_screen.dart';
import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editor color swatches match the library card palette', (
    tester,
  ) async {
    final theme = buildRemasterTheme(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: NoteEditorScreen(
          remastered: true,
          note: NoteItem(id: 'colors'),
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );
    final blue = find.byKey(const ValueKey('note-color-swatch-blue'));
    await tester.ensureVisible(blue);
    await tester.pumpAndSettle();
    expect(tester.getSize(blue), const Size(48, 48));
    final swatch = tester.widget<CircleAvatar>(
      find.descendant(of: blue, matching: find.byType(CircleAvatar)),
    );

    expect(
      swatch.backgroundColor,
      noteLibrarySurfaceForColor(NoteColorKey.blue, theme.colorScheme),
    );
  });

  testWidgets('embedded editor closes through callback rather than navigator', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorScreen(
          embedded: true,
          remastered: true,
          onClose: () => closed = true,
          note: NoteItem(id: 'embedded', title: 'Plan'),
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Wróć do notatek'));
    await tester.pump();

    expect(closed, isTrue);
  });

  testWidgets('Gotowe saves the current draft and closes the route', (
    tester,
  ) async {
    NoteItem? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<NoteItem>(
                    builder: (_) => NoteEditorScreen(
                      remastered: true,
                      note: NoteItem(id: 'done-route', title: 'Stary tytuł'),
                      onSave: (note) async => saved = note,
                      onDelete: (_) async {},
                    ),
                  ),
                ),
                child: const Text('Otwórz edytor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Otwórz edytor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-title-field')),
      'Nowy tytuł',
    );
    await tester.enterText(find.byType(TextField).at(1), 'Zapisany tekst');
    await tester.tap(find.byKey(const ValueKey('note-done-button')));
    await tester.pumpAndSettle();

    expect(saved?.title, 'Nowy tytuł');
    expect(saved?.blocks.first.text, 'Zapisany tekst');
    expect(find.byKey(const ValueKey('note-title-field')), findsNothing);
    expect(find.text('Otwórz edytor'), findsOneWidget);
  });

  testWidgets('Gotowe closes the embedded editor only after save succeeds', (
    tester,
  ) async {
    var closed = false;
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.dark),
        home: NoteEditorScreen(
          embedded: true,
          remastered: true,
          onClose: () => closed = true,
          note: NoteItem(id: 'done-embedded', title: 'Plan'),
          onSave: (_) async => saves++,
          onDelete: (_) async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-done-button')));
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(closed, isTrue);
  });

  testWidgets('autosave keeps edits made while a slow save is in flight', (
    tester,
  ) async {
    final firstSave = Completer<void>();
    final savedBodies = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.dark),
        home: NoteEditorScreen(
          embedded: true,
          remastered: true,
          note: NoteItem(
            id: 'autosave-in-flight',
            blocks: [NoteBlock.text(id: 'body', text: '')],
          ),
          onSave: (note) {
            savedBodies.add(note.blocks.first.text);
            if (savedBodies.length == 1) return firstSave.future;
            return Future<void>.value();
          },
          onDelete: (_) async {},
        ),
      ),
    );

    final body = find.byType(TextField).at(1);
    await tester.enterText(body, 'Pierwsza wersja');
    await tester.pump(const Duration(milliseconds: 601));
    expect(savedBodies, ['Pierwsza wersja']);

    await tester.enterText(body, 'Nowsza wersja');
    await tester.pump(const Duration(milliseconds: 601));
    firstSave.complete();
    await tester.pumpAndSettle();

    expect(savedBodies, ['Pierwsza wersja', 'Nowsza wersja']);
    expect(find.byKey(const ValueKey('note-title-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moving a note folder saves the current draft and revision', (
    tester,
  ) async {
    NoteItem? moved;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.light),
        home: NoteEditorScreen(
          remastered: true,
          note: NoteItem(
            id: 'move-folder',
            title: 'Stary tytuł',
            revision: 5,
            folderId: 'work',
            blocks: [NoteBlock.text(id: 'body', text: 'Stary tekst')],
          ),
          folders: [
            NoteFolder(id: 'work', name: 'Praca', emoji: '💼'),
            NoteFolder(id: 'home', name: 'Dom', emoji: '🏠'),
          ],
          onMoveToFolder: (note, _) async => moved = note,
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('note-title-field')),
      'Aktualny tytuł',
    );
    await tester.enterText(find.byType(TextField).at(1), 'Aktualny tekst');
    await tester.tap(find.text('💼 Praca'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('🏠 Dom').last);
    await tester.pumpAndSettle();

    expect(moved?.folderId, 'home');
    expect(moved?.revision, 6);
    expect(moved?.title, 'Aktualny tytuł');
    expect(moved?.blocks.first.text, 'Aktualny tekst');
    expect(tester.takeException(), isNull);
  });

  testWidgets('can create and immediately assign a folder from the picker', (
    tester,
  ) async {
    NoteItem? moved;
    var nextFolderId = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.dark),
        home: NoteEditorScreen(
          remastered: true,
          note: NoteItem(id: 'quick-create'),
          onCreateFolder: (context) async {
            final draft = await showRemasterFolderDialog(
              context: context,
              folders: const [],
            );
            if (draft == null) return null;
            return NoteFolder(
              id: 'quick-folder-${nextFolderId++}',
              name: draft.name,
              colorKey: draft.colorKey,
              emoji: draft.emoji,
            );
          },
          onMoveToFolder: (note, _) async => moved = note,
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('Bez folderu'));
    await tester.pumpAndSettle();
    expect(find.text('Utwórz nowy folder'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note-create-folder-action')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('folder-name-field')),
      'Pomysły',
    );
    await tester.enterText(
      find.byKey(const ValueKey('folder-emoji-field')),
      '💡',
    );
    await tester.tap(find.text('Utwórz'));
    await tester.pumpAndSettle();

    expect(moved?.folderId, 'quick-folder-0');
    expect(find.text('💡 Pomysły'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling folder creation leaves the note unchanged', (
    tester,
  ) async {
    NoteItem? moved;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.dark),
        home: NoteEditorScreen(
          remastered: true,
          note: NoteItem(id: 'cancel-create'),
          onCreateFolder: (context) async {
            await showRemasterFolderDialog(context: context, folders: const []);
            return null;
          },
          onMoveToFolder: (note, _) async => moved = note,
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('Bez folderu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-create-folder-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();

    expect(moved, isNull);
    expect(find.text('Bez folderu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed Gotowe keeps editor open and retry allows completion', (
    tester,
  ) async {
    var attempts = 0;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.light),
        home: NoteEditorScreen(
          embedded: true,
          remastered: true,
          onClose: () => closed = true,
          note: NoteItem(id: 'done-retry', title: 'Plan'),
          onSave: (_) async {
            attempts++;
            if (attempts == 1) throw StateError('offline');
          },
          onDelete: (_) async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-done-button')));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.textContaining('Błąd zapisu lokalnego'), findsOneWidget);
    expect(find.byKey(const ValueKey('note-done-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note-save-retry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-done-button')));
    await tester.pumpAndSettle();

    expect(attempts, 3);
    expect(closed, isTrue);
  });

  testWidgets('Gotowe stays visible on a narrow phone with 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: NoteEditorScreen(
              embedded: true,
              remastered: true,
              note: NoteItem(id: 'done-small'),
              onSave: (_) async {},
              onDelete: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gotowe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'remastered editor shows back, save status, pin action and selected folder',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRemasterTheme(Brightness.light),
          home: NoteEditorScreen(
            remastered: true,
            note: NoteItem(
              id: 'note-1',
              title: 'Plan na tydzień',
              folderId: 'work',
              blocks: [NoteBlock.text(id: 'text-1', text: 'Pierwszy krok')],
            ),
            onSave: (_) async {},
            onDelete: (_) async {},
            folders: [NoteFolder(id: 'work', name: 'Praca', emoji: '💼')],
            onMoveToFolder: (_, _) async {},
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('remaster-note-editor')),
        findsOneWidget,
      );
      expect(find.byTooltip('Wróć do notatek'), findsOneWidget);
      expect(find.byTooltip('Przypnij notatkę'), findsOneWidget);
      expect(find.text('💼 Praca'), findsOneWidget);
      expect(find.text('Edytujesz notatkę'), findsNothing);
      expect(find.byKey(const ValueKey('note-title-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-save-status')), findsOneWidget);
      await tester.tap(find.text('💼 Praca'));
      await tester.pumpAndSettle();
      expect(find.text('💼 Praca'), findsNWidgets(2));
    },
  );

  testWidgets('secondary blocks live under Więcej opcji with Lista kroków', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.light),
        home: NoteEditorScreen(
          remastered: true,
          note: NoteItem(
            id: 'note-3',
            title: 'Plan',
            blocks: [
              NoteBlock.text(id: 'text-3', text: 'Opis'),
              NoteBlock.checklist(id: 'check-3'),
            ],
          ),
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    expect(find.text('Więcej opcji'), findsOneWidget);
    await tester.ensureVisible(find.text('Więcej opcji'));
    await tester.tap(find.text('Więcej opcji'));
    await tester.pumpAndSettle();
    expect(find.text('Lista kroków'), findsOneWidget);
  });

  testWidgets('save error keeps the editor open and exposes retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.light),
        home: NoteEditorScreen(
          remastered: true,
          note: NoteItem(
            id: 'note-retry',
            blocks: [NoteBlock.text(id: 'text-retry')],
          ),
          onSave: (_) async {
            attempts++;
            if (attempts == 1) throw StateError('offline');
          },
          onDelete: (_) async {},
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-title-field')),
      'Zmiana',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-save-retry')), findsOneWidget);
    expect(find.textContaining('Błąd zapisu lokalnego'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('note-save-retry')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets(
    'saving note labels closes the dialog without disposing its field early',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRemasterTheme(Brightness.light),
          home: NoteEditorScreen(
            remastered: true,
            note: NoteItem(
              id: 'note-2',
              blocks: [NoteBlock.text(id: 'text-2')],
            ),
            onSave: (_) async {},
            onDelete: (_) async {},
          ),
        ),
      );

      await tester.tap(find.byTooltip('Edytuj etykiety'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'dom, zakupy');
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();

      expect(find.text('Etykiety'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
