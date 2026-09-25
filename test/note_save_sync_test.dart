import 'package:dzien_po_dniu/note_save_sync.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('list action advances cloud revision before moving note to trash', () {
    final current = NoteItem(id: 'note-1', title: 'Elo elo', revision: 4);
    final requested = current.copyWith(deletedAt: DateTime(2026, 9, 24));

    final prepared = prepareNoteForSave(requested, current: current);

    expect(prepared.deletedAt, isNotNull);
    expect(prepared.revision, 5);
  });

  test('editor revision is not advanced twice', () {
    final current = NoteItem(id: 'note-1', title: 'Old', revision: 4);
    final requested = current.copyWith(title: 'New', revision: 5);

    expect(prepareNoteForSave(requested, current: current).revision, 5);
  });

  test('trash action keeps the latest saved body when its card is stale', () {
    final stale = NoteItem(id: 'note-1', title: 'Old', revision: 2);
    final latest = NoteItem(id: 'note-1', title: 'New', revision: 3);

    final trashed = prepareNoteForTrash(
      stale,
      current: latest,
      deletedAt: DateTime(2026, 9, 24),
    );

    expect(trashed.title, 'New');
    expect(trashed.revision, 4);
    expect(trashed.deletedAt, DateTime(2026, 9, 24));
  });

  test('trash retry preserves a newer cloud edit', () {
    final stale = NoteItem(id: 'same', title: 'Old', revision: 2);
    final cloud = NoteItem(id: 'same', title: 'New cloud text', revision: 5);
    final trashed = prepareNoteForTrash(
      stale,
      current: cloud,
      deletedAt: DateTime(2026, 9, 24),
    );
    expect(trashed.title, 'New cloud text');
    expect(trashed.revision, 6);
  });

  test('cloud failure queues after local save and returns pending', () async {
    final calls = <String>[];

    final synchronized = await saveLocallyThenSyncOrQueueNote(
      saveLocal: () async => calls.add('local'),
      syncCloud: () async {
        calls.add('cloud');
        throw StateError('offline');
      },
      enqueue: () async => calls.add('queue'),
    );

    expect(synchronized, isFalse);
    expect(calls, ['local', 'cloud', 'queue']);
  });

  test('local write failure is not disguised as a queued cloud save', () async {
    var queued = false;

    await expectLater(
      saveLocallyThenSyncOrQueueNote(
        saveLocal: () async => throw StateError('disk full'),
        syncCloud: () async {},
        enqueue: () async => queued = true,
      ),
      throwsStateError,
    );

    expect(queued, isFalse);
  });
}
