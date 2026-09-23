import 'task_item.dart';

enum PostponeOption { oneHour, tomorrowMorning, nextMonday }

typedef TaskPostponePlan = ({TaskItem updatedTask, DateTime? reminderTime});

TaskPostponePlan planTaskPostponement(
  TaskItem task,
  DateTime now,
  PostponeOption option,
) {
  final dueAt = switch (option) {
    PostponeOption.oneHour => now.add(const Duration(hours: 1)),
    PostponeOption.tomorrowMorning => DateTime(
        now.year,
        now.month,
        now.day + 1,
        9,
      ),
    PostponeOption.nextMonday => DateTime(
        now.year,
        now.month,
        now.day + (8 - now.weekday),
        9,
      ),
  };
  final reminderFollowsDueAt =
      task.reminderAt == null || task.reminderAt == task.dueAt;
  final updatedTask = task.copyWith(
    dueAt: dueAt,
    reminderAt: reminderFollowsDueAt && task.reminderAt != null
        ? dueAt
        : task.reminderAt,
  );
  return (
    updatedTask: updatedTask,
    reminderTime: reminderFollowsDueAt ? dueAt : null,
  );
}
