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
      NoteColorKey? selectedColor;
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
                onCreateFolder: (name, color) async {
                  selectedColor = color;
                  setState(
                    () => folders.add(
                      NoteFolder(id: name, name: name, colorKey: color),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Samochód');
      await tester.tap(find.text('Lawenda'));
      await tester.tap(find.text('Utwórz'));
      await tester.pumpAndSettle();

      expect(find.text('Samochód'), findsOneWidget);
      expect(selectedColor, NoteColorKey.lavender);
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

    await tester.tap(find.byTooltip('Opcje folderu: Samochód'));
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

  testWidgets('folder menu is contained in the same aligned chip as its name', (
    tester,
  ) async {
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
            onRenameFolder: (_) async {},
          ),
        ),
      ),
    );

    final chip = tester.getRect(find.byKey(const ValueKey('folder-chip-car')));
    final label = tester.getRect(find.text(folder.name));
    final menu = tester.getRect(find.byTooltip('Opcje folderu: Samochód'));

    expect(chip.contains(label.center), isTrue);
    expect(chip.contains(menu.center), isTrue);
    expect(menu.center.dy, closeTo(label.center.dy, 1));
  });

  testWidgets('folder controls stay within a 390 pixel phone viewport', (
    tester,
  ) async {
    final folders = <NoteFolder>[
      NoteFolder(id: 'work', name: 'Praca'),
      NoteFolder(id: 'home', name: 'Dom'),
      NoteFolder(id: 'health', name: 'Zdrowie'),
      NoteFolder(id: 'ideas', name: 'Pomysły'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 390,
          height: 844,
          child: Scaffold(
            body: RemasterNotesScreen(
              notes: const <NoteItem>[],
              folders: folders,
              onNewNote: ({String? folderId}) {},
              onOpenNote: (_) {},
              onSave: (_) async {},
              onDelete: (_) async {},
              onRenameFolder: (_) async {},
            ),
          ),
        ),
      ),
    );

    final viewport = tester.getRect(find.byType(Scaffold));
    for (final name in folders.map((folder) => folder.name)) {
      expect(
        tester.getRect(find.text(name)).right,
        lessThanOrEqualTo(viewport.right),
      );
    }
    expect(tester.takeException(), isNull);
  });
}
