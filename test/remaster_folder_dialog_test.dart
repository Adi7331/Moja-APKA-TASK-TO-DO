import 'package:dzien_po_dniu/note_folder.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/remaster_notes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'creating a folder closes its dialog before rebuilding the strip',
    (tester) async {
      final folders = <NoteFolder>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => RemasterNotesScreen(
                notes: const <NoteItem>[],
                folders: folders,
                onNewNote: ({String? folderId}) {},
                onOpenNote: (_) {},
                onSave: (_) async {},
                onDelete: (_) async {},
                onCreateFolder: (name) async {
                  setState(() => folders.add(NoteFolder(id: name, name: name)));
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Samochód');
      await tester.tap(find.text('Utwórz'));
      await tester.pumpAndSettle();

      expect(find.text('Samochód'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
