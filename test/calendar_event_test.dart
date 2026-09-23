import 'package:dzien_po_dniu/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calendar event reads a timed Google event in local time', () {
    final event = CalendarEvent.fromGoogleJson({
      'id': 'event-1',
      'summary': 'Dentysta',
      'start': {'dateTime': '2026-09-11T14:00:00+02:00'},
      'end': {'dateTime': '2026-09-11T15:00:00+02:00'},
    }, calendarId: 'primary');

    expect(event.title, 'Dentysta');
    expect(event.isAllDay, isFalse);
    expect(event.startsAt.hour, 14);
  });

  test('calendar event reads an all day Google event', () {
    final event = CalendarEvent.fromGoogleJson({
      'id': 'event-2',
      'summary': 'Urlop',
      'start': {'date': '2026-09-11'},
      'end': {'date': '2026-09-12'},
    }, calendarId: 'primary');

    expect(event.isAllDay, isTrue);
    expect(event.startsAt, DateTime(2026, 9, 11));
  });
}
