/// Returns the next local time at which the daily plan should be shown.
///
/// The setting is deliberately opt-in. A time equal to [now] is considered
/// already missed, so the next occurrence is tomorrow.
DateTime? nextDailyPlanAt({
  required DateTime now,
  required bool enabled,
  required int hour,
  required int minute,
}) {
  if (!enabled) return null;
  final candidate = DateTime(now.year, now.month, now.day, hour, minute);
  return candidate.isAfter(now)
      ? candidate
      : candidate.add(const Duration(days: 1));
}

bool isSupportedOverdueInterval(int minutes) =>
    minutes == 0 || minutes == 30 || minutes == 60 || minutes == 120;
