import 'note_folder.dart';
import 'note_item.dart';

enum NoteLibraryScope { all, pinned, reminders, archive, trash }

const _unchanged = Object();

/// State shared by mobile filters and the desktop folder sidebar.
class NoteLibrarySelection {
  const NoteLibrarySelection({
    this.scope = NoteLibraryScope.all,
    this.folderId,
    this.query = '',
  });

  final NoteLibraryScope scope;
  final String? folderId;
  final String query;

  NoteLibrarySelection copyWith({
    NoteLibraryScope? scope,
    Object? folderId = _unchanged,
    String? query,
  }) => NoteLibrarySelection(
    scope: scope ?? this.scope,
    folderId: identical(folderId, _unchanged)
        ? this.folderId
        : folderId as String?,
    query: query ?? this.query,
  );
}

List<NoteItem> selectNotesForLibrary({
  required List<NoteItem> notes,
  required List<NoteFolder> folders,
  required NoteLibrarySelection selection,
}) {
  final folderNames = {for (final folder in folders) folder.id: folder.name};
  final query = selection.query.trim().toLowerCase();
  final selected = notes.where((note) {
    final belongsToScope = switch (selection.scope) {
      NoteLibraryScope.all => !note.isArchived && !note.isDeleted,
      NoteLibraryScope.pinned =>
        note.pinned && !note.isArchived && !note.isDeleted,
      NoteLibraryScope.reminders =>
        note.reminderAt != null && !note.isArchived && !note.isDeleted,
      NoteLibraryScope.archive => note.isArchived && !note.isDeleted,
      NoteLibraryScope.trash => note.isDeleted,
    };
    if (!belongsToScope) return false;
    if (selection.folderId != null && note.folderId != selection.folderId) {
      return false;
    }
    if (query.isEmpty) return true;
    final searchable = [
      note.title,
      note.previewText,
      ...note.labels,
      folderNames[note.folderId] ?? '',
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }).toList()
    ..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  return selected;
}

int visibleFolderCount({
  required List<NoteItem> notes,
  required String? folderId,
}) => notes
    .where(
      (note) =>
          note.folderId == folderId && !note.isArchived && !note.isDeleted,
    )
    .length;
