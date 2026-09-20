import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_sync_outbox.dart';

void main() {
  test('task outbox replaces an older snapshot for the same task', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = TaskSyncOutbox(preferences);
    const first = TaskItem(id: 'task-1', title: 'Pierwsza', status: 'todo');
    const second = TaskItem(id: 'task-1', title: 'Nowsza', status: 'todo');

    await store.enqueue(first);
    await store.enqueue(second);

    final pending = await store.load();
    expect(pending, hasLength(1));
    expect(pending.single.task.title, 'Nowsza');
    await store.remove('task-1');
    expect(await store.load(), isEmpty);
  });
}
