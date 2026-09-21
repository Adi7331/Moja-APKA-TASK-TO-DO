import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'note_item.dart';

enum NoteSyncOperationKind { save, delete }

class PendingNoteSync {
  const PendingNoteSync({
    required this.id,
    required this.note,
    required this.expectedRevision,
    required this.includeFolderId,
    this.kind = NoteSyncOperationKind.save,
  });

  final String id;
  final NoteItem note;
  final int? expectedRevision;
  final bool includeFolderId;
  final NoteSyncOperationKind kind;

  Map<String, dynamic> toJson() => {
    'id': id,
    'note': note.toStorage(),
    'expectedRevision': expectedRevision,
    'includeFolderId': includeFolderId,
    'kind': kind.name,
  };

  factory PendingNoteSync.fromJson(Map<String, dynamic> json) =>
      PendingNoteSync(
        id: json['id'] as String,
        note: NoteItem.fromStorage(
          Map<String, dynamic>.from(json['note'] as Map),
        ),
        expectedRevision: (json['expectedRevision'] as num?)?.toInt(),
        includeFolderId: json['includeFolderId'] as bool? ?? false,
        kind: NoteSyncOperationKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => NoteSyncOperationKind.save,
        ),
      );
}

/// Durable outbox for note saves and permanent deletes. It intentionally stores
/// snapshots, not tokens or credentials, so an offline restart can retry safely.
class NoteSyncOutbox {
  NoteSyncOutbox(this._preferences);

  static const _key = 'note_sync_outbox_v1';
  final SharedPreferences _preferences;

  Future<List<PendingNoteSync>> load() async {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map(
          (entry) => PendingNoteSync.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList();
  }

  Future<void> enqueue(
    NoteItem note, {
    required int? expectedRevision,
    required bool includeFolderId,
  }) async {
    final items = await load();
    final pending = PendingNoteSync(
      id: note.id,
      note: note,
      expectedRevision: expectedRevision,
      includeFolderId: includeFolderId,
    );
    final index = items.indexWhere((item) => item.id == note.id);
    if (index == -1) {
      items.add(pending);
    } else {
      items[index] = pending;
    }
    await _save(items);
  }

  Future<void> enqueueDelete(NoteItem note) async {
    final items = await load();
    final pending = PendingNoteSync(
      id: note.id,
      note: note,
      expectedRevision: null,
      includeFolderId: false,
      kind: NoteSyncOperationKind.delete,
    );
    final index = items.indexWhere((item) => item.id == note.id);
    if (index == -1) {
      items.add(pending);
    } else {
      items[index] = pending;
    }
    await _save(items);
  }

  Future<void> remove(String id) async {
    final items = await load();
    items.removeWhere((item) => item.id == id);
    await _save(items);
  }

  Future<void> _save(List<PendingNoteSync> items) => _preferences.setString(
    _key,
    jsonEncode(items.map((item) => item.toJson()).toList()),
  );
}
