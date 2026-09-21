import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CalendarSecretStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class _FlutterSecureStorageAdapter implements CalendarSecretStorage {
  _FlutterSecureStorageAdapter(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class CalendarCredentialStore {
  CalendarCredentialStore(this._storage);

  factory CalendarCredentialStore.secure() => CalendarCredentialStore(
    _FlutterSecureStorageAdapter(FlutterSecureStorage()),
  );

  static const _accessTokenKey = 'google_calendar_access_token_v1';

  final CalendarSecretStorage _storage;

  Future<String?> read() => _storage.read(_accessTokenKey);

  Future<void> save(String token) => _storage.write(_accessTokenKey, token);

  Future<void> clear() => _storage.delete(_accessTokenKey);
}
