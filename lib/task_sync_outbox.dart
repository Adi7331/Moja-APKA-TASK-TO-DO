import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'task_item.dart';

class PendingTaskSync {
  const PendingTaskSync({required this.id, required this.task});

  final String id;
  final TaskItem task;

  Map<String, dynamic> toJson() => {'id': id, 'task': task.toStorage()};

  factory PendingTaskSync.fromJson(Map<String, dynamic> json) =>
      PendingTaskSync(
        id: json['id'] as String,
        task: TaskItem.fromStorage(
          Map<String, dynamic>.from(json['task'] as Map),
        ),
      );
}

/// Durable snapshots for task creates that could not reach Supabase.
class TaskSyncOutbox {
  TaskSyncOutbox(this._preferences);

  static const _key = 'task_sync_outbox_v1';
  final SharedPreferences _preferences;

  Future<List<PendingTaskSync>> load() async {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => PendingTaskSync.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> enqueue(TaskItem task) async {
    final items = await load();
    final pending = PendingTaskSync(id: task.id, task: task);
    final index = items.indexWhere((item) => item.id == task.id);
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

  Future<void> _save(List<PendingTaskSync> items) => _preferences.setString(
    _key,
    jsonEncode(items.map((item) => item.toJson()).toList()),
  );
}
