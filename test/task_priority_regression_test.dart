import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_view.dart';

void main() {
  test(
    'high priority precedes earlier low priority and equal rows stay stable',
    () {
      final tasks = [
        TaskItem(
          id: 'low',
          title: 'Low',
          status: 'todo',
          priority: 'low',
          dueAt: DateTime(2026, 9, 11),
        ),
        TaskItem(
          id: 'high',
          title: 'High',
          status: 'todo',
          priority: 'high',
          dueAt: DateTime(2026, 9, 12),
        ),
        TaskItem(
          id: 'equal',
          title: 'Equal',
          status: 'todo',
          priority: 'high',
          dueAt: DateTime(2026, 9, 12),
        ),
      ];
      expect(
        tasksForView(
          tasks,
          TaskView.upcoming,
          DateTime(2026, 9, 10),
        ).map((t) => t.id),
        ['high', 'equal', 'low'],
      );
    },
  );
}
