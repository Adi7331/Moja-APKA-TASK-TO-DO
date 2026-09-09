import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'note_item.dart';

class LocalNoteStore {
  LocalNoteStore({this._directory});

  static const storageFileName = 'notes.json';
  static const migrationKeyFileName = 'notes-cloud-migration-v1';
  final Directory? _directory;

  Future<Directory> _dataDirectory() async {
    final directory = _directory ?? await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return directory;
  }

  Future<List<NoteItem>> load() async {
    final directory = await _dataDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$storageFileName');
    if (!await file.exists()) return [];
    final raw = jsonDecode(await file.readAsString());
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => NoteItem.fromStorage(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> save(List<NoteItem> notes) async {
    final directory = await _dataDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$storageFileName');
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode(notes.map((note) => note.toStorage()).toList()),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  Future<bool> get cloudMigrationCompleted async {
    final directory = await _dataDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}$migrationKeyFileName',
    ).exists();
  }

  Future<void> markCloudMigrationCompleted() async {
    final directory = await _dataDirectory();
    await File(
      '${directory.path}${Platform.pathSeparator}$migrationKeyFileName',
    ).writeAsString('done', flush: true);
  }

  Future<NoteAttachment> copyAttachment({
    required String noteId,
    required String attachmentId,
    required File source,
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) async {
    final byteSize = await source.length();
    if (byteSize > noteAttachmentMaxBytes) {
      throw ArgumentError('Załącznik nie może przekraczać 20 MB.');
    }
    final directory = await _dataDirectory();
    final safeName = _safeFileName(fileName);
    final targetDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}attachments${Platform.pathSeparator}$noteId',
    );
    await targetDirectory.create(recursive: true);
    final target = File(
      '${targetDirectory.path}${Platform.pathSeparator}$attachmentId-$safeName',
    );
    await source.copy(target.path);
    return NoteAttachment(
      id: attachmentId,
      fileName: fileName,
      mimeType: mimeType,
      byteSize: byteSize,
      localPath: target.path,
    );
  }

  Future<void> deleteAttachment(NoteAttachment attachment) async {
    final path = attachment.localPath;
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

String _safeFileName(String fileName) {
  final cleaned = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return cleaned.isEmpty ? 'plik' : cleaned;
}
