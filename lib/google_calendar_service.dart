import 'dart:convert';
import 'dart:io';

import 'calendar_event.dart';

abstract interface class CalendarTransport {
  Future<Map<String, dynamic>> get(Uri uri, String accessToken);
}

class HttpCalendarTransport implements CalendarTransport {
  @override
  Future<Map<String, dynamic>> get(Uri uri, String accessToken) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Google Calendar zwrócił błąd ${response.statusCode}.',
        );
      }
      return Map<String, dynamic>.from(jsonDecode(body) as Map);
    } finally {
      client.close(force: true);
    }
  }
}

class GoogleCalendarInfo {
  const GoogleCalendarInfo({
    required this.id,
    required this.title,
    required this.isPrimary,
  });

  final String id;
  final String title;
  final bool isPrimary;
}

class GoogleCalendarService {
  GoogleCalendarService([CalendarTransport? transport])
    : _transport = transport ?? HttpCalendarTransport();

  final CalendarTransport _transport;

  Future<List<GoogleCalendarInfo>> loadCalendars(String accessToken) async {
    final response = await _transport.get(
      Uri.https('www.googleapis.com', '/calendar/v3/users/me/calendarList'),
      accessToken,
    );
    return (response['items'] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) => item['id'] is String)
        .map(
          (item) => GoogleCalendarInfo(
            id: item['id'] as String,
            title: (item['summary'] as String?)?.trim().isNotEmpty == true
                ? (item['summary'] as String).trim()
                : 'Bez nazwy',
            isPrimary: item['primary'] as bool? ?? false,
          ),
        )
        .toList();
  }

  Future<List<CalendarEvent>> loadEvents(
    String accessToken, {
    required List<String> calendarIds,
    required DateTime from,
    required DateTime until,
  }) async {
    final events = <CalendarEvent>[];
    for (final calendarId in calendarIds) {
      final response = await _transport.get(
        Uri.https(
          'www.googleapis.com',
          '/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events',
          {
            'timeMin': from.toUtc().toIso8601String(),
            'timeMax': until.toUtc().toIso8601String(),
            'singleEvents': 'true',
            'orderBy': 'startTime',
            'maxResults': '2500',
          },
        ),
        accessToken,
      );
      for (final item in response['items'] as List<dynamic>? ?? const []) {
        final event = CalendarEvent.fromGoogleJson(
          Map<String, dynamic>.from(item as Map),
          calendarId: calendarId,
        );
        if (!event.cancelled) events.add(event);
      }
    }
    events.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return events;
  }
}
