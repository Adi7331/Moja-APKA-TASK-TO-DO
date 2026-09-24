import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/note_sync_outbox.dart';

void main() {
  test('outbox keeps a note snapshot across reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = NoteSyncOutbox(preferences);
    final note = NoteItem(
      id: 'note-1',
      title: 'Offline',
      blocks: const [NoteBlock.text(id: 'block-1', text: 'Treść')],
      updatedAt: DateTime(2026, 9, 20, 12),
    );

    await store.enqueue(note, expectedRevision: null, includeFolderId: false);

    final reloaded = NoteSyncOutbox(preferences);
    final pending = await reloaded.load();
    expect(pending, hasLength(1));
    expect(pending.single.note.title, 'Offline');
    expect(pending.single.note.blocks.single.text, 'Treść');
    expect(pending.single.includeFolderId, isFalse);

    await reloaded.remove(pending.single.id);
    expect(await reloaded.load(), isEmpty);
  });

  test('permanent delete replaces an older save for the same note', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = NoteSyncOutbox(preferences);
    final note = NoteItem(id: 'note-2', title: 'Do usunięcia');

    await store.enqueue(note, expectedRevision: null, includeFolderId: false);
    await store.enqueueDelete(note);

    final pending = await store.load();
    expect(pending, hasLength(1));
    expect(pending.single.kind, NoteSyncOperationKind.delete);
  });

  test('repeated offline edits retain the first cloud base revision', () async {
    SharedPreferences.setMockInitialValues({});
    final store = NoteSyncOutbox(await SharedPreferences.getInstance());
    await store.enqueue(
      NoteItem(id: 'same', title: 'First', revision: 4),
      expectedRevision: 3,
      includeFolderId: false,
    );
    await store.enqueue(
      NoteItem(id: 'same', title: 'Latest', revision: 5),
      expectedRevision: 4,
      includeFolderId: false,
    );
    final pending = (await store.load()).single;
    expect(pending.note.title, 'Latest');
    expect(pending.expectedRevision, 3);
  });
}
