import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'task_category.dart';

enum TaskCategorySyncOperationKind { upsert, delete }

class PendingTaskCategorySync {
  const PendingTaskCategorySync({
    required this.id,
    required this.category,
    required this.kind,
  });

  final String id;
  final TaskCategory category;
  final TaskCategorySyncOperationKind kind;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'category': category.toStorage(),
      };

  factory PendingTaskCategorySync.fromJson(Map<String, dynamic> json) =>
      PendingTaskCategorySync(
        id: json['id'] as String,
        kind: TaskCategorySyncOperationKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => TaskCategorySyncOperationKind.upsert,
        ),
        category: TaskCategory.fromStorage(
          Map<String, dynamic>.from(json['category'] as Map),
        ),
      );
}

/// Durable category changes for the short period when Supabase is unavailable.
class TaskCategorySyncOutbox {
  TaskCategorySyncOutbox(this._preferences);

  static const _key = 'task_category_sync_outbox_v1';
  final SharedPreferences _preferences;

  Future<List<PendingTaskCategorySync>> load() async {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map(
          (item) => PendingTaskCategorySync.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> enqueueUpsert(TaskCategory category) => _enqueue(
        category,
        TaskCategorySyncOperationKind.upsert,
      );

  Future<void> enqueueDelete(TaskCategory category) => _enqueue(
        category,
        TaskCategorySyncOperationKind.delete,
      );

  Future<void> remove(String id) async {
    final items = await load();
    items.removeWhere((item) => item.id == id);
    await _save(items);
  }

  Future<void> _enqueue(
    TaskCategory category,
    TaskCategorySyncOperationKind kind,
  ) async {
    final items = await load();
    final pending = PendingTaskCategorySync(
      id: category.id,
      category: category,
      kind: kind,
    );
    final index = items.indexWhere((item) => item.id == category.id);
    if (index == -1) {
      items.add(pending);
    } else {
      items[index] = pending;
    }
    await _save(items);
  }

  Future<void> _save(List<PendingTaskCategorySync> items) =>
      _preferences.setString(
        _key,
        jsonEncode(items.map((item) => item.toJson()).toList()),
      );
}
