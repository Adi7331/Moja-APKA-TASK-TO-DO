import 'package:dzien_po_dniu/note_save_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
