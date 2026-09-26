import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/reminder_schedule.dart';
import 'package:dzien_po_dniu/task_item.dart';

void main() {
  test('daily plan stays disabled unless explicitly enabled', () {
    expect(
      nextDailyPlanAt(
        now: DateTime(2026, 9, 20, 8),
        enabled: false,
        hour: 9,
        minute: 0,
      ),
      isNull,
    );
  });

  test('daily plan schedules today when its time is still ahead', () {
    expect(
      nextDailyPlanAt(
        now: DateTime(2026, 9, 20, 8, 30),
        enabled: true,
        hour: 9,
        minute: 15,
      ),
      DateTime(2026, 9, 20, 9, 15),
    );
  });

  test('daily plan rolls to tomorrow after its time', () {
    expect(
      nextDailyPlanAt(
        now: DateTime(2026, 9, 20, 9, 15),
        enabled: true,
        hour: 9,
        minute: 15,
      ),
      DateTime(2026, 9, 21, 9, 15),
    );
  });

  test('daily plan keeps a rolling sequence of future mornings', () {
    expect(
      dailyPlanTimes(
        now: DateTime(2026, 9, 20, 8),
        enabled: true,
        hour: 9,
        minute: 15,
        occurrenceCount: 3,
      ),
      <DateTime>[
        DateTime(2026, 9, 20, 9, 15),
        DateTime(2026, 9, 21, 9, 15),
        DateTime(2026, 9, 22, 9, 15),
      ],
    );
  });

  test('overdue interval accepts only supported options', () {
    expect(isSupportedOverdueInterval(0), isTrue);
    expect(isSupportedOverdueInterval(30), isTrue);
    expect(isSupportedOverdueInterval(60), isTrue);
    expect(isSupportedOverdueInterval(120), isTrue);
    expect(isSupportedOverdueInterval(15), isFalse);
  });

  test(
    'overdue reminders start after the due time and use the selected interval',
    () {
      final reminders = overdueReminderTimes(
        dueAt: DateTime(2026, 9, 20, 9),
        intervalMinutes: 30,
        now: DateTime(2026, 9, 20, 8),
        occurrenceCount: 3,
      );

      expect(reminders, <DateTime>[
        DateTime(2026, 9, 20, 9, 30),
        DateTime(2026, 9, 20, 10),
        DateTime(2026, 9, 20, 10, 30),
      ]);
    },
  );

  test('overdue reminders skip alarms already in the past', () {
    final reminders = overdueReminderTimes(
      dueAt: DateTime(2026, 9, 20, 9),
      intervalMinutes: 60,
      now: DateTime(2026, 9, 20, 11, 1),
      occurrenceCount: 4,
    );

    expect(reminders, <DateTime>[
      DateTime(2026, 9, 20, 12),
      DateTime(2026, 9, 20, 13),
    ]);
  });

  test('disabled or unsupported overdue reminders produce no alarms', () {
    expect(
      overdueReminderTimes(dueAt: DateTime(2026, 9, 20, 9), intervalMinutes: 0),
      isEmpty,
    );
    expect(
      overdueReminderTimes(
        dueAt: DateTime(2026, 9, 20, 9),
        intervalMinutes: 15,
      ),
      isEmpty,
    );
  });

  test('task digest includes only open tasks due today or overdue', () {
    final now = DateTime(2026, 9, 26, 10);
    final selected = tasksForTaskDigest([
      _task('overdue', DateTime(2026, 9, 20)),
      _task('today', DateTime(2026, 9, 26, 22)),
      _task('future', DateTime(2026, 9, 27)),
      _task('no-date', null),
      _task('done', DateTime(2026, 9, 26), isDone: true),
    ], now: now);

    expect(selected.map((task) => task.id), ['overdue', 'today']);
  });

  test('task digest shows at most three titles and a count', () {
    final digest = formatTaskDigest(
      List.generate(5, (index) => _task('id-$index', DateTime(2026, 9, 26))),
    );

    expect(digest.title, 'Masz 5 zadań do zrobienia');
    expect(digest.body, contains('Zadanie 0'));
    expect(digest.body, contains('Zadanie 2'));
    expect(digest.body, isNot(contains('Zadanie 3')));
    expect(
      formatTaskDigest([
        _task('id-1', DateTime(2026, 9, 26)),
        _task('id-2', DateTime(2026, 9, 26)),
      ]).title,
      'Masz 2 zadania do zrobienia',
    );
  });

  test('task digest schedule stays inside daytime window', () {
    final times = taskDigestTimes(
      now: DateTime(2026, 9, 26, 10, 10),
      intervalMinutes: 60,
      startMinute: 9 * 60,
      endMinute: 21 * 60,
      occurrenceCount: 3,
    );

    expect(times, [
      DateTime(2026, 9, 26, 11),
      DateTime(2026, 9, 26, 12),
      DateTime(2026, 9, 26, 13),
    ]);
  });

  test('task digest supports a window crossing midnight', () {
    final times = taskDigestTimes(
      now: DateTime(2026, 9, 26, 23, 40),
      intervalMinutes: 60,
      startMinute: 22 * 60,
      endMinute: 2 * 60,
      occurrenceCount: 3,
    );

    expect(times, [
      DateTime(2026, 9, 27, 0),
      DateTime(2026, 9, 27, 1),
      DateTime(2026, 9, 27, 22),
    ]);
  });

  test('task digest continues the previous night window after midnight', () {
    final times = taskDigestTimes(
      now: DateTime(2026, 9, 27, 0, 20),
      intervalMinutes: 60,
      startMinute: 22 * 60,
      endMinute: 2 * 60,
      occurrenceCount: 2,
    );

    expect(times, [
      DateTime(2026, 9, 27, 1),
      DateTime(2026, 9, 27, 22),
    ]);
  });

  test('digest interval accepts custom values from 15 to 1440 minutes', () {
    expect(isSupportedTaskDigestInterval(15), isTrue);
    expect(isSupportedTaskDigestInterval(1440), isTrue);
    expect(isSupportedTaskDigestInterval(14), isFalse);
    expect(isSupportedTaskDigestInterval(1441), isFalse);
  });
}

TaskItem _task(String id, DateTime? dueAt, {bool isDone = false}) => TaskItem(
  id: id,
  title: id.startsWith('id-') ? 'Zadanie ${id.substring(3)}' : id,
  status: isDone ? 'done' : 'todo',
  dueAt: dueAt,
);
