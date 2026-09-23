import 'task_item.dart';

class WeeklyReview {
  const WeeklyReview({
    required this.weekStart,
    required this.completedCount,
    required this.overdue,
    required this.nextDue,
  });

  final DateTime weekStart;
  final int completedCount;
  final List<TaskItem> overdue;
  final List<TaskItem> nextDue;
}

DateTime startOfWeek(DateTime local) {
  final localMidnight = DateTime(local.year, local.month, local.day);
  return localMidnight.subtract(Duration(days: localMidnight.weekday - DateTime.monday));
}

WeeklyReview buildWeeklyReview(List<TaskItem> tasks, DateTime now) {
  final currentWeekStart = startOfWeek(now);
  final previousWeekStart = currentWeekStart.subtract(const Duration(days: 7));
  final completedCount = tasks
      .where((task) => task.completedAt != null)
      .where((task) => !task.completedAt!.isBefore(previousWeekStart))
      .where((task) => task.completedAt!.isBefore(currentWeekStart))
      .length;
  final overdue = tasks
      .where((task) => !task.isDone)
      .where((task) => task.dueAt != null && task.dueAt!.isBefore(now))
      .toList()
    ..sort((first, second) => first.dueAt!.compareTo(second.dueAt!));
  final nextDue = tasks
      .where((task) => !task.isDone)
      .where((task) => task.dueAt != null && !task.dueAt!.isBefore(now))
      .toList()
    ..sort((first, second) => first.dueAt!.compareTo(second.dueAt!));

  return WeeklyReview(
    weekStart: previousWeekStart,
    completedCount: completedCount,
    overdue: overdue,
    nextDue: nextDue.take(3).toList(),
  );
}
