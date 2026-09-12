import 'package:dzien_po_dniu/calendar_event.dart';
import 'package:dzien_po_dniu/remaster_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('start shows the next cached calendar event', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RemasterShell(
          syncStatus: 'Lokalnie',
          tasks: const [],
          notes: const [],
          calendarEvents: [
            CalendarEvent(
              id: 'event',
              calendarId: 'primary',
              title: 'Dentysta',
              startsAt: DateTime.now().add(const Duration(hours: 2)),
              endsAt: DateTime.now().add(const Duration(hours: 3)),
              isAllDay: false,
            ),
          ],
          tasksContent: const SizedBox(),
          notesContent: const SizedBox(),
          onAddTask: () {},
          onAddNote: () {},
          onOpenTask: (_) {},
          onOpenNote: (_) {},
          onCompleteTask: (_) {},
          onOpenFocus: (_) {},
          onLegacy: () {},
          themeMode: ThemeMode.system,
          onThemeMode: (_) {},
        ),
      ),
    );

    expect(find.text('Następne wydarzenie'), findsOneWidget);
    expect(find.text('Dentysta'), findsOneWidget);
  });
}
