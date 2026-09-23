import 'package:dzien_po_dniu/note_folder.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/remaster_notes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pl_PL'));

  RemasterNotesScreen screen({
    List<NoteItem> notes = const [],
    List<NoteFolder> folders = const [],
    SaveRemasterFolder? onCreateFolder,
    Future<void> Function(NoteFolder)? onRenameFolder,
    Future<void> Function(NoteFolder)? onDeleteFolder,
  }) => RemasterNotesScreen(
    notes: notes,
    folders: folders,
    onNewNote: ({folderId}) {},
    onOpenNote: (_) {},
    onSave: (_) async {},
    onDelete: (_) async {},
    onCreateFolder: onCreateFolder,
    onRenameFolder: onRenameFolder,
    onDeleteFolder: onDeleteFolder,
  );

  Future<void> openMore(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Więcej widoków notatek'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'creating a folder closes its dialog before rebuilding the strip',
    (tester) async {
      final folders = <NoteFolder>[];
      NoteFolderDraft? savedDraft;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => screen(
                folders: folders,
                onCreateFolder: (draft) async {
                  savedDraft = draft;
                  setState(
                    () => folders.add(
                      NoteFolder(
                        id: draft.name,
                        name: draft.name,
                        colorKey: draft.colorKey,
                        emoji: draft.emoji,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await openMore(tester);
      await tester.tap(find.text('Nowy folder'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('folder-name-field')),
        'Samochód',
      );
      await tester.enterText(
        find.byKey(const ValueKey('folder-emoji-field')),
        '🚗',
      );
      await tester.tap(find.byKey(const ValueKey('folder-color-blue')));
      await tester.tap(find.text('Utwórz'));
      await tester.pumpAndSettle();

      expect(find.text('🚗 Samochód'), findsOneWidget);
      expect(savedDraft?.colorKey, NoteColorKey.blue);
      expect(savedDraft?.emoji, '🚗');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editing a folder keeps its identity and allows clearing emoji', (
    tester,
  ) async {
    NoteFolder? renamedFolder;
    final folder = NoteFolder(id: 'car', name: 'Samochód', emoji: '🚗');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: screen(
            folders: [folder],
            onRenameFolder: (updated) async => renamedFolder = updated,
          ),
        ),
      ),
    );

    await openMore(tester);
    await tester.tap(find.text('Zarządzaj folderami'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opcje folderu: Samochód'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edytuj'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('folder-name-field')),
      'Auto',
    );
    await tester.enterText(
      find.byKey(const ValueKey('folder-emoji-field')),
      '',
    );
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();

    expect(renamedFolder, isNotNull);
    expect(renamedFolder!.id, 'car');
    expect(renamedFolder!.name, 'Auto');
    expect(renamedFolder!.emoji, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('folder manager refreshes its list after rename and deletion', (
    tester,
  ) async {
    var folders = [NoteFolder(id: 'work', name: 'Praca')];
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setParentState) => Scaffold(
            body: screen(
              folders: folders,
              onRenameFolder: (updated) async {
                setParentState(() => folders = [updated]);
              },
              onDeleteFolder: (deleted) async {
                setParentState(
                  () => folders = folders
                      .where((folder) => folder.id != deleted.id)
                      .toList(),
                );
              },
            ),
          ),
        ),
      ),
    );

    await openMore(tester);
    await tester.tap(find.text('Zarządzaj folderami'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opcje folderu: Praca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edytuj'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('folder-name-field')),
      'Biuro',
    );
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();

    expect(find.text('Biuro'), findsNWidgets(2));
    expect(find.byTooltip('Opcje folderu: Biuro'), findsOneWidget);

    await tester.tap(find.byTooltip('Opcje folderu: Biuro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń folder').last);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Opcje folderu: Biuro'), findsNothing);
    expect(find.text('Nie masz jeszcze folderów.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects more than one emoji grapheme without closing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: screen(onCreateFolder: (_) async {})),
      ),
    );
    await openMore(tester);
    await tester.tap(find.text('Nowy folder'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('folder-name-field')),
      'Podróże',
    );
    await tester.enterText(
      find.byKey(const ValueKey('folder-emoji-field')),
      '🚗🏠',
    );
    await tester.tap(find.text('Utwórz'));
    await tester.pumpAndSettle();

    expect(find.text('Wpisz jedną emoji.'), findsOneWidget);
    expect(find.byKey(const ValueKey('folder-name-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects a duplicate folder name without invoking save', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: screen(
            folders: [NoteFolder(id: 'work', name: 'Praca')],
            onCreateFolder: (_) async => saved = true,
          ),
        ),
      ),
    );
    await openMore(tester);
    await tester.tap(find.text('Nowy folder'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('folder-name-field')),
      ' Praca ',
    );
    await tester.tap(find.text('Utwórz'));
    await tester.pumpAndSettle();

    expect(find.text('Folder o tej nazwie już istnieje.'), findsOneWidget);
    expect(saved, isFalse);
    expect(find.byKey(const ValueKey('folder-name-field')), findsOneWidget);
  });

  testWidgets('deleting a folder asks for confirmation and preserves notes', (
    tester,
  ) async {
    NoteFolder? deleted;
    final folder = NoteFolder(id: 'car', name: 'Samochód');
    final note = NoteItem(id: 'note-1', title: 'Plan auta', folderId: 'car');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: screen(
            folders: [folder],
            notes: [note],
            onDeleteFolder: (value) async => deleted = value,
          ),
        ),
      ),
    );
    await openMore(tester);
    await tester.tap(find.text('Zarządzaj folderami'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opcje folderu: Samochód'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń folder').last);
    await tester.pumpAndSettle();

    expect(deleted?.id, 'car');
    expect(note.id, 'note-1');
    expect(note.title, 'Plan auta');
    expect(note.folderId, 'car');
    expect(tester.takeException(), isNull);
  });

  testWidgets('folder filters stay in one horizontally scrollable strip', (
    tester,
  ) async {
    final folders = [
      NoteFolder(id: 'work', name: 'Praca'),
      NoteFolder(id: 'car', name: 'Samochód'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: screen(folders: folders)),
      ),
    );

    expect(find.byKey(const ValueKey('notes-filter-strip')), findsOneWidget);
    expect(find.text('Praca'), findsOneWidget);
    expect(find.text('Samochód'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'many folder filters do not overflow a 390 pixel phone viewport',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final folders = [
        NoteFolder(id: 'work', name: 'Praca'),
        NoteFolder(id: 'home', name: 'Dom'),
        NoteFolder(id: 'health', name: 'Zdrowie'),
        NoteFolder(id: 'ideas', name: 'Pomysły'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: screen(folders: folders)),
        ),
      );

      expect(find.byKey(const ValueKey('notes-filter-strip')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
