import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_view.dart';

void main() {
  test('places undated inbox tasks only in the inbox', () {
    const inbox = TaskItem(id: '1', title: 'Pomysł', status: 'todo');

    expect(tasksForView([inbox], TaskView.inbox, DateTime(2026, 9, 1)), [
      inbox,
    ]);
    expect(
      tasksForView([inbox], TaskView.upcoming, DateTime(2026, 9, 1)),
      isEmpty,
    );
  });

  test(
    'hides completed tasks due today outside the completed view',
    () {
      final doneToday = TaskItem(
        id: 'done-today',
        title: 'Wysłane',
        status: 'done',
        dueAt: DateTime(2026, 9, 1, 16),
      );

      expect(
        tasksForView([doneToday], TaskView.today, DateTime(2026, 9, 1)),
        isEmpty,
      );
    },
  );

  test('sorts upcoming active tasks from the nearest date', () {
    final later = TaskItem(
      id: 'later',
      title: 'Później',
      status: 'todo',
      dueAt: DateTime(2026, 9, 4),
    );
    final sooner = TaskItem(
      id: 'sooner',
      title: 'Wcześniej',
      status: 'todo',
      dueAt: DateTime(2026, 9, 2),
    );

    expect(
      tasksForView([later, sooner], TaskView.upcoming, DateTime(2026, 9, 1)),
      [sooner, later],
    );
  });

  test('shows completed tasks only in the completed view', () {
    const done = TaskItem(id: 'done', title: 'Gotowe', status: 'done');
    const open = TaskItem(id: 'open', title: 'Otwarte', status: 'todo');

    expect(
      tasksForView([done, open], TaskView.completed, DateTime(2026, 9, 1)),
      [done],
    );
  });

  test('daily plan excludes completed pinned tasks and keeps three open tasks', () {
    const first = TaskItem(id: 'first', title: 'Pierwsze', status: 'todo', pinnedToday: true);
    const done = TaskItem(id: 'done', title: 'Gotowe', status: 'done', pinnedToday: true);
    const second = TaskItem(id: 'second', title: 'Drugie', status: 'todo', pinnedToday: true);
    const third = TaskItem(id: 'third', title: 'Trzecie', status: 'todo', pinnedToday: true);

    expect(pinnedTodayTasks([first, done, second, third]), [first, second, third]);
  });
}
