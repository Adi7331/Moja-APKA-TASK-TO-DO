import 'note_item.dart';

List<NoteItem> notesMovedOutOfFolder({
  required List<NoteItem> notes,
  required String folderId,
  required DateTime updatedAt,
}) => notes
    .where((note) => note.folderId == folderId)
    .map((note) => note.copyWith(folderId: null, updatedAt: updatedAt))
    .toList();
