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

/// Keep a short rolling window so the daily plan still appears when the app
/// is not opened between two mornings. It is rebuilt whenever the task count
/// or the reminder setting changes.
const dailyPlanOccurrenceCount = 14;

List<DateTime> dailyPlanTimes({
  required DateTime now,
  required bool enabled,
  required int hour,
  required int minute,
  int occurrenceCount = dailyPlanOccurrenceCount,
}) {
  final first = nextDailyPlanAt(
    now: now,
    enabled: enabled,
    hour: hour,
    minute: minute,
  );
  if (first == null || occurrenceCount <= 0) return const [];
  return List<DateTime>.generate(
    occurrenceCount,
    (index) => first.add(Duration(days: index)),
    growable: false,
  );
}

bool isSupportedOverdueInterval(int minutes) =>
    minutes == 0 || minutes == 30 || minutes == 60 || minutes == 120;

/// Number of one-shot overdue alarms kept ahead on the device. The list is
/// refreshed on app resume and whenever a task/settings change, which keeps
/// the schedule bounded and recoverable.
const overdueReminderOccurrenceCount = 24;

int overdueReminderNotificationId(String taskId, int occurrence) =>
    taskId.hashCode ^ 0x4f564552 ^ occurrence;

/// Builds the next overdue reminder times for a task.
///
/// The OS notification plugin does not expose a reliable "start repeating at
/// this future date" API on every supported platform. We therefore schedule a
/// bounded window of one-shot alarms. The window is refreshed when the app is
/// opened/resumed or when the task/settings change, so a task never gets an
/// unbounded collection of alarms left behind on the device.
List<DateTime> overdueReminderTimes({
  required DateTime dueAt,
  required int intervalMinutes,
  DateTime? now,
  int occurrenceCount = overdueReminderOccurrenceCount,
}) {
  if (!isSupportedOverdueInterval(intervalMinutes) ||
      intervalMinutes == 0 ||
      occurrenceCount <= 0) {
    return const [];
  }
  final current = now ?? DateTime.now();
  final interval = Duration(minutes: intervalMinutes);
  return List<DateTime>.generate(occurrenceCount, (index) {
    return dueAt.add(interval * (index + 1));
  }).where((time) => time.isAfter(current)).toList(growable: false);
}
