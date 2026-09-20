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

  test('overdue interval accepts only supported options', () {
    expect(isSupportedOverdueInterval(0), isTrue);
    expect(isSupportedOverdueInterval(30), isTrue);
    expect(isSupportedOverdueInterval(60), isTrue);
    expect(isSupportedOverdueInterval(120), isTrue);
    expect(isSupportedOverdueInterval(15), isFalse);
  });
}
