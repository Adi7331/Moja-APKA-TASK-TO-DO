import 'note_sync_service.dart';

/// Saves locally before attempting the cloud, and queues transport failures.
/// Local write failures and optimistic concurrency conflicts remain errors.
Future<bool> saveLocallyThenSyncOrQueueNote({
  required Future<void> Function() saveLocal,
  required Future<void> Function() syncCloud,
  required Future<void> Function() enqueue,
}) async {
  await saveLocal();
  try {
    await syncCloud();
    return true;
  } on NoteConflictException {
    rethrow;
  } catch (_) {
    await enqueue();
    return false;
  }
}
