import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:dzien_po_dniu/remaster_weekly_calendar.dart';
import 'package:dzien_po_dniu/calendar_event.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone week selects a day without horizontal task scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.dark),
        home: RemasterWeeklyCalendarScreen(
          tasks: [
            TaskItem(
              id: 'tuesday',
              title: 'Wtorkowe zadanie',
              status: 'todo',
              dueAt: DateTime(2026, 9, 8),
            ),
          ],
          initialWeek: DateTime(2026, 9, 7),
          onOpenTask: (_) {},
          onMoveTask: (_, _) {},
          onQuickAdd: () {},
        ),
      ),
    );

    await tester.tap(find.text('Wt'));
    await tester.pumpAndSettle();

    expect(find.text('Wtorkowe zadanie'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('week shows calendar events as separate time blocks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.dark),
        home: RemasterWeeklyCalendarScreen(
          tasks: const [],
          calendarEvents: [
            CalendarEvent(
              id: 'calendar-1',
              calendarId: 'primary',
              title: 'Dentysta',
              startsAt: DateTime(2026, 9, 7, 14),
              endsAt: DateTime(2026, 9, 7, 15),
              isAllDay: false,
            ),
          ],
          initialWeek: DateTime(2026, 9, 7),
          onOpenTask: (_) {},
          onMoveTask: (_, _) {},
          onQuickAdd: () {},
        ),
      ),
    );

    expect(find.text('Dentysta'), findsOneWidget);
    expect(find.text('14:00–15:00'), findsOneWidget);
  });
}
