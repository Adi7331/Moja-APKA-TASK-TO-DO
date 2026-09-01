import 'task_item.dart';

enum TaskView { today, inbox, upcoming, completed }

List<TaskItem> tasksForView(List<TaskItem> tasks, TaskView view, DateTime now) {
  final endOfToday = DateTime(now.year, now.month, now.day + 1);
  final selected = switch (view) {
    TaskView.today =>
      tasks
          .where(
            (task) => task.dueAt == null || task.dueAt!.isBefore(endOfToday),
          )
          .toList(),
    TaskView.inbox =>
      tasks
          .where((task) => !task.isDone)
          .where((task) => task.category == 'Skrzynka' && task.dueAt == null)
          .toList(),
    TaskView.upcoming =>
      tasks
          .where((task) => !task.isDone)
          .where(
            (task) => task.dueAt != null && !task.dueAt!.isBefore(endOfToday),
          )
          .toList(),
    TaskView.completed => tasks.where((task) => task.isDone).toList(),
  };

  selected.sort(
    (a, b) => switch (view) {
      TaskView.upcoming => a.dueAt!.compareTo(b.dueAt!),
      TaskView.completed => _completedOrder(a, b),
      _ => 0,
    },
  );
  return selected;
}

int _completedOrder(TaskItem a, TaskItem b) {
  if (a.dueAt == null && b.dueAt == null) return 0;
  if (a.dueAt == null) return 1;
  if (b.dueAt == null) return -1;
  return b.dueAt!.compareTo(a.dueAt!);
}
