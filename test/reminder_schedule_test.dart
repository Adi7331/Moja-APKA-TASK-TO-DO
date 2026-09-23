import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/reminder_schedule.dart';

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

  test('overdue reminders start after the due time and use the selected interval', () {
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
  });

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
      overdueReminderTimes(
        dueAt: DateTime(2026, 9, 20, 9),
        intervalMinutes: 0,
      ),
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
}
