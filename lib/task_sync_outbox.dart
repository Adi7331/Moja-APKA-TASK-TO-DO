import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'task_item.dart';

enum TaskSyncOperationKind { create, update, delete }

class PendingTaskSync {
  const PendingTaskSync({
    required this.id,
    required this.task,
    this.kind = TaskSyncOperationKind.create,
    this.syncSubtasks = false,
  });

  final String id;
  final TaskItem task;
  final TaskSyncOperationKind kind;
  final bool syncSubtasks;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'syncSubtasks': syncSubtasks,
        'task': task.toStorage(),
      };

  factory PendingTaskSync.fromJson(Map<String, dynamic> json) =>
      PendingTaskSync(
        id: json['id'] as String,
        kind: TaskSyncOperationKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => TaskSyncOperationKind.create,
        ),
        syncSubtasks: json['syncSubtasks'] as bool? ?? false,
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
    await _enqueue(task, TaskSyncOperationKind.create);
  }

  Future<void> enqueueUpdate(
    TaskItem task, {
    bool syncSubtasks = false,
  }) async {
    await _enqueue(
      task,
      TaskSyncOperationKind.update,
      syncSubtasks: syncSubtasks,
    );
  }

  Future<void> enqueueDelete(TaskItem task) async {
    await _enqueue(task, TaskSyncOperationKind.delete);
  }

  Future<void> _enqueue(
    TaskItem task,
    TaskSyncOperationKind kind, {
    bool syncSubtasks = false,
  }) async {
    final items = await load();
    final pending = PendingTaskSync(
      id: task.id,
      task: task,
      kind: kind,
      syncSubtasks: syncSubtasks,
    );
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
