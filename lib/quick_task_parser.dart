class QuickTaskParseResult {
  const QuickTaskParseResult({required this.title, required this.dueAt});

  final String title;
  final DateTime? dueAt;
}

QuickTaskParseResult parseQuickTask(String input, DateTime now) {
  final trimmed = input.trim();
  final todayPattern = RegExp(r'(?<!\S)dziś(?!\S)', caseSensitive: false);
  final tomorrowPattern = RegExp(r'(?<!\S)jutro(?!\S)', caseSensitive: false);
  final mondayPattern = RegExp(r'(?<!\S)w\s+poniedziałek(?!\S)', caseSensitive: false);
  final timePattern = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b');

  DateTime? day;
  RegExp? matchedDayPattern;
  if (todayPattern.hasMatch(trimmed)) {
    day = DateTime(now.year, now.month, now.day);
    matchedDayPattern = todayPattern;
  } else if (tomorrowPattern.hasMatch(trimmed)) {
    day = DateTime(now.year, now.month, now.day + 1);
    matchedDayPattern = tomorrowPattern;
  } else if (mondayPattern.hasMatch(trimmed)) {
    day = DateTime(now.year, now.month, now.day + (8 - now.weekday));
    matchedDayPattern = mondayPattern;
  }

  if (day == null || matchedDayPattern == null) {
    return QuickTaskParseResult(title: trimmed, dueAt: null);
  }

  final timeMatch = timePattern.firstMatch(trimmed);
  final hour = timeMatch == null ? 9 : int.parse(timeMatch.group(1)!);
  final minute = timeMatch == null ? 0 : int.parse(timeMatch.group(2)!);
  final title = trimmed
      .replaceFirst(matchedDayPattern, '')
      .replaceFirst(timePattern, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return QuickTaskParseResult(
    title: title,
    dueAt: DateTime(day.year, day.month, day.day, hour, minute),
  );
}
