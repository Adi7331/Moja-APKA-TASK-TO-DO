import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Only app content and durable outboxes are copied; auth secrets are excluded.
class LocalBackupData {
  LocalBackupData(this.preferences, this.supportDirectory);

  final SharedPreferences preferences;
  final Directory supportDirectory;

  static const _sharedKeys = {
    'local_tasks_v1',
    'local_tasks_cloud_migration_v1',
    'local_task_categories_v1',
    'focus_sessions_v1',
  };

  static bool _belongsToOwner(String key, String ownerId) =>
      _sharedKeys.contains(key) ||
      key == 'task_sync_outbox_v1_$ownerId' ||
      key == 'task_category_sync_outbox_v1_$ownerId' ||
      key == 'note_sync_outbox_v1_$ownerId' ||
      key == 'note_folder_sync_outbox_v1_$ownerId' ||
      (ownerId == 'local-user' &&
          {
            'task_sync_outbox_v1',
            'task_category_sync_outbox_v1',
            'note_sync_outbox_v1',
            'note_folder_sync_outbox_v1',
          }.contains(key)) ||
      {
        'cost_entries_v1_$ownerId',
        'cost_subscriptions_v1_$ownerId',
        'cost_categories_v1_$ownerId',
        'cost_sync_outbox_v1_$ownerId',
        'work_hours_v1_$ownerId',
        'business_workspace_v1_$ownerId',
      }.contains(key);

  Future<Map<String, dynamic>> capture(String ownerId) async {
    final currentOwner = preferences.getString('local_content_owner_v1');
    if (currentOwner != null &&
        currentOwner != ownerId &&
        ownerId != 'local-user') {
      throw StateError('Pamięć lokalna jest przypisana do innego konta.');
    }
    final values = <String, dynamic>{};
    for (final key in preferences.getKeys()) {
      if (_belongsToOwner(key, ownerId)) {
        final value = preferences.get(key);
        if (value is String || value is bool) values[key] = value;
      }
    }
    final files = <String, String>{};
    final originalPaths = <String, String>{};
    final referencedPaths = <String>{};
    for (final fileName in [
      'notes.json',
      'note_folders.json',
      'notes-cloud-migration-v1',
    ]) {
      final file = File(
        '${supportDirectory.path}${Platform.pathSeparator}$fileName',
      );
      if (await file.exists()) {
        files[fileName] = base64Encode(await file.readAsBytes());
        if (fileName == 'notes.json') {
          _collectLocalPaths(
            jsonDecode(await file.readAsString()),
            referencedPaths,
          );
        }
      }
    }
    final businessKey = 'business_workspace_v1_$ownerId';
    if (values[businessKey] is String) {
      _collectLocalPaths(
        jsonDecode(values[businessKey] as String),
        referencedPaths,
      );
    }
    final noteOutbox =
        values['note_sync_outbox_v1_$ownerId'] ??
        (ownerId == 'local-user' ? values['note_sync_outbox_v1'] : null);
    if (noteOutbox is String) {
      _collectLocalPaths(jsonDecode(noteOutbox), referencedPaths);
    }
    for (final directoryName in ['attachments', 'business_assets']) {
      final directory = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}$directoryName',
      );
      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is! File) continue;
          final normalizedPath = _normalizedLocalPath(entity.path);
          if (!referencedPaths.contains(normalizedPath)) continue;
          final relative = entity.path
              .substring(supportDirectory.path.length + 1)
              .replaceAll(Platform.pathSeparator, '/');
          files[relative] = base64Encode(await entity.readAsBytes());
          originalPaths[normalizedPath] = relative;
        }
      }
    }
    final replacements = <String, String>{};
    for (final reference in referencedPaths) {
      final relative = originalPaths[_normalizedLocalPath(reference)];
      if (relative != null) replacements[reference] = 'backup://$relative';
    }
    if (files.containsKey('notes.json')) {
      final decoded = jsonDecode(
        utf8.decode(base64Decode(files['notes.json']!)),
      );
      files['notes.json'] = base64Encode(
        utf8.encode(jsonEncode(_rewritePaths(decoded, replacements))),
      );
    }
    final noteOutboxKey = ownerId == 'local-user'
        ? 'note_sync_outbox_v1'
        : 'note_sync_outbox_v1_$ownerId';
    if (values[noteOutboxKey] is String) {
      values[noteOutboxKey] = jsonEncode(
        _rewritePaths(
          jsonDecode(values[noteOutboxKey] as String),
          replacements,
        ),
      );
    }
    if (values[businessKey] is String) {
      values[businessKey] = jsonEncode(
        _rewritePaths(jsonDecode(values[businessKey] as String), replacements),
      );
    }
    return {
      'ownerId': ownerId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'preferences': values,
      'files': files,
    };
  }

  Future<void> restore(Map<String, dynamic> snapshot, String ownerId) async {
    if (snapshot['ownerId'] != ownerId) {
      throw StateError('Ta kopia należy do innego konta.');
    }
    final values = Map<String, dynamic>.from(snapshot['preferences'] as Map);
    final rawFiles = Map<String, dynamic>.from(snapshot['files'] as Map);
    for (final entry in values.entries) {
      if (!_belongsToOwner(entry.key, ownerId) ||
          (entry.value is! String && entry.value is! bool)) {
        throw const FormatException('Kopia zawiera niedozwolone ustawienia.');
      }
    }
    final files = <String, List<int>>{};
    var totalBytes = 0;
    for (final entry in rawFiles.entries) {
      if (!_safeRelativePath(entry.key) || entry.value is! String) {
        throw const FormatException('Kopia zawiera niedozwoloną ścieżkę.');
      }
      final bytes = base64Decode(entry.value as String);
      totalBytes += bytes.length;
      if (totalBytes > 500 * 1024 * 1024) {
        throw const FormatException('Kopia jest zbyt duża.');
      }
      files[entry.key] = bytes;
    }
    final previouslyReferencedPaths = <String>{};
    final currentNotesFile = File(_targetPath('notes.json'));
    if (await currentNotesFile.exists()) {
      _collectLocalPaths(
        jsonDecode(await currentNotesFile.readAsString()),
        previouslyReferencedPaths,
      );
    }
    final currentNoteOutboxKey = ownerId == 'local-user'
        ? 'note_sync_outbox_v1'
        : 'note_sync_outbox_v1_$ownerId';
    final currentNoteOutbox = preferences.getString(currentNoteOutboxKey);
    if (currentNoteOutbox != null) {
      _collectLocalPaths(
        jsonDecode(currentNoteOutbox),
        previouslyReferencedPaths,
      );
    }
    final businessKey = 'business_workspace_v1_$ownerId';
    final currentBusiness = preferences.getString(businessKey);
    if (currentBusiness != null) {
      _collectLocalPaths(
        jsonDecode(currentBusiness),
        previouslyReferencedPaths,
      );
    }
    final pathReplacements = <String, String>{};
    for (final relative in files.keys.where(
      (path) =>
          path.startsWith('attachments/') ||
          path.startsWith('business_assets/'),
    )) {
      pathReplacements['backup://$relative'] = _targetPath(relative);
    }
    if (values[businessKey] is String) {
      values[businessKey] = jsonEncode(
        _rewritePaths(
          jsonDecode(values[businessKey] as String),
          pathReplacements,
        ),
      );
    }
    if (files.containsKey('notes.json')) {
      files['notes.json'] = utf8.encode(
        jsonEncode(
          _rewritePaths(
            jsonDecode(utf8.decode(files['notes.json']!)),
            pathReplacements,
          ),
        ),
      );
    }
    final noteOutboxKey = ownerId == 'local-user'
        ? 'note_sync_outbox_v1'
        : 'note_sync_outbox_v1_$ownerId';
    if (values[noteOutboxKey] is String) {
      values[noteOutboxKey] = jsonEncode(
        _rewritePaths(
          jsonDecode(values[noteOutboxKey] as String),
          pathReplacements,
        ),
      );
    }
    // Validate all backup entries before changing local data.
    for (final entry in files.entries) {
      final destination = File(_targetPath(entry.key));
      await destination.parent.create(recursive: true);
      final temporary = File('${destination.path}.restore-tmp');
      await temporary.writeAsBytes(entry.value, flush: true);
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
    }
    for (final oldPath in previouslyReferencedPaths.difference(
      pathReplacements.values.toSet(),
    )) {
      if (!_isInsideSupportDirectory(oldPath)) continue;
      final staleFile = File(oldPath);
      if (await staleFile.exists()) await staleFile.delete();
    }
    for (final key in preferences.getKeys().where(
      (key) => _belongsToOwner(key, ownerId) && !values.containsKey(key),
    )) {
      await preferences.remove(key);
    }
    for (final entry in values.entries) {
      if (entry.value is bool) {
        await preferences.setBool(entry.key, entry.value as bool);
      } else {
        await preferences.setString(entry.key, entry.value as String);
      }
    }
  }

  String _targetPath(String relative) =>
      '${supportDirectory.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';

  bool _isInsideSupportDirectory(String path) {
    final normalizedRoot = supportDirectory.absolute.path;
    final normalizedFile = File(path).absolute.path;
    return normalizedFile.startsWith(
          '$normalizedRoot${Platform.pathSeparator}',
        ) ||
        normalizedFile.startsWith('$normalizedRoot/');
  }

  static bool _safeRelativePath(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    return path.isNotEmpty &&
        !path.startsWith('/') &&
        !path.contains(':') &&
        parts.every((part) => part.isNotEmpty && part != '.' && part != '..') &&
        (path == 'notes.json' ||
            path == 'note_folders.json' ||
            path == 'notes-cloud-migration-v1' ||
            path.startsWith('attachments/') ||
            path.startsWith('business_assets/'));
  }

  static Object? _rewritePaths(
    Object? value,
    Map<String, String> replacements,
  ) {
    if (value is String) return replacements[value] ?? value;
    if (value is List) {
      return value.map((item) => _rewritePaths(item, replacements)).toList();
    }
    if (value is Map) {
      return value.map(
        (key, item) =>
            MapEntry(key.toString(), _rewritePaths(item, replacements)),
      );
    }
    return value;
  }

  static void _collectLocalPaths(Object? value, Set<String> paths) {
    if (value is String) {
      if (value.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value)) {
        paths
          ..add(value)
          ..add(_normalizedLocalPath(value));
      }
    } else if (value is List) {
      for (final item in value) {
        _collectLocalPaths(item, paths);
      }
    } else if (value is Map) {
      for (final item in value.values) {
        _collectLocalPaths(item, paths);
      }
    }
  }

  static String _normalizedLocalPath(String path) {
    final normalized = File(path).absolute.path.replaceAll('\\', '/');
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }
}
