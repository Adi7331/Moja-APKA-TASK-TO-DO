import 'dart:convert';
import 'dart:io';

import 'calendar_event.dart';
import 'calendar_store.dart';

CalendarConnectionStatus calendarStatusForError(Object error) {
  if (error is CalendarTransportException) {
    final reason = error.reason;
    if (error.statusCode == 401 || reason == 'authError') {
      return CalendarConnectionStatus.expired;
    }
    if (error.statusCode == 429 ||
        const {
          'rateLimitExceeded',
          'userRateLimitExceeded',
          'quotaExceeded',
          'dailyLimitExceeded',
          'concurrentLimitExceeded',
          'limitExceeded',
          'servingLimitExceeded',
        }.contains(reason)) {
      return CalendarConnectionStatus.rateLimited;
    }
    if (const {'accessNotConfigured', 'serviceDisabled'}.contains(reason)) {
      return CalendarConnectionStatus.apiDisabled;
    }
    if (const {
      'insufficientPermissions',
      'insufficientAuthenticationScopes',
    }.contains(reason)) {
      return CalendarConnectionStatus.missingScopes;
    }
    if (const {
      'domainPolicy',
      'accountDisabled',
      'accountDeleted',
      'accountUnverified',
      'insufficientAudience',
      'insufficientAuthorizedParty',
    }.contains(reason)) {
      return CalendarConnectionStatus.accountRestricted;
    }
    if (error.statusCode == 403) {
      return CalendarConnectionStatus.permissionDenied;
    }
  }
  return CalendarConnectionStatus.offline;
}

abstract interface class CalendarTransport {
  Future<Map<String, dynamic>> get(Uri uri, String accessToken);
}

class CalendarTransportException extends StateError {
  CalendarTransportException(this.statusCode, String message, {this.reason})
    : super(message);

  factory CalendarTransportException.fromResponse(int statusCode, String body) {
    String? reason;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final apiError = decoded['error'];
        if (apiError is Map) {
          final errors = apiError['errors'];
          if (errors is List && errors.isNotEmpty && errors.first is Map) {
            final candidate = (errors.first as Map)['reason'];
            if (candidate is String &&
                candidate.length <= 80 &&
                RegExp(r'^[A-Za-z0-9_]+$').hasMatch(candidate)) {
              reason = candidate;
            }
          }
        }
      }
    } on FormatException {
      // Keep only the HTTP status when Google did not send valid JSON.
    }
    return CalendarTransportException(
      statusCode,
      'Google Calendar zwrócił błąd $statusCode.',
      reason: reason,
    );
  }

  final int statusCode;
  final String? reason;
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
        throw CalendarTransportException.fromResponse(
          response.statusCode,
          body,
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
