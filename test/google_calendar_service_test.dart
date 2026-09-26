import 'package:dzien_po_dniu/google_calendar_service.dart';
import 'package:dzien_po_dniu/calendar_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forbidden Calendar response is not mislabeled as expired token', () {
    expect(
      calendarStatusForError(CalendarTransportException(403, 'forbidden')),
      CalendarConnectionStatus.permissionDenied,
    );
    expect(
      calendarStatusForError(CalendarTransportException(401, 'expired')),
      CalendarConnectionStatus.expired,
    );
  });

  test('classifies Calendar API disabled separately from OAuth denial', () {
    final error = CalendarTransportException.fromResponse(403, '''
      {"error":{"errors":[{"reason":"accessNotConfigured"}],"code":403}}
    ''');

    expect(error.reason, 'accessNotConfigured');
    expect(calendarStatusForError(error), CalendarConnectionStatus.apiDisabled);
  });

  test('classifies missing Calendar scopes and quota errors separately', () {
    final scopes = CalendarTransportException.fromResponse(403, '''
      {"error":{"errors":[{"reason":"insufficientPermissions"}],"code":403}}
    ''');
    final rateLimited = CalendarTransportException.fromResponse(403, '''
      {"error":{"errors":[{"reason":"rateLimitExceeded"}],"code":403}}
    ''');
    final tooManyRequests = CalendarTransportException.fromResponse(429, '''
      {"error":{"errors":[{"reason":"rateLimitExceeded"}],"code":429}}
    ''');

    expect(
      calendarStatusForError(scopes),
      CalendarConnectionStatus.missingScopes,
    );
    expect(
      calendarStatusForError(rateLimited),
      CalendarConnectionStatus.rateLimited,
    );
    expect(
      calendarStatusForError(tooManyRequests),
      CalendarConnectionStatus.rateLimited,
    );
  });

  test(
    'does not expose response messages or arbitrary error body in exception',
    () {
      final error = CalendarTransportException.fromResponse(403, '''
      {"error":{"errors":[{"reason":"domainPolicy","message":"private account detail"}],"message":"private body"}}
    ''');

      expect(error.reason, 'domainPolicy');
      expect(error.toString(), isNot(contains('private')));
      expect(
        calendarStatusForError(error),
        CalendarConnectionStatus.accountRestricted,
      );
    },
  );

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
