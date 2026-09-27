class WorkEntry {
  const WorkEntry({
    required this.id,
    required this.date,
    required this.name,
    this.place = '',
    required this.startMinute,
    required this.endMinute,
    this.breakMinutes = 0,
    this.nextDay = false,
    required this.rateCents,
    this.paid = false,
    required this.updatedAt,
  });

  final String id, name, place;
  final DateTime date, updatedAt;
  final int startMinute, endMinute, breakMinutes, rateCents;
  final bool nextDay, paid;

  int get workMinutes =>
      endMinute + (nextDay ? 1440 : 0) - startMinute - breakMinutes;
  int get amountCents => (workMinutes * rateCents + 30) ~/ 60;
  String? get validationError {
    if (name.trim().isEmpty) return 'Podaj nazwę pracy.';
    if (name.length > 200 || place.length > 200) {
      return 'Nazwa i miejscowość: maksymalnie 200 znaków.';
    }
    if (startMinute < 0 ||
        startMinute > 1439 ||
        endMinute < 0 ||
        endMinute > 1439) {
      return 'Podaj poprawne godziny.';
    }
    final span = endMinute + (nextDay ? 1440 : 0) - startMinute;
    if (span <= 0 || span > 1440) {
      return 'Koniec musi być później niż początek (maksymalnie 24 h).';
    }
    if (breakMinutes < 0 || breakMinutes >= span) {
      return 'Przerwa musi być krótsza od czasu pracy.';
    }
    if (rateCents < 0 || rateCents > 100000000) return 'Podaj poprawną stawkę.';
    return null;
  }

  WorkEntry withPaid(bool value) => WorkEntry(
    id: id,
    date: date,
    name: name,
    place: place,
    startMinute: startMinute,
    endMinute: endMinute,
    breakMinutes: breakMinutes,
    nextDay: nextDay,
    rateCents: rateCents,
    paid: value,
    updatedAt: DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'work_date':
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'name': name,
    'place': place,
    'start_minute': startMinute,
    'end_minute': endMinute,
    'break_minutes': breakMinutes,
    'next_day': nextDay,
    'rate_cents': rateCents,
    'paid': paid,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'deleted_at': null,
  };
  factory WorkEntry.fromJson(Map<String, dynamic> row) => WorkEntry(
    id: row['id'] as String,
    date: DateTime.parse(row['work_date'] as String),
    name: row['name'] as String,
    place: row['place'] as String? ?? '',
    startMinute: (row['start_minute'] as num).toInt(),
    endMinute: (row['end_minute'] as num).toInt(),
    breakMinutes: (row['break_minutes'] as num?)?.toInt() ?? 0,
    nextDay: row['next_day'] as bool? ?? false,
    rateCents: (row['rate_cents'] as num).toInt(),
    paid: row['paid'] as bool? ?? false,
    updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
  );
}

class WorkSummary {
  WorkSummary(Iterable<WorkEntry> entries) {
    final dates = <String>{};
    for (final item in entries) {
      dates.add('${item.date.year}-${item.date.month}-${item.date.day}');
      minutes += item.workMinutes;
      totalCents += item.amountCents;
      if (item.paid) paidCents += item.amountCents;
    }
    days = dates.length;
  }
  int days = 0, minutes = 0, totalCents = 0, paidCents = 0;
  int get outstandingCents => totalCents - paidCents;
}

String workTime(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
String workDuration(int minutes) => minutes % 60 == 0
    ? '${minutes ~/ 60} h'
    : '${minutes ~/ 60} h ${minutes % 60} min';
int? parseWorkRate(String text) {
  final match = RegExp(r'^\s*(\d{1,7})(?:[.,](\d{1,2}))?\s*$').firstMatch(text);
  if (match == null) return null;
  return int.parse(match[1]!) * 100 +
      int.parse((match[2] ?? '0').padRight(2, '0'));
}
