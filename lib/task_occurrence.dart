import 'subtask_item.dart';
import 'task_item.dart';

TaskItem createNextOccurrence(
  TaskItem completed,
  DateTime completedAt,
  String id,
) {
  final rule = completed.repeatRule;
  if (rule == null) {
    throw ArgumentError.value(completed, 'completed', 'Task must repeat.');
  }
  final reference = completed.dueAt ?? completedAt;
  return completed.copyWith(
    id: id,
    status: 'todo',
    dueAt: rule.nextDueDate(reference),
    reminderAt: null,
    pinnedToday: false,
    completedAt: null,
    subtasks: completed.subtasks
        .map(
          (step) => SubtaskItem(
            id: 'step-$id-${step.position}',
            title: step.title,
            isDone: false,
            position: step.position,
          ),
        )
        .toList(),
  );
}
