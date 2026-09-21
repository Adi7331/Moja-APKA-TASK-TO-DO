import 'package:dzien_po_dniu/note_editor_screen.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remastered note editor presents a focused writing surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.light),
        home: NoteEditorScreen(
          remastered: true,
          note: NoteItem(
            id: 'note-1',
            title: 'Plan na tydzień',
            blocks: [NoteBlock.text(id: 'text-1', text: 'Pierwszy krok')],
          ),
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('remaster-note-editor')), findsOneWidget);
    expect(find.text('Edytujesz notatkę'), findsOneWidget);
    expect(find.byKey(const ValueKey('note-title-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-save-status')), findsOneWidget);
  });

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
    await tester.tap(find.text('Więcej opcji'));
    await tester.pumpAndSettle();
    expect(find.text('Lista kroków'), findsOneWidget);
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
