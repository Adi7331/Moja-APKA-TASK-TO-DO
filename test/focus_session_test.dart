import 'package:dzien_po_dniu/focus_session.dart';
import 'package:dzien_po_dniu/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pomodoro session uses a 25 minute work interval and a 5 minute break',
    () {
      const plan = FocusPlan.pomodoro();

      expect(plan.workDuration, const Duration(minutes: 25));
      expect(plan.breakDuration, const Duration(minutes: 5));
    },
  );

  test('focus session survives storage round trip', () {
    final session = FocusSession(
      id: 'session-1',
      taskId: 'task-1',
      startedAt: DateTime.utc(2026, 9, 11, 10),
      endedAt: DateTime.utc(2026, 9, 11, 10, 25),
      plannedWorkSeconds: 1500,
      completed: true,
    );

    expect(FocusSession.fromStorage(session.toStorage()), session);
  });

  test('focus session converts to and from a private Supabase row', () {
    final session = FocusSession(
      id: 'session-1',
      taskId: 'task-1',
      startedAt: DateTime.utc(2026, 9, 11, 10),
      endedAt: DateTime.utc(2026, 9, 11, 10, 25),
      plannedWorkSeconds: 1500,
      completed: true,
    );

    final row = session.toSupabasePayload('user-1');
    expect(row['user_id'], 'user-1');
    expect(FocusSession.fromSupabaseRow(row), session);
  });

  test('focus notification id stays separate from task reminders', () {
    expect(focusNotificationId('task-1'), isNot('task-1'.hashCode));
  });
}
