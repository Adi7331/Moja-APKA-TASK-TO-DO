import 'package:dzien_po_dniu/repeat_rule.dart';
import 'package:dzien_po_dniu/subtask_item.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_occurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a completed recurring task creates an open unpinned occurrence', () {
    final completed = TaskItem(
      id: 'morning-routine',
      title: 'Poranny spacer',
      status: 'done',
      dueAt: DateTime(2026, 9, 6, 8),
      reminderAt: DateTime(2026, 9, 6, 7, 45),
      pinnedToday: true,
      repeatRule: RepeatRule(unit: RepeatUnit.week, weekdays: {1}),
      subtasks: [
        SubtaskItem(id: 'shoes', title: 'Buty', isDone: true, position: 0),
      ],
    );

    final next = createNextOccurrence(
      completed,
      DateTime(2026, 9, 6, 9),
      'morning-routine-next',
    );

    expect(next.id, 'morning-routine-next');
    expect(next.status, 'todo');
    expect(next.dueAt, DateTime(2026, 9, 7, 8));
    expect(next.reminderAt, isNull);
    expect(next.pinnedToday, isFalse);
    expect(next.completedAt, isNull);
    expect(next.subtasks.single.isDone, isFalse);
    expect(next.subtasks.single.id, isNot('shoes'));
  });
}
