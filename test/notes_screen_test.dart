import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/app_theme.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/notes_screen.dart';

void main() {
  Widget buildNotes({List<NoteItem> notes = const []}) => MaterialApp(
    theme: buildLightTheme(),
    home: NotesScreen(
      notes: notes,
      onOpenTasks: () {},
      onSave: (_) async {},
      onDelete: (_) async {},
    ),
  );

  testWidgets('shows an inviting empty state and opens a new note editor', (
    tester,
  ) async {
    await tester.pumpWidget(buildNotes());

    expect(find.byKey(const ValueKey('notes-section-title')), findsOneWidget);
    expect(find.text('Utwórz pierwszą notatkę'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('new-note')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-title-field')), findsOneWidget);
    expect(find.text('Nowa notatka'), findsOneWidget);
  });

  testWidgets('renders a note card with checklist progress and labels', (
    tester,
  ) async {
    final note = NoteItem(
      id: 'n1',
      title: 'Zakupy',
      labels: const ['dom'],
      blocks: [
        NoteBlock.checklist(
          id: 'b1',
          items: const [
            NoteChecklistItem(id: 'c1', text: 'Chleb'),
            NoteChecklistItem(id: 'c2', text: 'Mleko', isDone: true),
          ],
        ),
      ],
    );
    await tester.pumpWidget(buildNotes(notes: [note]));

    expect(find.text('Zakupy'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('dom'), findsOneWidget);
  });

  testWidgets('keeps the note editor usable at a 390 pixel phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildNotes(notes: [NoteItem(id: 'n1', title: 'Telefon') ]));
    await tester.tap(find.text('Telefon').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('note-title-field')), findsOneWidget);
  });

  testWidgets('offers a Keep-style quick composer with separate note actions', (
    tester,
  ) async {
    await tester.pumpWidget(buildNotes());

    expect(find.byKey(const ValueKey('quick-note-composer')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-checklist')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-file')), findsOneWidget);
  });

  testWidgets('can create a second note after closing the first editor', (
    tester,
  ) async {
    await tester.pumpWidget(buildNotes());

    await tester.tap(find.byKey(const ValueKey('quick-note-composer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-close-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note-close-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-note-composer')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quick-note-composer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-title-field')), findsOneWidget);
  });
}
