import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'note_item.dart';

class NoteConflictException implements Exception {
  const NoteConflictException(this.noteId);
  final String noteId;

  @override
  String toString() => 'Notatka $noteId została zmieniona na innym urządzeniu.';
}

class NoteSyncService {
  NoteSyncService(this._client);
  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser?.id ?? (throw StateError('Zaloguj się, aby synchronizować notatki.'));

  Future<List<NoteItem>> loadNotes({bool includeTrash = false}) async {
    final query = _client.from('notes').select().eq('user_id', _userId);
    final rows = includeTrash
        ? await query.order('updated_at', ascending: false)
        : await query.isFilter('deleted_at', null).order('updated_at', ascending: false);
    final notes = <NoteItem>[];
    for (final raw in List<Map<String, dynamic>>.from(rows)) {
      final row = Map<String, dynamic>.from(raw);
      final blockRows = await _client
          .from('note_blocks')
          .select()
          .eq('note_id', row['id'])
          .order('position');
      final blocks = List<Map<String, dynamic>>.from(blockRows).map((block) {
        final payload = Map<String, dynamic>.from(block['payload'] as Map? ?? const {});
        return NoteBlock.fromJson({
          ...payload,
          'id': block['id'],
          'type': block['block_type'],
          'position': block['position'],
        });
      }).toList();
      final attachmentRows = await _client
          .from('note_attachments')
          .select()
          .eq('note_id', row['id'])
          .isFilter('deleted_at', null);
      final linkRows = await _client
          .from('note_label_links')
          .select('label_id')
          .eq('note_id', row['id'])
          .eq('user_id', _userId);
      final labelIds = List<Map<String, dynamic>>.from(linkRows)
          .map((item) => item['label_id'] as String)
          .toList();
      final labels = labelIds.isEmpty
          ? <String>[]
          : List<Map<String, dynamic>>.from(await _client
                .from('note_labels')
                .select('id, name')
                .inFilter('id', labelIds))
            .map((item) => item['name'] as String)
            .toList();
      notes.add(
        NoteItem(
          id: row['id'] as String,
          userId: row['user_id'] as String?,
          title: row['title'] as String? ?? '',
          blocks: blocks,
          colorKey: NoteColorKey.values.firstWhere(
            (value) => value.name == row['color_key'],
            orElse: () => NoteColorKey.neutral,
          ),
          pinned: row['pinned'] as bool? ?? false,
          archivedAt: _date(row['archived_at']),
          deletedAt: _date(row['deleted_at']),
          reminderAt: _date(row['reminder_at']),
          revision: row['revision'] as int? ?? 1,
          createdAt: _date(row['created_at']) ?? DateTime.now(),
          updatedAt: _date(row['updated_at']) ?? DateTime.now(),
          attachments: List<Map<String, dynamic>>.from(attachmentRows)
              .map((item) => NoteAttachment(
                    id: item['id'] as String,
                    fileName: item['file_name'] as String? ?? 'plik',
                    mimeType: item['mime_type'] as String? ?? 'application/octet-stream',
                    byteSize: (item['byte_size'] as num?)?.toInt() ?? 0,
                    storagePath: item['storage_path'] as String?,
                    createdAt: _date(item['created_at']),
                  ))
              .toList(),
          labels: labels,
        ),
      );
    }
    return notes;
  }

  Future<void> saveNote(NoteItem note, {int? expectedRevision}) async {
    final userId = _userId;
    final expected = expectedRevision ?? note.revision - 1;
    final payload = note.toSupabasePayload(userId: userId);
    final nextRevision = expected + 1;
    final notePayload = {...payload, 'revision': nextRevision};
    if (expectedRevision == null) {
      await _client.from('notes').upsert(notePayload, onConflict: 'id');
    } else {
      final rows = await _client
          .from('notes')
          .update(notePayload)
          .eq('id', note.id)
          .eq('user_id', userId)
          .eq('revision', expected)
          .select('id');
      if (rows.isEmpty) throw NoteConflictException(note.id);
    }
    await _client.from('note_blocks').delete().eq('note_id', note.id).eq('user_id', userId);
    if (note.blocks.isNotEmpty) {
      await _client.from('note_blocks').insert(note.blocks.map((block) => {
        'id': block.id,
        'note_id': note.id,
        'user_id': userId,
        'block_type': block.type.name,
        'payload': block.toJson(),
        'position': block.position,
      }).toList());
    }
    await _client.from('note_label_links').delete().eq('note_id', note.id).eq('user_id', userId);
    for (final label in note.labels.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet()) {
      final labelRow = await _client.from('note_labels').upsert({
        'user_id': userId,
        'name': label,
      }, onConflict: 'user_id,name').select('id').single();
      await _client.from('note_label_links').insert({
        'note_id': note.id,
        'label_id': labelRow['id'],
        'user_id': userId,
      });
    }
  }

  Future<void> importLocalNotes(Iterable<NoteItem> notes) async {
    for (final note in notes) {
      final existing = await _client.from('notes').select('id').eq('id', note.id).maybeSingle();
      if (existing == null) {
        await saveNote(note.copyWith(userId: _userId), expectedRevision: null);
      }
    }
  }

  Future<NoteItem> createConflictCopy(NoteItem note) async {
    final copy = note.copyWith(
      id: newNoteId(),
      title: note.title.isEmpty ? 'Konflikt — notatka' : 'Konflikt — ${note.title}',
      conflictOf: note.id,
      revision: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await saveNote(copy, expectedRevision: null);
    return copy;
  }

  Future<void> purgeExpiredTrash(NoteTrashRetention retention) async {
    if (retention == NoteTrashRetention.never) return;
    final days = retention == NoteTrashRetention.sevenDays ? 7 : 30;
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: days));
    await _client
        .from('notes')
        .delete()
        .eq('user_id', _userId)
        .lt('deleted_at', cutoff.toIso8601String());
  }

  Future<void> permanentlyDeleteNote(NoteItem note) async {
    final userId = _userId;
    final attachments = await _client
        .from('note_attachments')
        .select('storage_path')
        .eq('note_id', note.id)
        .eq('user_id', userId);
    final paths = List<Map<String, dynamic>>.from(attachments)
        .map((item) => item['storage_path'] as String)
        .toList();
    if (paths.isNotEmpty) {
      await _client.storage.from('note-attachments').remove(paths);
    }
    await _client.from('notes').delete().eq('id', note.id).eq('user_id', userId);
  }

  Future<NoteSettings> loadSettings() async {
    final row = await _client
        .from('note_settings')
        .select('trash_retention_days')
        .eq('user_id', _userId)
        .maybeSingle();
    return NoteSettings.fromJson({'trashRetentionDays': row?['trash_retention_days']});
  }

  Future<void> saveSettings(NoteSettings settings) async {
    await _client.from('note_settings').upsert(
      settings.toSupabasePayload(_userId),
      onConflict: 'user_id',
    );
  }

  Future<NoteAttachment> uploadAttachment({
    required NoteAttachment attachment,
    required String noteId,
    required File file,
  }) async {
    final userId = _userId;
    final byteSize = await file.length();
    if (byteSize > noteAttachmentMaxBytes) {
      throw ArgumentError('Załącznik nie może przekraczać 20 MB.');
    }
    final safeName = attachment.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$userId/$noteId/${attachment.id}/$safeName';
    await _client.storage.from('note-attachments').upload(
      path,
      file,
      fileOptions: FileOptions(upsert: true, contentType: attachment.mimeType),
    );
    await _client.from('note_attachments').upsert({
      'id': attachment.id,
      'note_id': noteId,
      'user_id': userId,
      'storage_path': path,
      'file_name': attachment.fileName,
      'mime_type': attachment.mimeType,
      'byte_size': byteSize,
    }, onConflict: 'id');
    return NoteAttachment(
      id: attachment.id,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
      byteSize: byteSize,
      storagePath: path,
      createdAt: attachment.createdAt,
    );
  }

  Future<void> deleteAttachment(NoteAttachment attachment) async {
    final userId = _userId;
    final path = attachment.storagePath;
    if (path != null && path.isNotEmpty) {
      await _client.storage.from('note-attachments').remove([path]);
    }
    await _client
        .from('note_attachments')
        .delete()
        .eq('id', attachment.id)
        .eq('user_id', userId);
  }

  Future<String?> createAttachmentUrl(NoteAttachment attachment) async {
    final path = attachment.storagePath;
    if (path == null || path.isEmpty) return null;
    return _client.storage.from('note-attachments').createSignedUrl(path, 300);
  }
}

DateTime? _date(Object? raw) => raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
