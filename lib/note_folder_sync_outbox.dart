import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'note_folder.dart';

enum NoteFolderSyncOperationKind { upsert, delete }

class PendingNoteFolderSync {
  const PendingNoteFolderSync({
    required this.id,
    required this.folder,
    required this.kind,
  });

  final String id;
  final NoteFolder folder;
  final NoteFolderSyncOperationKind kind;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'folder': folder.toStorage(),
  };

  factory PendingNoteFolderSync.fromJson(Map<String, dynamic> json) =>
      PendingNoteFolderSync(
        id: json['id'] as String,
        kind: NoteFolderSyncOperationKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => NoteFolderSyncOperationKind.upsert,
        ),
        folder: NoteFolder.fromStorage(
          Map<String, dynamic>.from(json['folder'] as Map),
        ),
      );
}

/// Durable folder changes kept locally until Supabase is available again.
class NoteFolderSyncOutbox {
  NoteFolderSyncOutbox(this._preferences, {this.ownerId});

  static const legacyKey = 'note_folder_sync_outbox_v1';
  final SharedPreferences _preferences;
  final String? ownerId;
  String get _key => ownerId == null ? legacyKey : '${legacyKey}_$ownerId';

  static Future<void> scopeLegacyQueue(
    SharedPreferences preferences,
    String ownerId,
  ) async {
    final scopedKey = '${legacyKey}_$ownerId';
    if (preferences.containsKey(scopedKey)) return;
    final legacy = preferences.getString(legacyKey);
    if (legacy != null) {
      await preferences.setString(scopedKey, legacy);
      await preferences.remove(legacyKey);
    }
  }

  Future<List<PendingNoteFolderSync>> load() async {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map(
          (item) =>
              PendingNoteFolderSync.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> enqueueUpsert(NoteFolder folder) =>
      _enqueue(folder, NoteFolderSyncOperationKind.upsert);

  Future<void> enqueueDelete(NoteFolder folder) =>
      _enqueue(folder, NoteFolderSyncOperationKind.delete);

  Future<void> remove(String id) async {
    final items = await load();
    items.removeWhere((item) => item.id == id);
    await _save(items);
  }

  Future<void> _enqueue(
    NoteFolder folder,
    NoteFolderSyncOperationKind kind,
  ) async {
    final items = await load();
    final pending = PendingNoteFolderSync(
      id: folder.id,
      folder: folder,
      kind: kind,
    );
    final index = items.indexWhere((item) => item.id == folder.id);
    if (index == -1) {
      items.add(pending);
    } else {
      items[index] = pending;
    }
    await _save(items);
  }

  Future<void> _save(List<PendingNoteFolderSync> items) => _preferences
      .setString(_key, jsonEncode(items.map((item) => item.toJson()).toList()));
}
