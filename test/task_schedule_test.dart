import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_schedule.dart';

TaskItem scheduledTask({DateTime? reminderAt}) => TaskItem(
      id: 'postpone-me',
      title: 'Oddzwonić do Marka',
      status: 'todo',
      dueAt: DateTime(2026, 9, 6, 14, 30),
      reminderAt: reminderAt,
    );

void main() {
  final now = DateTime(2026, 9, 6, 16, 20);

  test('postpones a task by one hour and reschedules its implicit reminder', () {
    final plan = planTaskPostponement(
      scheduledTask(),
      now,
      PostponeOption.oneHour,
    );

    expect(plan.updatedTask.dueAt, DateTime(2026, 9, 6, 17, 20));
    expect(plan.updatedTask.reminderAt, isNull);
    expect(plan.reminderTime, DateTime(2026, 9, 6, 17, 20));
  });

  test('postpones a due-time reminder to tomorrow morning', () {
    final plan = planTaskPostponement(
      scheduledTask(reminderAt: DateTime(2026, 9, 6, 14, 30)),
      now,
      PostponeOption.tomorrowMorning,
    );

    expect(plan.updatedTask.dueAt, DateTime(2026, 9, 7, 9));
    expect(plan.updatedTask.reminderAt, DateTime(2026, 9, 7, 9));
    expect(plan.reminderTime, DateTime(2026, 9, 7, 9));
  });

  test('postpones a task to the next Monday and leaves a custom reminder unchanged', () {
    final customReminder = DateTime(2026, 9, 6, 13);
    final plan = planTaskPostponement(
      scheduledTask(reminderAt: customReminder),
      now,
      PostponeOption.nextMonday,
    );

    expect(plan.updatedTask.dueAt, DateTime(2026, 9, 7, 9));
    expect(plan.updatedTask.reminderAt, customReminder);
    expect(plan.reminderTime, isNull);
  });
}
