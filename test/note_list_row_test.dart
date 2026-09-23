import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/note_folder.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/note_list_row.dart';
import 'package:dzien_po_dniu/remaster_theme.dart';

void main() {
  Widget buildRow(NoteItem note, {NoteFolder? folder}) => MaterialApp(
    theme: buildRemasterTheme(Brightness.light),
    home: Scaffold(
      body: NoteListRow(
        note: note,
        folder: folder,
        selected: false,
        onTap: () {},
        onOpen: () {},
        onSave: (_) async {},
        onDelete: (_) async {},
      ),
    ),
  );

  testWidgets('renders title, preview, folder and attachment status', (
    tester,
  ) async {
    final note = NoteItem(
      id: 'n1',
      title: 'Plan tygodnia',
      blocks: const [
        NoteBlock.text(id: 'b1', text: 'Najważniejsze rzeczy do zrobienia'),
      ],
      attachments: [
        NoteAttachment(
          id: 'a1',
          fileName: 'plan.pdf',
          mimeType: 'application/pdf',
          byteSize: 100,
        ),
      ],
    );
    await tester.pumpWidget(
      buildRow(
        note,
        folder: NoteFolder(id: 'f1', name: 'Praca'),
      ),
    );

    expect(find.text('Plan tygodnia'), findsOneWidget);
    expect(find.textContaining('Najważniejsze rzeczy'), findsOneWidget);
    expect(find.text('Praca'), findsOneWidget);
    expect(find.byTooltip('Załączniki: 1'), findsOneWidget);
  });

  testWidgets('long text truncates without horizontal overflow', (
    tester,
  ) async {
    final long = List.filled(80, 'Bardzo długa treść notatki').join(' ');
    await tester.pumpWidget(
      buildRow(
        NoteItem(
          id: 'long',
          title: long,
          blocks: [NoteBlock.text(id: 'b', text: long)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the first attachment in the row', (tester) async {
    await tester.pumpWidget(
      buildRow(
        NoteItem(
          id: 'doc',
          title: 'Dokumenty',
          attachments: [
            NoteAttachment(
              id: 'a',
              fileName: 'budżet.pdf',
              mimeType: 'application/pdf',
              byteSize: 2048,
            ),
          ],
        ),
      ),
    );
    expect(find.textContaining('budżet.pdf'), findsOneWidget);
  });

  testWidgets(
    'exposes an actionable semantic label for keyboard and screen readers',
    (tester) async {
      await tester.pumpWidget(
        buildRow(
          NoteItem(id: 'semantic', title: 'Plan dnia'),
          folder: NoteFolder(
            id: 'long-folder',
            name: 'Bardzo długa nazwa folderu do sprawdzenia',
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(
          'Notatka Plan dnia, folder Bardzo długa nazwa folderu do sprawdzenia',
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Opcje notatki'), findsOneWidget);
    },
  );

  testWidgets('cancelling the folder picker does not clear the folder', (
    tester,
  ) async {
    String? movedTo;
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteListRow(
            note: NoteItem(id: 'move', title: 'Notatka'),
            folder: NoteFolder(id: 'work', name: 'Praca'),
            folders: [NoteFolder(id: 'work', name: 'Praca')],
            selected: false,
            onTap: () {},
            onOpen: () {},
            onSave: (_) async {},
            onDelete: (_) async {},
            onMoveToFolder: (_, folderId) async {
              called = true;
              movedTo = folderId;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Opcje notatki'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Przenieś do folderu'));
    await tester.pumpAndSettle();
    expect(find.text('Przenieś notatkę'), findsOneWidget);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(movedTo, isNull);
  });
}
