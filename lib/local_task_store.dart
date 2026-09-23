import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'task_item.dart';

class LocalTaskStore {
  LocalTaskStore(this._preferences);

  static const _storageKey = 'local_tasks_v1';
  static const _cloudMigrationKey = 'local_tasks_cloud_migration_v1';
  final SharedPreferences _preferences;

  bool get cloudMigrationCompleted =>
      _preferences.getBool(_cloudMigrationKey) ?? false;

  Future<void> markCloudMigrationCompleted() =>
      _preferences.setBool(_cloudMigrationKey, true);

  Future<List<TaskItem>> load() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null) return [];
    final data = jsonDecode(raw) as List<dynamic>;
    return data
        .map(
          (entry) =>
              TaskItem.fromStorage(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
  }

  Future<void> save(List<TaskItem> tasks) => _preferences.setString(
    _storageKey,
    jsonEncode(tasks.map((task) => task.toStorage()).toList()),
  );
}
