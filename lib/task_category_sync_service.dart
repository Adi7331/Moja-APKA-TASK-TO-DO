import 'package:supabase_flutter/supabase_flutter.dart';

import 'task_category.dart';

class TaskCategorySyncService {
  TaskCategorySyncService(this._client);

  final SupabaseClient _client;

  Future<List<TaskCategory>> loadCategories() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rows = await _client
        .from('task_categories')
        .select()
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows)
        .map(TaskCategory.fromRow)
        .toList();
  }

  Future<TaskCategory> save(TaskCategory category) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id != category.userId) {
      throw StateError('Zaloguj się, aby synchronizować kategorie.');
    }
    final row = await _client
        .from('task_categories')
        .upsert(category.toSupabasePayload())
        .select()
        .single();
    return TaskCategory.fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> delete(String categoryId) async {
    await _client.from('task_categories').delete().eq('id', categoryId);
  }
}
