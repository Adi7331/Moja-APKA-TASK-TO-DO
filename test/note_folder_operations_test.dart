import 'package:dzien_po_dniu/note_folder_operations.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'moving notes out of a deleted folder preserves note identity and data',
    () {
      final updatedAt = DateTime(2026, 9, 23, 12);
      final assigned = NoteItem(
        id: 'note-1',
        title: 'Plan auta',
        folderId: 'car',
        blocks: const [NoteBlock.text(id: 'block-1', text: 'treść')],
        pinned: true,
      );
      final unrelated = NoteItem(id: 'note-2', title: 'Inne', folderId: 'work');

      final moved = notesMovedOutOfFolder(
        notes: [assigned, unrelated],
        folderId: 'car',
        updatedAt: updatedAt,
      );

      expect(moved, hasLength(1));
      expect(moved.single.id, assigned.id);
      expect(moved.single.title, assigned.title);
      expect(moved.single.blocks.single.text, 'treść');
      expect(moved.single.pinned, isTrue);
      expect(moved.single.folderId, isNull);
      expect(moved.single.updatedAt, updatedAt);
    },
  );
}
