import 'package:dzien_po_dniu/note_folder.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/note_library_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all excludes archived and deleted notes while pinned keeps only active pins', () {
    final notes = [
      NoteItem(id: 'active-pin', title: 'Plan', pinned: true),
      NoteItem(
        id: 'archive-pin',
        title: 'Stary',
        pinned: true,
        archivedAt: DateTime(2026, 9, 1),
      ),
      NoteItem(
        id: 'trash',
        title: 'Kosz',
        deletedAt: DateTime(2026, 9, 1),
      ),
    ];

    expect(
      selectNotesForLibrary(
        notes: notes,
        folders: const [],
        selection: const NoteLibrarySelection(),
      ).map((note) => note.id),
      ['active-pin'],
    );
    expect(
      selectNotesForLibrary(
        notes: notes,
        folders: const [],
        selection: const NoteLibrarySelection(scope: NoteLibraryScope.pinned),
      ).map((note) => note.id),
      ['active-pin'],
    );
    expect(
      selectNotesForLibrary(
        notes: notes,
        folders: const [],
        selection: const NoteLibrarySelection(scope: NoteLibraryScope.archive),
      ).map((note) => note.id),
      ['archive-pin'],
    );
    expect(
      selectNotesForLibrary(
        notes: notes,
        folders: const [],
        selection: const NoteLibrarySelection(scope: NoteLibraryScope.trash),
      ).map((note) => note.id),
      ['trash'],
    );
  });

  test('search finds folder name and folder count excludes archived content', () {
    final folders = [NoteFolder(id: 'work', name: 'Praca')];
    final notes = [
      NoteItem(id: 'active', title: 'Oferta', folderId: 'work'),
      NoteItem(
        id: 'archived',
        title: 'Stary',
        folderId: 'work',
        archivedAt: DateTime(2026, 9, 1),
      ),
    ];

    final visible = selectNotesForLibrary(
      notes: notes,
      folders: folders,
      selection: const NoteLibrarySelection(query: 'praca'),
    );

    expect(visible.single.id, 'active');
    expect(visibleFolderCount(notes: notes, folderId: 'work'), 1);
  });
}
