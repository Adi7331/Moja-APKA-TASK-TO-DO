import 'package:dzien_po_dniu/google_calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calendar service loads selectable calendars', () async {
    final transport = _FakeTransport({
      'calendarList': {
        'items': [
          {'id': 'primary', 'summary': 'Mój kalendarz', 'primary': true},
          {'id': 'work', 'summary': 'Praca'},
        ],
      },
    });

    final calendars = await GoogleCalendarService(transport)
        .loadCalendars('token');

    expect(calendars.map((calendar) => calendar.id), ['primary', 'work']);
    expect(calendars.first.isPrimary, isTrue);
  });

  test('calendar service excludes cancelled events from a sync', () async {
    final transport = _FakeTransport({
      'events': {
        'items': [
          {
            'id': 'kept',
            'summary': 'Spotkanie',
            'start': {'dateTime': '2026-09-11T14:00:00+02:00'},
            'end': {'dateTime': '2026-09-11T15:00:00+02:00'},
          },
          {
            'id': 'cancelled',
            'summary': 'Odwołane',
            'status': 'cancelled',
            'start': {'dateTime': '2026-09-11T16:00:00+02:00'},
            'end': {'dateTime': '2026-09-11T17:00:00+02:00'},
          },
        ],
      },
    });

    final events = await GoogleCalendarService(transport).loadEvents(
      'token',
      calendarIds: const ['primary'],
      from: DateTime(2026, 9, 11),
      until: DateTime(2026, 10, 11),
    );

    expect(events.map((event) => event.id), ['kept']);
  });
}

class _FakeTransport implements CalendarTransport {
  _FakeTransport(this.responses);
  final Map<String, Map<String, dynamic>> responses;

  @override
  Future<Map<String, dynamic>> get(Uri uri, String accessToken) async {
    final isCalendarList = uri.path.endsWith('/users/me/calendarList');
    return responses[isCalendarList ? 'calendarList' : 'events']!;
  }
}
