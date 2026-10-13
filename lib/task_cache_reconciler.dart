import 'local_task_store.dart';
import 'task_item.dart';
import 'task_sync_outbox.dart';

/// Keeps the on-device alarm snapshot in step with the visible cloud view.
Future<List<TaskItem>> reconcileCloudTasks({
  required List<TaskItem> cloudTasks,
  required List<PendingTaskSync> pending,
  required LocalTaskStore store,
}) async {
  final byId = {for (final task in cloudTasks) task.id: task};
  for (final operation in pending) {
    if (operation.kind == TaskSyncOperationKind.delete) {
      byId.remove(operation.id);
    } else {
      byId[operation.id] = operation.task;
    }
  }
  final merged = byId.values.toList();
  await store.save(merged);
  return merged;
}
