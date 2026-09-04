import 'task_item.dart';

DateTime _localMidnight(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime _mondayOf(DateTime date) {
  final midnight = _localMidnight(date);
  return midnight.subtract(Duration(days: midnight.weekday - DateTime.monday));
}

List<DateTime> weekDays(DateTime weekStart) {
  final monday = _mondayOf(weekStart);
  return List<DateTime>.generate(
    7,
    (index) => DateTime(monday.year, monday.month, monday.day + index),
  );
}

Map<DateTime, List<TaskItem>> tasksByDay(
  Iterable<TaskItem> tasks,
  DateTime weekStart,
) {
  final days = weekDays(weekStart);
  final grouped = <DateTime, List<TaskItem>>{
    for (final day in days) day: <TaskItem>[],
  };
  final monday = days.first;
  final followingMonday = DateTime(monday.year, monday.month, monday.day + 7);

  for (final task in tasks) {
    final dueAt = task.dueAt;
    if (dueAt == null ||
        dueAt.isBefore(monday) ||
        !dueAt.isBefore(followingMonday)) {
      continue;
    }
    final day = _localMidnight(dueAt);
    grouped[day]?.add(task);
  }

  for (final items in grouped.values) {
    items.sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  }
  return grouped;
}

TaskItem moveTaskToDay(TaskItem task, DateTime targetDay) {
  final dueAt = task.dueAt;
  final hour = dueAt?.hour ?? 9;
  final minute = dueAt?.minute ?? 0;
  return task.copyWith(
    dueAt: DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
      hour,
      minute,
    ),
  );
}
