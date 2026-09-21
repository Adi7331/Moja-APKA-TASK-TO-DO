import 'package:supabase_flutter/supabase_flutter.dart';

import 'task_item.dart';
import 'subtask_item.dart';

class TaskSyncService {
  TaskSyncService(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> loadTasks() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('tasks')
        .select()
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addTask(
    String title, {
    String? id,
    String note = '',
    String category = 'Skrzynka',
    String? categoryId,
    String priority = 'medium',
    DateTime? dueAt,
    DateTime? reminderAt,
    String? sourceNoteId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Zaloguj się, aby synchronizować zadania.');
    }
    final row = await _client
        .from('tasks')
        .insert({
          'id': ?id,
          'user_id': user.id,
          'title': title,
          'note': note,
          'category': category,
          'category_id': ?categoryId,
          'priority': priority,
          'due_at': dueAt?.toUtc().toIso8601String(),
          'reminder_at': reminderAt?.toUtc().toIso8601String(),
          'source_note_id': sourceNoteId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<int> importLocalTasks(Iterable<TaskItem> localTasks) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Zaloguj się, aby przenieść zadania do chmury.');
    }

    var imported = 0;
    for (final task in localTasks) {
      final row = await _client
          .from('tasks')
          .insert({
            'user_id': user.id,
            ...task.toSupabasePayload(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      final cloudTaskId = row['id'] as String;
      for (final subtask in task.subtasks) {
        final importedSubtask = await addSubtask(
          cloudTaskId,
          subtask.title,
          subtask.position,
        );
        if (subtask.isDone) {
          await setSubtaskDone(importedSubtask['id'] as String, true);
        }
      }
      imported++;
    }
    return imported;
  }

  Future<void> updateTask(
    String id, {
    required String title,
    required String note,
    required String category,
    String? categoryId,
    required String priority,
    required DateTime? dueAt,
    DateTime? reminderAt,
  }) => _client
      .from('tasks')
      .update({
        'title': title,
        'note': note,
        'category': category,
        'category_id': categoryId,
        'priority': priority,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'reminder_at': reminderAt?.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id);

  Future<void> updateOrganizerTask(TaskItem task) => _client
      .from('tasks')
      .update({
        ...task.toSupabasePayload(),
        'category_id': task.categoryId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', task.id);

  Future<void> completeAndCreateNext(TaskItem completed, TaskItem? next) async {
    await updateOrganizerTask(completed);
    if (next == null) return;
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Zaloguj się, aby synchronizować zadania.');
    }
    await _client.from('tasks').insert({
      'user_id': user.id,
      ...next.toSupabasePayload(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> completeTask(String id) => _client
      .from('tasks')
      .update({
        'status': 'done',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id);

  Future<void> setStatus(String id, String status) => _client
      .from('tasks')
      .update({
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id);

  Future<void> deleteTask(String id) => _client
      .from('tasks')
      .update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id);

  Future<void> restoreTask(String id) => _client
      .from('tasks')
      .update({
        'deleted_at': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id);

  Future<List<Map<String, dynamic>>> loadSubtasks(String taskId) async {
    final rows = await _client
        .from('subtasks')
        .select()
        .eq('task_id', taskId)
        .order('position');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addSubtask(
    String taskId,
    String title,
    int position,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Zaloguj się, aby synchronizować kroki.');
    }
    final row = await _client
        .from('subtasks')
        .insert({
          'task_id': taskId,
          'user_id': user.id,
          'title': title,
          'position': position,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> setSubtaskDone(String id, bool isDone) => _client
      .from('subtasks')
      .update({
        'is_done': isDone,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id);

  Future<void> updateSubtask(
    String id, {
    required String title,
    required int position,
  }) => _client
      .from('subtasks')
      .update({
        'title': title,
        'position': position,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id);

  /// Reconciles subtasks only when the local edit actually changed them.
  /// Keeping this opt-in avoids overwriting a newer remote subtask edit when
  /// an unrelated task field was saved offline.
  Future<void> syncSubtasks(String taskId, List<SubtaskItem> desired) async {
    final remote = await loadSubtasks(taskId);
    final remoteById = {
      for (final row in remote)
        row['id'] as String: SubtaskItem.fromRow(row),
    };
    final desiredIds = desired.map((item) => item.id).toSet();
    for (final item in remoteById.values) {
      if (!desiredIds.contains(item.id)) await deleteSubtask(item.id);
    }
    for (final item in desired) {
      final existing = remoteById[item.id];
      if (existing == null) {
        final inserted = await addSubtask(taskId, item.title, item.position);
        if (item.isDone) await setSubtaskDone(inserted['id'] as String, true);
        continue;
      }
      if (existing.title != item.title || existing.position != item.position) {
        await updateSubtask(
          item.id,
          title: item.title,
          position: item.position,
        );
      }
      if (existing.isDone != item.isDone) {
        await setSubtaskDone(item.id, item.isDone);
      }
    }
  }

  Future<void> deleteSubtask(String id) =>
      _client.from('subtasks').delete().eq('id', id);
}
