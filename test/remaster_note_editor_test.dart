import 'package:dzien_po_dniu/note_editor_screen.dart';
import 'package:dzien_po_dniu/note_folder.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
