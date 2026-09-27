import 'task_item.dart';

enum TaskView { today, inbox, upcoming, completed }

List<TaskItem> pinnedTodayTasks(Iterable<TaskItem> tasks) =>
    tasks.where((task) => task.pinnedToday && !task.isDone).take(3).toList();

List<TaskItem> tasksForView(List<TaskItem> tasks, TaskView view, DateTime now) {
  final endOfToday = DateTime(now.year, now.month, now.day + 1);
  final selected = switch (view) {
    TaskView.today =>
      tasks
          .where(
            (task) =>
                !task.isDone &&
                (task.dueAt == null || task.dueAt!.isBefore(endOfToday)),
          )
          .toList(),
    TaskView.inbox =>
      tasks
          .where((task) => !task.isDone)
          .where((task) => task.dueAt == null)
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

  final positions = {
    for (var i = 0; i < selected.length; i++) selected[i].id: i,
  };
  selected.sort((a, b) {
    if (view == TaskView.completed) {
      return (b.completedAt ?? b.dueAt ?? DateTime(1900)).compareTo(
        a.completedAt ?? a.dueAt ?? DateTime(1900),
      );
    }
    const ranks = {'high': 0, 'medium': 1, 'low': 2};
    final priority = (ranks[a.priority] ?? 1).compareTo(ranks[b.priority] ?? 1);
    if (priority != 0) return priority;
    final date = (a.dueAt ?? DateTime(9999)).compareTo(
      b.dueAt ?? DateTime(9999),
    );
    return date != 0 ? date : positions[a.id]!.compareTo(positions[b.id]!);
  });
  return selected;
}
