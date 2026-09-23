class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.isAllDay,
    this.cancelled = false,
  });

  factory CalendarEvent.fromGoogleJson(
    Map<String, dynamic> json, {
    required String calendarId,
  }) {
    final start = Map<String, dynamic>.from(json['start'] as Map);
    final end = Map<String, dynamic>.from(json['end'] as Map);
    final allDay = start['dateTime'] == null;
    return CalendarEvent(
      id: json['id'] as String,
      calendarId: calendarId,
      title: (json['summary'] as String?)?.trim().isNotEmpty == true
          ? (json['summary'] as String).trim()
          : 'Bez tytułu',
      startsAt: _readGoogleDate(start, allDay),
      endsAt: _readGoogleDate(end, allDay),
      isAllDay: allDay,
      cancelled: json['status'] == 'cancelled',
    );
  }

  factory CalendarEvent.fromStorage(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String,
    calendarId: json['calendarId'] as String,
    title: json['title'] as String,
    startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
    endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
    isAllDay: json['isAllDay'] as bool,
    cancelled: json['cancelled'] as bool? ?? false,
  );

  final String id;
  final String calendarId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isAllDay;
  final bool cancelled;

  Map<String, dynamic> toStorage() => {
    'id': id,
    'calendarId': calendarId,
    'title': title,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
    'isAllDay': isAllDay,
    'cancelled': cancelled,
  };
}

DateTime _readGoogleDate(Map<String, dynamic> value, bool allDay) {
  final raw = value[allDay ? 'date' : 'dateTime'] as String;
  return allDay ? DateTime.parse(raw) : DateTime.parse(raw).toLocal();
}
