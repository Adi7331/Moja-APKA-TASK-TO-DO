import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/task_category.dart';
import 'package:dzien_po_dniu/task_item.dart';

void main() {
  test('category keeps user-entered visual data and owner identity', () {
    final createdAt = DateTime.utc(2026, 9, 20, 10);
    final category = TaskCategory(
      id: '6f7c09d4-d03d-4db8-8363-c3c80dfc7313',
      userId: 'fcd7c9d9-0100-4e09-a978-b6c43bc53d47',
      name: 'Finanse',
      color: '#2F6FED',
      emoji: '💳',
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    expect(TaskCategory.fromStorage(category.toStorage()), category);
    expect(category.toSupabasePayload()['emoji'], '💳');
  });

  test('task storage keeps an optional category id without changing legacy category', () {
    const task = TaskItem(
      id: 'task-1',
      title: 'Opłacić rachunek',
      status: 'todo',
      category: 'Dom',
      categoryId: '6f7c09d4-d03d-4db8-8363-c3c80dfc7313',
    );

    final restored = TaskItem.fromStorage(task.toStorage());

    expect(restored.category, 'Dom');
    expect(restored.categoryId, '6f7c09d4-d03d-4db8-8363-c3c80dfc7313');
    expect(task.toSupabasePayload()['category_id'], restored.categoryId);
  });

  test('old stored tasks remain in no category', () {
    final restored = TaskItem.fromStorage({
      'id': 'legacy-task',
      'title': 'Starsze zadanie',
      'status': 'todo',
      'category': 'Praca',
    });

    expect(restored.categoryId, isNull);
  });
}
