import 'package:dzien_po_dniu/remaster_tasks_screen.dart';
import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('completed task title uses a clearly visible strike-through', (
    tester,
  ) async {
    const task = TaskItem(
      id: 'done-task',
      title: 'Przejechać się subaru',
      status: 'done',
      category: 'Dom',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.dark),
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 800,
            child: RemasterTasksScreen(
              tasks: const [task],
              selectedView: TaskView.completed,
              onViewChanged: (_) {},
              onOpenTask: (_) {},
              onStatusSelected: (_, _) {},
              onDeleteTask: (_) {},
              onPostponeTask: (_) {},
              onQuickAdd: () {},
              onOpenWeek: () {},
              onOpenWeeklyReview: () {},
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text(task.title));
    expect(title.style?.decoration, TextDecoration.lineThrough);
    expect(title.style?.decorationThickness, 2);
    expect(title.style?.color, isNotNull);
  });
}
