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

  testWidgets('renaming a folder keeps its identity for assigned notes', (
    tester,
  ) async {
    NoteFolder? renamedFolder;
    final folder = NoteFolder(id: 'car', name: 'Samochód');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemasterNotesScreen(
            notes: const <NoteItem>[],
            folders: <NoteFolder>[folder],
            onNewNote: ({String? folderId}) {},
            onOpenNote: (_) {},
            onSave: (_) async {},
            onDelete: (_) async {},
            onRenameFolder: (updated) async => renamedFolder = updated,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Opcje folderu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zmień nazwę folderu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Auto');
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();

    expect(renamedFolder, isNotNull);
    expect(renamedFolder!.id, 'car');
    expect(renamedFolder!.name, 'Auto');
    expect(tester.takeException(), isNull);
  });
}
