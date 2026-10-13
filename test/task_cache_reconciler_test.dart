import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dzien_po_dniu/local_task_store.dart';
import 'package:dzien_po_dniu/task_cache_reconciler.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_sync_outbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cloud refresh persists the current task snapshot for Android alarms', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalTaskStore(await SharedPreferences.getInstance());
    await store.save([
      const TaskItem(id: 'old', title: 'Old', status: 'todo'),
    ]);

    final merged = await reconcileCloudTasks(
      cloudTasks: [
        const TaskItem(id: 'current', title: 'Current', status: 'todo'),
      ],
      pending: const [],
      store: store,
    );

    expect(merged.map((task) => task.id), ['current']);
    expect((await store.load()).map((task) => task.id), ['current']);
  });

  test('pending deletion does not reappear after a cloud refresh', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalTaskStore(await SharedPreferences.getInstance());
    const removed = TaskItem(id: 'removed', title: 'Removed', status: 'todo');

    final merged = await reconcileCloudTasks(
      cloudTasks: [
        removed,
        const TaskItem(id: 'kept', title: 'Kept', status: 'todo'),
      ],
      pending: const [
        PendingTaskSync(
          id: 'removed',
          task: removed,
          kind: TaskSyncOperationKind.delete,
        ),
      ],
      store: store,
    );

    expect(merged.map((task) => task.id), ['kept']);
    expect((await store.load()).map((task) => task.id), ['kept']);
  });
}
