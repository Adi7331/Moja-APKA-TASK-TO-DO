import 'package:dzien_po_dniu/remaster_tasks_screen.dart';
import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('priority toggle maps high to medium and other levels to high', () {
    const low = TaskItem(
      id: 'low',
      title: 'Low',
      status: 'todo',
      priority: 'low',
    );
    const high = TaskItem(
      id: 'high',
      title: 'High',
      status: 'todo',
      priority: 'high',
    );

    expect(low.togglePriority().priority, 'high');
    expect(high.togglePriority().priority, 'medium');
  });

  testWidgets('task row lets the user toggle priority on and off', (
    tester,
  ) async {
    var task = const TaskItem(
      id: 'toggle',
      title: 'Toggle priority',
      status: 'todo',
      priority: 'low',
    );

    Widget buildApp() => MaterialApp(
      theme: buildRemasterTheme(Brightness.light),
      home: Scaffold(
        body: RemasterTasksScreen(
          tasks: [task],
          selectedView: TaskView.today,
          onViewChanged: (_) {},
          onOpenTask: (_) {},
          onStatusSelected: (_, _) {},
          onPriorityChanged: (updated) => task = updated,
          onDeleteTask: (_) {},
          onPostponeTask: (_) {},
          onQuickAdd: () {},
          onOpenWeek: () {},
          onOpenWeeklyReview: () {},
        ),
      ),
    );

    await tester.pumpWidget(buildApp());
    final normalColor = tester
        .widget<Material>(find.byKey(const ValueKey('task-card-toggle')))
        .color;
    tester
        .widget<IconButton>(find.byKey(const ValueKey('task-priority-toggle')))
        .onPressed!
        .call();
    await tester.pump();
    expect(task.priority, 'high');

    await tester.pumpWidget(buildApp());
    final priorityColor = tester
        .widget<Material>(find.byKey(const ValueKey('task-card-toggle')))
        .color;
    expect(priorityColor, isNot(normalColor));
    tester
        .widget<IconButton>(find.byKey(const ValueKey('task-priority-toggle')))
        .onPressed!
        .call();
    await tester.pump();
    expect(task.priority, 'medium');

    await tester.pumpWidget(buildApp());
    final restoredColor = tester
        .widget<Material>(find.byKey(const ValueKey('task-card-toggle')))
        .color;
    expect(restoredColor, normalColor);
  });

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
