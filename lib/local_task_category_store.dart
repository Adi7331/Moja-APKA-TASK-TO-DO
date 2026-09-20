import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'task_category.dart';

class LocalTaskCategoryStore {
  LocalTaskCategoryStore(this._preferences);

  static const _storageKey = 'local_task_categories_v1';
  final SharedPreferences _preferences;

  Future<List<TaskCategory>> load() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null) return const [];
    final values = jsonDecode(raw) as List<dynamic>;
    return values
        .map(
          (value) => TaskCategory.fromStorage(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList();
  }

  Future<void> save(List<TaskCategory> categories) => _preferences.setString(
        _storageKey,
        jsonEncode(categories.map((category) => category.toStorage()).toList()),
      );
}
