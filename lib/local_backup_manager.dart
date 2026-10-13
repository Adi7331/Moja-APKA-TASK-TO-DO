import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_backup_codec.dart';
import 'local_backup_data.dart';

class LocalBackupSettings {
  const LocalBackupSettings({
    this.enabled = false,
    this.folder,
    this.encrypted = true,
    this.lastSuccessfulAt,
  });

  final bool enabled;
  final String? folder;
  final bool encrypted;
  final DateTime? lastSuccessfulAt;
}

abstract class BackupStorage {
  Future<String?> chooseFolder();
  Future<List<String>> list(String folder);
  Future<void> write(String folder, String name, Uint8List bytes);
  Future<Uint8List> read(String folder, String name);
  Future<void> delete(String folder, String name);
}

class DesktopBackupStorage implements BackupStorage {
  @override
  Future<String?> chooseFolder() async {
    throw UnsupportedError('Użyj systemowego wyboru folderu.');
  }

  File _file(String folder, String name) {
    if (name.contains('/') || name.contains('\\') || name.contains('..')) {
      throw const FormatException('Niedozwolona nazwa kopii.');
    }
    return File('$folder${Platform.pathSeparator}$name');
  }

  @override
  Future<List<String>> list(String folder) async {
    final directory = Directory(folder);
    if (!await directory.exists()) throw FileSystemException('Folder kopii jest niedostępny', folder);
    return directory.list().where((entry) => entry is File)
        .map((entry) => entry.uri.pathSegments.last).toList();
  }

  @override
  Future<void> write(String folder, String name, Uint8List bytes) async {
    final destination = _file(folder, name);
    if (!await destination.parent.exists()) {
      throw FileSystemException('Folder kopii jest niedostępny', folder);
    }
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(destination.path);
  }

  @override
  Future<Uint8List> read(String folder, String name) => _file(folder, name).readAsBytes();

  @override
  Future<void> delete(String folder, String name) => _file(folder, name).delete().then((_) {});
}

/// Android's document-tree URI remains usable after process restart because
/// the native picker takes a persistable permission grant.
class AndroidSafBackupStorage implements BackupStorage {
  static const _channel = MethodChannel('dniowka/local_backup');

  @override
  Future<String?> chooseFolder() => _channel.invokeMethod<String>('chooseFolder');

  @override
  Future<List<String>> list(String folder) async =>
      (await _channel.invokeListMethod<String>('list', {'folder': folder})) ?? const [];

  @override
  Future<void> write(String folder, String name, Uint8List bytes) async {
    final staging = await File('${Directory.systemTemp.path}${Platform.pathSeparator}$name.tmp')
        .writeAsBytes(bytes, flush: true);
    try {
      await _channel.invokeMethod<void>('write', {
        'folder': folder,
        'name': name,
        'path': staging.path,
      });
    } finally {
      if (await staging.exists()) await staging.delete();
    }
  }

  @override
  Future<Uint8List> read(String folder, String name) async {
    final path = await _channel.invokeMethod<String>('read', {
      'folder': folder,
      'name': name,
    });
    if (path == null) throw const FileSystemException('Nie można odczytać kopii.');
    final staging = File(path);
    try {
      return await staging.readAsBytes();
    } finally {
      if (await staging.exists()) await staging.delete();
    }
  }

  @override
  Future<void> delete(String folder, String name) =>
      _channel.invokeMethod<void>('delete', {'folder': folder, 'name': name});
}

abstract class BackupPasswordStore {
  Future<void> save(String key, String? password);
  Future<String?> read(String key);
}

class SecureBackupPasswordStore implements BackupPasswordStore {
  const SecureBackupPasswordStore();
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> save(String key, String? password) async {
    if (password == null) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: password);
    }
  }

  @override
  Future<String?> read(String key) => _storage.read(key: key);
}

class MemoryBackupPasswordStore implements BackupPasswordStore {
  final _values = <String, String>{};
  @override
  Future<void> save(String key, String? password) async {
    if (password == null) {
      _values.remove(key);
    } else {
      _values[key] = password;
    }
  }
  @override
  Future<String?> read(String key) async => _values[key];
}

class LocalBackupManager {
  LocalBackupManager({
    required this.preferences,
    required this.supportDirectory,
    required this.storage,
    required this.passwords,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SharedPreferences preferences;
  final Directory supportDirectory;
  final BackupStorage storage;
  final BackupPasswordStore passwords;
  final DateTime Function() _now;
  LocalBackupSettings settings = const LocalBackupSettings();
  String? _ownerId;
  int _sequence = 0;
  bool _busy = false;

  String _prefix(String ownerId) {
    final hash = SHA256Digest().process(Uint8List.fromList(utf8.encode(ownerId)));
    return 'dniowka-${hash.take(8).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}-';
  }

  String _key(String ownerId, String field) => 'local_backup_${field}_${_prefix(ownerId)}';

  Future<void> load(String ownerId) async {
    _ownerId = ownerId;
    final last = preferences.getString(_key(ownerId, 'last'));
    settings = LocalBackupSettings(
      enabled: preferences.getBool(_key(ownerId, 'enabled')) ?? false,
      folder: preferences.getString(_key(ownerId, 'folder')),
      encrypted: preferences.getBool(_key(ownerId, 'encrypted')) ?? true,
      lastSuccessfulAt: last == null ? null : DateTime.tryParse(last),
    );
  }

  Future<void> configure({
    required String ownerId,
    required String folder,
    required bool enabled,
    String? password,
  }) async {
    if (folder.isEmpty) throw ArgumentError.value(folder, 'folder');
    await storage.list(folder); // Check access before enabling automatic writes.
    if (password != null && password.isEmpty) throw ArgumentError.value(password, 'password');
    await passwords.save(_key(ownerId, 'password'), password);
    await preferences.setString(_key(ownerId, 'folder'), folder);
    await preferences.setBool(_key(ownerId, 'enabled'), enabled);
    await preferences.setBool(_key(ownerId, 'encrypted'), password != null);
    await load(ownerId);
  }

  Future<void> setEnabled(String ownerId, bool enabled) async {
    if (settings.folder == null && enabled) throw StateError('Najpierw wybierz folder.');
    await preferences.setBool(_key(ownerId, 'enabled'), enabled);
    await load(ownerId);
  }

  Future<String> createNow(String ownerId) async {
    if (_busy) throw StateError('Kopia jest już tworzona.');
    if (_ownerId != ownerId) await load(ownerId);
    final folder = settings.folder;
    if (folder == null) throw StateError('Najpierw wybierz folder kopii.');
    _busy = true;
    try {
      final password = settings.encrypted
          ? await passwords.read(_key(ownerId, 'password')) : null;
      if (settings.encrypted && (password == null || password.isEmpty)) {
        throw StateError('Nie ma hasła kopii na tym urządzeniu. Ustaw je ponownie.');
      }
      final snapshot = await LocalBackupData(preferences, supportDirectory).capture(ownerId);
      final bytes = LocalBackupCodec.encode(snapshot, password: password);
      final timestamp = _now().toUtc().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
      final name = '${_prefix(ownerId)}$timestamp-${_sequence++}.dniowka';
      await storage.write(folder, name, bytes);
      // A successful backup must be readable before retention removes anything.
      LocalBackupCodec.decode(await storage.read(folder, name), password: password);
      await preferences.setString(_key(ownerId, 'last'), _now().toUtc().toIso8601String());
      settings = LocalBackupSettings(
        enabled: settings.enabled, folder: folder, encrypted: settings.encrypted,
        lastSuccessfulAt: _now().toUtc(),
      );
      final previous = await listBackups();
      for (final old in previous.skip(7)) {
        await storage.delete(folder, old);
      }
      return name;
    } finally {
      _busy = false;
    }
  }

  Future<List<String>> listBackups() async {
    final ownerId = _ownerId;
    final folder = settings.folder;
    if (ownerId == null || folder == null) return [];
    final entries = await storage.list(folder);
    return entries.where((name) =>
        name.startsWith(_prefix(ownerId)) && name.endsWith('.dniowka'))
        .toList()..sort((a, b) => b.compareTo(a));
  }

  Future<bool> backupIfChanged(String ownerId) async {
    if (_ownerId != ownerId) await load(ownerId);
    if (!settings.enabled || settings.folder == null || _busy) return false;
    final snapshot = await LocalBackupData(preferences, supportDirectory).capture(ownerId);
    snapshot.remove('createdAt');
    final digest = base64Encode(SHA256Digest().process(
      Uint8List.fromList(utf8.encode(jsonEncode(snapshot))),
    ));
    if (preferences.getString(_key(ownerId, 'digest')) == digest) return false;
    await createNow(ownerId);
    await preferences.setString(_key(ownerId, 'digest'), digest);
    return true;
  }

  Future<Map<String, dynamic>> preview(String name, String ownerId, {String? password}) async {
    if (_ownerId != ownerId) await load(ownerId);
    if (!name.startsWith(_prefix(ownerId)) || !name.endsWith('.dniowka')) {
      throw const FormatException('To nie jest kopia tego konta.');
    }
    final folder = settings.folder;
    if (folder == null) throw StateError('Nie wybrano folderu kopii.');
    return LocalBackupCodec.decode(await storage.read(folder, name), password: password);
  }

  Future<void> restore(String name, String ownerId, {String? password}) async {
    // Read and verify the selected backup before creating a safety snapshot.
    final snapshot = await preview(name, ownerId, password: password);
    if (snapshot['ownerId'] != ownerId) throw StateError('Kopia należy do innego konta.');
    await createNow(ownerId);
    await LocalBackupData(preferences, supportDirectory).restore(snapshot, ownerId);
    await preferences.remove(_key(ownerId, 'digest'));
  }
}
