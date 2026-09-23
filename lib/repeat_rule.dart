enum RepeatUnit { day, week, month }

class RepeatRule {
  const RepeatRule({
    required this.unit,
    this.interval = 1,
    this.weekdays = const {},
  }) : assert(interval > 0);

  const RepeatRule.daily() : this(unit: RepeatUnit.day);

  factory RepeatRule.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError.notNull('json');
    }
    final rawUnit = json['unit'] as String? ?? 'day';
    final unit = RepeatUnit.values.firstWhere(
      (value) => value.name == rawUnit,
      orElse: () => RepeatUnit.day,
    );
    final rawWeekdays = json['weekdays'] as List<dynamic>? ?? const [];
    return RepeatRule(
      unit: unit,
      interval: (json['interval'] as num?)?.toInt().clamp(1, 365) ?? 1,
      weekdays: rawWeekdays
          .map((value) => (value as num).toInt())
          .where((value) => value >= DateTime.monday && value <= DateTime.sunday)
          .toSet(),
    );
  }

  final RepeatUnit unit;
  final int interval;
  final Set<int> weekdays;

  Map<String, dynamic> toJson() => {
        'unit': unit.name,
        'interval': interval,
        'weekdays': weekdays.toList()..sort(),
      };

  DateTime nextDueDate(DateTime reference) => switch (unit) {
        RepeatUnit.day => reference.add(Duration(days: interval)),
        RepeatUnit.month => _addMonths(reference, interval),
        RepeatUnit.week => _nextWeeklyDate(reference),
      };

  DateTime _nextWeeklyDate(DateTime reference) {
    if (weekdays.isEmpty) {
      return reference.add(Duration(days: 7 * interval));
    }
    if (interval > 1) {
      final future = reference.add(Duration(days: 7 * interval));
      return _nextSelectedWeekday(future.subtract(const Duration(days: 1)));
    }
    return _nextSelectedWeekday(reference);
  }

  DateTime _nextSelectedWeekday(DateTime after) {
    for (var dayOffset = 1; dayOffset <= 7; dayOffset++) {
      final candidate = after.add(Duration(days: dayOffset));
      if (weekdays.contains(candidate.weekday)) return candidate;
    }
    return after.add(const Duration(days: 7));
  }

  DateTime _addMonths(DateTime reference, int amount) {
    final monthIndex = reference.month - 1 + amount;
    final year = reference.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      reference.day.clamp(1, lastDay),
      reference.hour,
      reference.minute,
      reference.second,
      reference.millisecond,
      reference.microsecond,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RepeatRule &&
      other.unit == unit &&
      other.interval == interval &&
      _sameValues(other.weekdays, weekdays);

  @override
  int get hashCode => Object.hash(unit, interval, Object.hashAll(weekdays.toList()..sort()));

  static bool _sameValues(Set<int> first, Set<int> second) =>
      first.length == second.length && first.containsAll(second);
}
