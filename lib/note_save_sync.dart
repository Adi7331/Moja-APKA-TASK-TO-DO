import 'note_sync_service.dart';
import 'note_item.dart';

/// List and folder actions do not go through the editor's revision bump.
/// Normalize them before optimistic cloud update, while preserving a revision
/// already advanced by the editor.
NoteItem prepareNoteForSave(NoteItem requested, {NoteItem? current}) {
  if (current == null || requested.revision > current.revision) {
    return requested;
  }
  return requested.copyWith(revision: current.revision + 1);
}

/// A card can be stale while the editor has already saved newer content.
/// Trash the latest local version so deletion never restores old text.
NoteItem prepareNoteForTrash(
  NoteItem requested, {
  NoteItem? current,
  required DateTime deletedAt,
}) {
  final latest = current ?? requested;
  return latest.copyWith(
    deletedAt: deletedAt,
    updatedAt: deletedAt,
    revision: latest.revision + 1,
  );
}

/// Saves locally before attempting the cloud, and queues transport failures.
/// Local write failures and optimistic concurrency conflicts remain errors.
Future<bool> saveLocallyThenSyncOrQueueNote({
  required Future<void> Function() saveLocal,
  required Future<void> Function() syncCloud,
  required Future<void> Function() enqueue,
}) async {
  await saveLocal();
  await enqueue();
  try {
    await syncCloud();
    return true;
  } on NoteConflictException {
    rethrow;
  } catch (_) {
    return false;
  }
}

/// Runs best-effort work after the note itself is safely saved. A failed
/// refresh or reminder must not be reported as a failed note write.
Future<bool> runNoteSaveFollowUps(
  Iterable<Future<void> Function()> actions,
) async {
  var succeeded = true;
  for (final action in actions) {
    try {
      await action();
    } on Object {
      succeeded = false;
    }
  }
  return succeeded;
}

/// Attachment metadata has a foreign key to the parent note, so the parent
/// must exist before uploading attachment objects and metadata.
Future<NoteItem> ensureNoteBeforeAttachments({
  required Future<void> Function() ensureNote,
  required Future<NoteItem> Function() uploadAttachments,
}) async {
  await ensureNote();
  return uploadAttachments();
}
